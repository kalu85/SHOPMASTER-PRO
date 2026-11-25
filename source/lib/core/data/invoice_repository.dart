import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/invoice.dart';
import '../models/serial.dart';
import '../utils/serials.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class InvoiceRepository {
  InvoiceRepository._();
  static final InvoiceRepository instance = InvoiceRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  /// +1 adds stock, -1 removes stock, 0 leaves stock alone.
  ///   sale invoice -> -1, sale return -> +1,
  ///   purchase invoice -> +1, purchase return -> -1, quotation -> 0.
  static int stockDirection(InvoiceKind k, DocType d) {
    if (d == DocType.quotation) return 0;
    final sale = k == InvoiceKind.sale;
    final isReturn = d == DocType.returnNote;
    return (sale != isReturn) ? -1 : 1;
  }

  /// Party balance: invoices add the unpaid amount, returns reduce it.
  static int balanceDirection(DocType d) =>
      d == DocType.returnNote ? -1 : 1;

  /// True when money comes INTO a cash/bank account for this document.
  /// Sale invoice and purchase return bring money in; the others pay out.
  static bool moneyComesIn(InvoiceKind k, DocType d) =>
      stockDirection(k, d) == -1;

  /// Saves the document, updates stock, serials, the party balance and the
  /// cash/bank account, all in one transaction (all or nothing).
  /// Returns the new document number. Throws [SerialException] if a serial
  /// number breaks a rule; nothing is saved in that case.
  Future<String> create(Invoice draft, List<InvoiceItem> items) async {
    final db = await _db;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // Automatic numbering, never reused.
      final key = '${draft.kind.name}_${docTypeToDb(draft.docType)}';
      final rows =
          await txn.query('counters', where: 'key = ?', whereArgs: [key]);
      final next = (rows.isEmpty ? 0 : (rows.first['value'] as int)) + 1;
      await txn.insert(
        'counters',
        {'key': key, 'value': next},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      var prefix = numberPrefix(draft.kind, draft.docType);
      if (draft.kind == InvoiceKind.sale && draft.docType == DocType.invoice) {
        final p = await txn
            .query('settings', where: "key = 'invoice_prefix'", limit: 1);
        final custom =
            p.isEmpty ? '' : (p.first['value'] as String).trim();
        if (custom.isNotEmpty) prefix = custom;
      }
      final number = '$prefix-${next.toString().padLeft(4, '0')}';

      final invoiceId = await txn.insert('invoices', {
        ...draft.toMap(),
        'number': number,
        'created_at': now,
      });

      await _applyEffects(txn, draft, items, invoiceId, number, now);
      return number;
    });
  }

  /// Writes the lines and applies stock, serial, party and account effects.
  Future<void> _applyEffects(
    Transaction txn,
    Invoice draft,
    List<InvoiceItem> items,
    int invoiceId,
    String number,
    String now,
  ) async {
    for (final it in items) {
      await txn.insert('invoice_items', it.toMap(invoiceId));
    }

    // Stock (service items and custom items never change inventory).
    final dir = stockDirection(draft.kind, draft.docType);
    if (dir != 0) {
      for (final it in items) {
        final pid = it.productId;
        if (pid == null) continue;
        final change = dir * it.qty;
        final updated = await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ? '
          'WHERE id = ? AND is_service = 0',
          [change, pid],
        );
        if (updated > 0) {
          await txn.insert('stock_movements', {
            'product_id': pid,
            'qty_change': change,
            'reason': '${docTitle(draft.kind, draft.docType)} $number',
            'note': '',
            'created_at': now,
          });
        }
      }
    }

    // Serial numbers and warranty.
    if (draft.docType != DocType.quotation) {
      for (final it in items) {
        final list = parseSerials(it.serials);
        for (final s in list) {
          await _applySerial(txn, draft, it, s, invoiceId, number, now);
        }
      }
    }

    // Party balance (quotations never touch it).
    final partyId = draft.partyId;
    if (partyId != null && draft.docType != DocType.quotation) {
      final delta = balanceDirection(draft.docType) * draft.due;
      if (delta != 0) {
        await txn.rawUpdate(
          'UPDATE parties SET current_balance = current_balance + ? '
          'WHERE id = ?',
          [delta, partyId],
        );
      }
    }

    // Cash / bank account entry for the money actually paid or received.
    if (draft.docType != DocType.quotation && draft.paid > 0) {
      var accountId = draft.accountId;
      if (accountId == null) {
        final cash = await txn.query('accounts',
            where: "kind = 'cash'", limit: 1);
        if (cash.isNotEmpty) accountId = cash.first['id'] as int?;
      }
      if (accountId != null) {
        final kindLabel = switch ((draft.kind, draft.docType)) {
          (InvoiceKind.sale, DocType.returnNote) => 'sale_return',
          (InvoiceKind.purchase, DocType.returnNote) => 'purchase_return',
          (InvoiceKind.sale, _) => 'sale',
          _ => 'purchase',
        };
        await txn.insert('account_txns', {
          'account_id': accountId,
          'direction': moneyComesIn(draft.kind, draft.docType) ? 'in' : 'out',
          'amount': draft.paid,
          'kind': kindLabel,
          'ref': number,
          'note': draft.partyName,
          'txn_date': draft.invoiceDate,
          'created_at': now,
        });
      }
    }
  }

  static String _txnKind(InvoiceKind k, DocType d) => switch ((k, d)) {
        (InvoiceKind.sale, DocType.returnNote) => 'sale_return',
        (InvoiceKind.purchase, DocType.returnNote) => 'purchase_return',
        (InvoiceKind.sale, _) => 'sale',
        _ => 'purchase',
      };

  /// Undoes everything a saved document did: stock, serials, the party
  /// balance and the cash/bank entry. Throws [SerialException] when a serial
  /// number has moved on and the change would leave bad data.
  Future<void> _reverse(Transaction txn, Invoice old, List<InvoiceItem> items,
      String now) async {
    if (old.docType == DocType.quotation) return;
    final id = old.id!;

    // Serial numbers.
    if (old.docType == DocType.returnNote) {
      if (items.any((i) => parseSerials(i.serials).isNotEmpty)) {
        throw SerialException(
            'Returns that carry serial numbers cannot be changed or deleted');
      }
    } else if (old.kind == InvoiceKind.sale) {
      final rows = await txn
          .query('serials', where: 'sale_invoice_id = ?', whereArgs: [id]);
      for (final r in rows) {
        final boughtHere = r['purchase_invoice_id'] == null;
        if (boughtHere) {
          await txn.delete('serials', where: 'id = ?', whereArgs: [r['id']]);
        } else {
          await txn.update(
            'serials',
            {
              'status': 'in_stock',
              'sale_invoice_id': null,
              'sale_number': '',
              'customer_id': null,
              'customer_name': '',
              'customer_phone': '',
              'sold_date': null,
              'warranty_months': 0,
              'warranty_start': null,
              'warranty_expiry': null,
            },
            where: 'id = ?',
            whereArgs: [r['id']],
          );
        }
      }
    } else {
      final rows = await txn.query('serials',
          where: 'purchase_invoice_id = ?', whereArgs: [id]);
      for (final r in rows) {
        if (r['status'] != 'in_stock') {
          throw SerialException(
              'Serial "${r['serial']}" is already ${r['status']}, so this purchase cannot be changed');
        }
      }
      for (final r in rows) {
        await txn.delete('serials', where: 'id = ?', whereArgs: [r['id']]);
      }
    }

    // Stock.
    final dir = stockDirection(old.kind, old.docType);
    if (dir != 0) {
      for (final it in items) {
        final pid = it.productId;
        if (pid == null) continue;
        final change = -dir * it.qty;
        final updated = await txn.rawUpdate(
          'UPDATE products SET current_stock = current_stock + ? '
          'WHERE id = ? AND is_service = 0',
          [change, pid],
        );
        if (updated > 0) {
          await txn.insert('stock_movements', {
            'product_id': pid,
            'qty_change': change,
            'reason': 'Reversed ${old.number}',
            'note': '',
            'created_at': now,
          });
        }
      }
    }

    // Party balance.
    if (old.partyId != null) {
      final delta = -balanceDirection(old.docType) * old.due;
      if (delta != 0) {
        await txn.rawUpdate(
          'UPDATE parties SET current_balance = current_balance + ? '
          'WHERE id = ?',
          [delta, old.partyId],
        );
      }
    }

    // Cash / bank entry.
    await txn.delete('account_txns',
        where: 'ref = ? AND kind = ?',
        whereArgs: [old.number, _txnKind(old.kind, old.docType)]);
  }

  /// Deletes a saved document and puts stock, serials, the party balance and
  /// the cash/bank balance back as they were. The number is never reused.
  Future<void> delete(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows =
          await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final old = Invoice.fromMap(rows.first);
      final itemRows = await txn
          .query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final items = itemRows.map(InvoiceItem.fromMap).toList();
      await _reverse(txn, old, items, DateTime.now().toIso8601String());
      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Replaces a saved document. The number and id stay the same. The old
  /// effects are undone and the new ones applied in one transaction, so a
  /// failure (for example a serial problem) changes nothing.
  Future<void> update(int id, Invoice draft, List<InvoiceItem> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows =
          await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Document no longer exists');
      final old = Invoice.fromMap(rows.first);
      final itemRows = await txn
          .query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      final oldItems = itemRows.map(InvoiceItem.fromMap).toList();
      final now = DateTime.now().toIso8601String();
      await _reverse(txn, old, oldItems, now);
      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      await txn.update(
        'invoices',
        {...draft.toMap(), 'number': old.number},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _applyEffects(txn, draft, items, id, old.number, now);
    });
  }

  Future<void> _applySerial(
    Transaction txn,
    Invoice draft,
    InvoiceItem it,
    String serial,
    int invoiceId,
    String number,
    String now,
  ) async {
    final found =
        await txn.query('serials', where: 'serial = ?', whereArgs: [serial]);
    final row = found.isEmpty ? null : found.first;
    final isSale = draft.kind == InvoiceKind.sale;
    final isReturn = draft.docType == DocType.returnNote;

    if (isSale && !isReturn) {
      // Selling a serial.
      if (row != null) {
        if (row['status'] == 'sold') {
          throw SerialException(
              'Serial "$serial" is already sold (${row['sale_number']})');
        }
        if (row['status'] == 'returned') {
          throw SerialException(
              'Serial "$serial" was returned to the supplier');
        }
        final pid = row['product_id'] as int?;
        if (pid != null && it.productId != null && pid != it.productId) {
          throw SerialException('Serial "$serial" belongs to a different item');
        }
      }
      final sold = DateTime.parse(draft.invoiceDate);
      final months = it.warrantyMonths;
      final values = <String, Object?>{
        'sale_invoice_id': draft.kind == InvoiceKind.sale ? invoiceId : null,
        'sale_number': number,
        'customer_id': draft.partyId,
        'customer_name': draft.partyName,
        'customer_phone': draft.partyPhone,
        'sold_date': draft.invoiceDate,
        'warranty_months': months,
        'warranty_start': months > 0 ? draft.invoiceDate : null,
        'warranty_expiry': months > 0 ? _iso(addMonths(sold, months)) : null,
        'status': 'sold',
      };
      if (row == null) {
        await txn.insert('serials', {
          'serial': serial,
          'product_id': it.productId,
          'product_name': it.name,
          ...values,
          'created_at': now,
        });
      } else {
        await txn.update('serials', values,
            where: 'id = ?', whereArgs: [row['id']]);
      }
    } else if (!isSale && !isReturn) {
      // Buying a serial.
      if (row != null) {
        throw SerialException('Serial "$serial" already exists');
      }
      await txn.insert('serials', {
        'serial': serial,
        'product_id': it.productId,
        'product_name': it.name,
        'purchase_invoice_id': invoiceId,
        'purchase_number': number,
        'status': 'in_stock',
        'created_at': now,
      });
    } else if (isSale && isReturn) {
      // Customer returns an item: back in stock, warranty cleared.
      if (row != null && row['status'] == 'sold') {
        await txn.update(
          'serials',
          {
            'status': 'in_stock',
            'sale_invoice_id': null,
            'sale_number': '',
            'customer_id': null,
            'customer_name': '',
            'customer_phone': '',
            'sold_date': null,
            'warranty_months': 0,
            'warranty_start': null,
            'warranty_expiry': null,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    } else {
      // Purchase return: item goes back to the supplier.
      if (row != null) {
        if (row['status'] == 'sold') {
          throw SerialException(
              'Serial "$serial" is sold and cannot be returned to the supplier');
        }
        await txn.update('serials', {'status': 'returned'},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  /// Saves a mobile number on a document (used before sending on WhatsApp).
  Future<void> setPartyPhone(int id, String phone) async {
    final db = await _db;
    await db.update('invoices', {'party_phone': phone},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Invoice?> byNumber(InvoiceKind kind, DocType docType, String number) async {
    final db = await _db;
    final rows = await db.query('invoices',
        where: 'kind = ? AND doc_type = ? AND number = ?',
        whereArgs: [kind.name, docTypeToDb(docType), number],
        limit: 1);
    return rows.isEmpty ? null : Invoice.fromMap(rows.first);
  }

  Future<Invoice?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Invoice.fromMap(rows.first);
  }

  Future<List<Invoice>> list(
    InvoiceKind kind,
    DocType docType, {
    String query = '',
  }) async {
    final db = await _db;
    final q = query.trim();
    final rows = await db.query(
      'invoices',
      where: q.isEmpty
          ? 'kind = ? AND doc_type = ?'
          : 'kind = ? AND doc_type = ? AND (number LIKE ? OR party_name LIKE ? OR party_phone LIKE ?)',
      whereArgs: [
        kind.name,
        docTypeToDb(docType),
        if (q.isNotEmpty) ...List.filled(3, '%$q%'),
      ],
      orderBy: 'id DESC',
      limit: 300,
    );
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<InvoiceItem>> items(int invoiceId) async {
    final db = await _db;
    final rows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id',
    );
    return rows.map(InvoiceItem.fromMap).toList();
  }

  /// Latest documents of any kind (invoices and returns, no quotations).
  Future<List<Invoice>> recent({int limit = 5}) async {
    final db = await _db;
    final rows = await db.query(
      'invoices',
      where: "doc_type != 'quotation'",
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(Invoice.fromMap).toList();
  }

  /// Net total for a date (yyyy-MM-dd): invoices minus returns.
  Future<double> netTotalOn(InvoiceKind kind, String isoDate) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE doc_type WHEN 'invoice' THEN grand_total "
      "WHEN 'return' THEN -grand_total ELSE 0 END), 0) AS total "
      'FROM invoices WHERE kind = ? AND invoice_date = ?',
      [kind.name, isoDate],
    );
    return (rows.first['total'] as num).toDouble();
  }
}
