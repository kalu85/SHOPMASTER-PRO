import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class DuplicateBarcodeException implements Exception {
  @override
  String toString() => 'This barcode is already used by another item.';
}

class StockChangedException implements Exception {
  const StockChangedException(this.currentStock);
  final double currentStock;
}

class ProductRepository {
  ProductRepository._();
  static final ProductRepository instance = ProductRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<Product?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Supplier of the latest purchase invoice for each item (product id -> name).
  Future<Map<int, String>> lastSuppliers() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT ii.product_id AS pid, i.party_name AS name '
      'FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id '
      "WHERE i.kind = 'purchase' AND i.doc_type = 'invoice' "
      "AND ii.product_id IS NOT NULL AND i.party_name != '' "
      'ORDER BY i.id ASC, ii.id ASC',
    );
    final out = <int, String>{};
    for (final r in rows) {
      out[r['pid'] as int] = r['name'] as String; // later rows overwrite
    }
    return out;
  }

  Future<List<Product>> list({String query = ''}) async {
    final db = await _db;
    final q = query.trim();
    final rows = q.isEmpty
        ? await db.query('products', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'products',
            where:
                'name LIKE ? OR category LIKE ? OR hsn LIKE ? OR barcode LIKE ?',
            whereArgs: List.filled(4, '%$q%'),
            orderBy: 'name COLLATE NOCASE',
          );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insert(Product p) async {
    final db = await _db;
    try {
      return await db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();
        final stock = p.isService ? 0.0 : p.openingStock;
        final id = await txn.insert('products', {
          ...p.toMap(),
          'opening_stock': stock,
          'current_stock': stock,
          'created_at': now,
        });
        if (stock != 0) {
          await txn.insert('stock_movements', {
            'product_id': id,
            'qty_change': stock,
            'reason': 'Opening stock',
            'note': '',
            'created_at': now,
          });
        }
        return id;
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateBarcodeException();
      rethrow;
    }
  }

  /// Updates details only. Stock quantity changes go through [adjustStock].
  Future<void> update(Product p) async {
    final db = await _db;
    try {
      await db.update(
        'products',
        {
          'name': p.name,
          'category': p.category,
          'hsn': p.hsn,
          'barcode': (p.barcode == null || p.barcode!.isEmpty) ? null : p.barcode,
          'purchase_rate': p.purchaseRate,
          'sale_rate': p.saleRate,
          'gst_rate': p.gstRate,
          'min_stock': p.minStock,
          'is_service': p.isService ? 1 : 0,
          'supplier_id': p.supplierId,
          'supplier_name': p.supplierName,
        },
        where: 'id = ?',
        whereArgs: [p.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateBarcodeException();
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock({
    required int productId,
    required double change,
    required String reason,
    String note = '',
    double? expectedCurrentStock,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['current_stock'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Item no longer exists.');
      final currentStock = (rows.first['current_stock'] as num).toDouble();
      if (expectedCurrentStock != null && currentStock != expectedCurrentStock) {
        throw StockChangedException(currentStock);
      }
      await txn.rawUpdate(
        'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
        [change, productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'qty_change': change,
        'reason': reason,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<StockMovement>> movements(int productId) async {
    final db = await _db;
    final rows = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'id DESC',
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> count() async {
    final db = await _db;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM products')) ??
        0;
  }

  /// Stock items at or below their minimum level (includes negative stock).
  Future<List<Product>> lowStock({int limit = 8}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: 'is_service = 0 AND min_stock > 0 AND current_stock <= min_stock',
      orderBy: 'current_stock ASC',
      limit: limit,
    );
    return rows.map(Product.fromMap).toList();
  }
}
