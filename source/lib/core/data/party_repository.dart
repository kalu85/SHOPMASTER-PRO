import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/party.dart';

/// One line of a party ledger (an invoice, return, receipt or payment).
class LedgerEntry {
  const LedgerEntry({
    required this.date,
    required this.description,
    required this.change,
  });

  final String date;
  final String description;

  /// Positive increases what the customer owes (or what you owe a supplier).
  final double change;
}

class PartyRepository {
  PartyRepository._();
  static final PartyRepository instance = PartyRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<Party?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('parties', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Party.fromMap(rows.first);
  }

  Future<List<Party>> list(PartyType type, {String query = ''}) async {
    final db = await _db;
    final q = query.trim();
    final rows = q.isEmpty
        ? await db.query(
            'parties',
            where: 'type = ?',
            whereArgs: [type.name],
            orderBy: 'name COLLATE NOCASE',
          )
        : await db.query(
            'parties',
            where:
                'type = ? AND (name LIKE ? OR phone LIKE ? OR email LIKE ? OR gstin LIKE ?)',
            whereArgs: [type.name, ...List.filled(4, '%$q%')],
            orderBy: 'name COLLATE NOCASE',
          );
    return rows.map(Party.fromMap).toList();
  }

  Future<int> insert(Party p) async {
    final db = await _db;
    return db.insert('parties', {
      'type': p.type.name,
      'name': p.name,
      'phone': p.phone,
      'address': p.address,
      'email': p.email,
      'gstin': p.gstin,
      'opening_balance': p.openingBalance,
      'current_balance': p.openingBalance,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Updates contact details only. Balances change through transactions.
  Future<void> update(Party p) async {
    final db = await _db;
    await db.update(
      'parties',
      {
        'name': p.name,
        'phone': p.phone,
        'address': p.address,
        'email': p.email,
        'gstin': p.gstin,
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('parties', where: 'id = ?', whereArgs: [id]);
  }

  /// Sum of positive customer balances (money customers owe you).
  Future<double> customerOutstanding() async {
    final db = await _db;
    final rows = await db.rawQuery(
        "SELECT COALESCE(SUM(current_balance), 0) AS total FROM parties WHERE type = 'customer' AND current_balance > 0");
    return (rows.first['total'] as num).toDouble();
  }

  /// Records money received from a customer or paid to a supplier.
  /// Lowers the balance and adds an entry to the chosen cash/bank account.
  Future<void> recordPayment({
    required int partyId,
    required double amount,
    required int accountId,
    required String payMode,
    required String date,
    String note = '',
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows =
          await txn.query('parties', where: 'id = ?', whereArgs: [partyId]);
      if (rows.isEmpty) return;
      final isCustomer = rows.first['type'] == 'customer';
      final now = DateTime.now().toIso8601String();
      await txn.insert('party_payments', {
        'party_id': partyId,
        'amount': amount,
        'pay_mode': payMode,
        'account_id': accountId,
        'note': note,
        'pay_date': date,
        'created_at': now,
      });
      await txn.rawUpdate(
        'UPDATE parties SET current_balance = current_balance - ? WHERE id = ?',
        [amount, partyId],
      );
      await txn.insert('account_txns', {
        'account_id': accountId,
        'direction': isCustomer ? 'in' : 'out',
        'amount': amount,
        'kind': isCustomer ? 'receipt' : 'payment',
        'ref': '',
        'note': rows.first['name'] as String,
        'txn_date': date,
        'created_at': now,
      });
    });
  }

  /// Ledger: opening balance first, then invoices, returns and payments in
  /// date order. Quotations are not included.
  Future<List<LedgerEntry>> ledger(Party party) async {
    final db = await _db;
    final kind = party.type == PartyType.customer ? 'sale' : 'purchase';
    final inv = await db.query(
      'invoices',
      where: "party_id = ? AND kind = ? AND doc_type != 'quotation'",
      whereArgs: [party.id, kind],
    );
    final pay = await db.query(
      'party_payments',
      where: 'party_id = ?',
      whereArgs: [party.id],
    );

    final entries = <(String, int, LedgerEntry)>[];
    for (final r in inv) {
      final isReturn = r['doc_type'] == 'return';
      final due = (r['due'] as num).toDouble();
      final total = (r['grand_total'] as num).toDouble();
      final paid = (r['paid'] as num).toDouble();
      entries.add((
        r['invoice_date'] as String,
        (r['id'] as num).toInt(),
        LedgerEntry(
          date: r['invoice_date'] as String,
          description:
              '${r['number']}${isReturn ? ' (return)' : ''}  total ${total.toStringAsFixed(2)}, paid ${paid.toStringAsFixed(2)}',
          change: isReturn ? -due : due,
        ),
      ));
    }
    for (final r in pay) {
      entries.add((
        r['pay_date'] as String,
        1000000 + (r['id'] as num).toInt(),
        LedgerEntry(
          date: r['pay_date'] as String,
          description:
              '${party.type == PartyType.customer ? 'Payment received' : 'Payment made'} (${r['pay_mode']})',
          change: -(r['amount'] as num).toDouble(),
        ),
      ));
    }
    entries.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return entries.map((e) => e.$3).toList();
  }

  /// Customers who owe money, biggest first (for payment reminders).
  Future<List<Party>> withDues(PartyType type) async {
    final db = await _db;
    final rows = await db.query(
      'parties',
      where: 'type = ? AND current_balance > 0',
      whereArgs: [type.name],
      orderBy: 'current_balance DESC',
    );
    return rows.map(Party.fromMap).toList();
  }
}
