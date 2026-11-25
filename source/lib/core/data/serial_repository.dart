import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/serial.dart';

class SerialRepository {
  SerialRepository._();
  static final SerialRepository instance = SerialRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<SerialRecord?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('serials', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SerialRecord.fromMap(rows.first);
  }

  /// [status] null = all. [query] matches serial, product, customer, invoice.
  Future<List<SerialRecord>> list({String? status, String query = ''}) async {
    final db = await _db;
    final q = query.trim();
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (q.isNotEmpty) {
      where.add(
          '(serial LIKE ? OR product_name LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ? OR sale_number LIKE ? OR purchase_number LIKE ?)');
      args.addAll(List.filled(6, '%$q%'));
    }
    final rows = await db.query(
      'serials',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
      limit: 300,
    );
    return rows.map(SerialRecord.fromMap).toList();
  }

  /// Sold serials that have a warranty, optionally filtered by state.
  Future<List<SerialRecord>> warrantyList({
    WarrantyFilter filter = WarrantyFilter.all,
    String query = '',
  }) async {
    final db = await _db;
    final q = query.trim();
    final where = <String>["warranty_expiry IS NOT NULL", "status = 'sold'"];
    final args = <Object?>[];
    if (q.isNotEmpty) {
      where.add(
          '(serial LIKE ? OR product_name LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ?)');
      args.addAll(List.filled(4, '%$q%'));
    }
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final soon = today.add(const Duration(days: 30));
    final soonIso =
        '${soon.year.toString().padLeft(4, '0')}-${soon.month.toString().padLeft(2, '0')}-${soon.day.toString().padLeft(2, '0')}';
    switch (filter) {
      case WarrantyFilter.active:
        where.add('warranty_expiry >= ?');
        args.add(iso);
      case WarrantyFilter.expiring:
        where.add('warranty_expiry >= ? AND warranty_expiry <= ?');
        args.addAll([iso, soonIso]);
      case WarrantyFilter.expired:
        where.add('warranty_expiry < ?');
        args.add(iso);
      case WarrantyFilter.all:
        break;
    }
    final rows = await db.query(
      'serials',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'warranty_expiry ASC',
      limit: 300,
    );
    return rows.map(SerialRecord.fromMap).toList();
  }

  /// Manually registers a serial that is in stock.
  Future<void> addManual({
    required String serial,
    int? productId,
    String productName = '',
  }) async {
    final s = serial.trim();
    if (s.isEmpty) throw SerialException('Enter a serial number');
    final db = await _db;
    final exists = await db.query('serials', where: 'serial = ?', whereArgs: [s]);
    if (exists.isNotEmpty) {
      throw SerialException('Serial "$s" already exists');
    }
    await db.insert('serials', {
      'serial': s,
      'product_id': productId,
      'product_name': productName,
      'status': 'in_stock',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<WarrantyClaim>> claims(int serialId) async {
    final db = await _db;
    final rows = await db.query(
      'warranty_claims',
      where: 'serial_id = ?',
      whereArgs: [serialId],
      orderBy: 'id DESC',
    );
    return rows.map(WarrantyClaim.fromMap).toList();
  }

  Future<void> addClaim({
    required int serialId,
    required String date,
    required String issue,
  }) async {
    final db = await _db;
    await db.insert('warranty_claims', {
      'serial_id': serialId,
      'claim_date': date,
      'issue': issue,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateClaim(int id, String status, String resolution) async {
    final db = await _db;
    await db.update(
      'warranty_claims',
      {'status': status, 'resolution': resolution},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

enum WarrantyFilter { all, active, expiring, expired }
