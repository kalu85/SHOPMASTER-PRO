import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

enum SearchType {
  product,
  customer,
  supplier,
  sale,
  purchase,
  serial,
  warranty,
  payment,
}

String searchTypeLabel(SearchType t) => switch (t) {
      SearchType.product => 'Items & stock',
      SearchType.customer => 'Customers',
      SearchType.supplier => 'Suppliers',
      SearchType.sale => 'Sales',
      SearchType.purchase => 'Purchases',
      SearchType.serial => 'Serial numbers',
      SearchType.warranty => 'Warranty',
      SearchType.payment => 'Payments',
    };

class SearchHit {
  const SearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.date,
  });

  final SearchType type;
  final int id;
  final String title;
  final String subtitle;
  final String? date;
}

/// Global search across every module. Supports name, phone, invoice number,
/// serial number, HSN and barcode, with optional category and date filters.
/// Undated records (items, parties) are hidden while a date filter is on.
class SearchRepository {
  SearchRepository._();
  static final SearchRepository instance = SearchRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<List<SearchHit>> search(
    String query, {
    SearchType? only,
    String? from,
    String? to,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final db = await _db;
    final hasDates = from != null && to != null;
    final hits = <SearchHit>[];

    bool want(SearchType t) => only == null || only == t;

    if (want(SearchType.product) && !hasDates) {
      final rows = await db.query(
        'products',
        where: 'name LIKE ? OR category LIKE ? OR hsn LIKE ? OR barcode LIKE ?',
        whereArgs: List.filled(4, like),
        orderBy: 'name COLLATE NOCASE',
        limit: 25,
      );
      for (final r in rows) {
        final stock = (r['current_stock'] as num).toDouble();
        final parts = <String>[
          if ((r['is_service'] as num) == 1)
            'Service'
          else
            'Stock ${stock == stock.roundToDouble() ? stock.toInt() : stock}',
          if ((r['hsn'] as String).isNotEmpty) 'HSN ${r['hsn']}',
          if ((r['barcode'] as String?)?.isNotEmpty ?? false)
            'Barcode ${r['barcode']}',
        ];
        hits.add(SearchHit(
          type: SearchType.product,
          id: (r['id'] as num).toInt(),
          title: r['name'] as String,
          subtitle: parts.join('  •  '),
        ));
      }
    }

    for (final pt in [SearchType.customer, SearchType.supplier]) {
      if (!want(pt) || hasDates) continue;
      final rows = await db.query(
        'parties',
        where:
            'type = ? AND (name LIKE ? OR phone LIKE ? OR email LIKE ? OR gstin LIKE ?)',
        whereArgs: [pt.name, ...List.filled(4, like)],
        orderBy: 'name COLLATE NOCASE',
        limit: 25,
      );
      for (final r in rows) {
        hits.add(SearchHit(
          type: pt,
          id: (r['id'] as num).toInt(),
          title: r['name'] as String,
          subtitle: [
            if ((r['phone'] as String).isNotEmpty) r['phone'] as String,
            if ((r['email'] as String).isNotEmpty) r['email'] as String,
            if ((r['gstin'] as String).isNotEmpty) r['gstin'] as String,
          ].join('  •  '),
        ));
      }
    }

    for (final it in [SearchType.sale, SearchType.purchase]) {
      if (!want(it)) continue;
      final rows = await db.rawQuery('''
        SELECT * FROM invoices
        WHERE kind = ?
          AND (number LIKE ? OR party_name LIKE ? OR party_phone LIKE ?
               OR id IN (SELECT invoice_id FROM invoice_items
                         WHERE hsn LIKE ? OR name LIKE ? OR serials LIKE ?))
          ${hasDates ? 'AND invoice_date BETWEEN ? AND ?' : ''}
        ORDER BY id DESC LIMIT 25
      ''', [
        it.name,
        ...List.filled(6, like),
        if (hasDates) ...[from, to],
      ]);
      for (final r in rows) {
        final total = (r['grand_total'] as num).toDouble();
        hits.add(SearchHit(
          type: it,
          id: (r['id'] as num).toInt(),
          title: '${r['number']}  •  ${total.toStringAsFixed(2)}',
          subtitle:
              '${(r['party_name'] as String).isEmpty ? 'No party' : r['party_name']}  •  ${r['invoice_date']}  •  ${(r['is_gst'] as num) == 1 ? 'GST' : 'NON-GST'}',
          date: r['invoice_date'] as String,
        ));
      }
    }

    if (want(SearchType.serial) && !hasDates) {
      final rows = await db.query(
        'serials',
        where:
            'serial LIKE ? OR product_name LIKE ? OR customer_name LIKE ? OR sale_number LIKE ? OR purchase_number LIKE ?',
        whereArgs: List.filled(5, like),
        orderBy: 'id DESC',
        limit: 25,
      );
      for (final r in rows) {
        hits.add(SearchHit(
          type: SearchType.serial,
          id: (r['id'] as num).toInt(),
          title: r['serial'] as String,
          subtitle:
              '${r['product_name']}  •  ${r['status']}${(r['customer_name'] as String).isEmpty ? '' : '  •  ${r['customer_name']}'}',
        ));
      }
    }

    if (want(SearchType.warranty)) {
      final rows = await db.rawQuery('''
        SELECT * FROM serials
        WHERE warranty_expiry IS NOT NULL
          AND (serial LIKE ? OR product_name LIKE ? OR customer_name LIKE ? OR customer_phone LIKE ?)
          ${hasDates ? 'AND warranty_expiry BETWEEN ? AND ?' : ''}
        ORDER BY warranty_expiry LIMIT 25
      ''', [
        ...List.filled(4, like),
        if (hasDates) ...[from, to],
      ]);
      for (final r in rows) {
        hits.add(SearchHit(
          type: SearchType.warranty,
          id: (r['id'] as num).toInt(),
          title: '${r['serial']}  •  expires ${r['warranty_expiry']}',
          subtitle: '${r['product_name']}  •  ${r['customer_name']}',
          date: r['warranty_expiry'] as String,
        ));
      }
    }

    if (want(SearchType.payment)) {
      final rows = await db.rawQuery('''
        SELECT t.*, a.name AS account_name FROM account_txns t
        JOIN accounts a ON a.id = t.account_id
        WHERE (t.note LIKE ? OR t.ref LIKE ? OR t.kind LIKE ? OR CAST(t.amount AS TEXT) LIKE ?)
          ${hasDates ? 'AND t.txn_date BETWEEN ? AND ?' : ''}
        ORDER BY t.txn_date DESC, t.id DESC LIMIT 25
      ''', [
        ...List.filled(4, like),
        if (hasDates) ...[from, to],
      ]);
      for (final r in rows) {
        final isIn = r['direction'] == 'in';
        hits.add(SearchHit(
          type: SearchType.payment,
          id: (r['id'] as num).toInt(),
          title:
              '${isIn ? '+' : '-'}${(r['amount'] as num).toStringAsFixed(2)}  •  ${r['kind']}',
          subtitle:
              '${r['account_name']}  •  ${r['txn_date']}  •  ${'${r['ref']} ${r['note']}'.trim()}',
          date: r['txn_date'] as String,
        ));
      }
    }

    return hits;
  }
}
