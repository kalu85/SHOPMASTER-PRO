import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/account.dart';

class AccountRepository {
  AccountRepository._();
  static final AccountRepository instance = AccountRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  /// Accept only real calendar dates in the app's yyyy-MM-dd format.
  static bool _isIsoDate(String value) {
    if (value.length != 10 || value[4] != '-' || value[7] != '-') return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null &&
        parsed.year.toString().padLeft(4, '0') == value.substring(0, 4) &&
        parsed.month.toString().padLeft(2, '0') == value.substring(5, 7) &&
        parsed.day.toString().padLeft(2, '0') == value.substring(8, 10);
  }

  static void validateManualTransaction({
    required int accountId,
    required double amount,
    required String date,
  }) {
    if (accountId <= 0) throw ArgumentError('Choose a valid cash/bank account.');
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be finite and greater than zero.');
    }
    if (!_isIsoDate(date)) throw ArgumentError('Transaction date must be a valid yyyy-MM-dd date.');
  }

  static void validateExpense({
    required String category,
    required String date,
    required double amount,
    required int accountId,
    int? id,
    required String payMode,
  }) {
    if (id != null && id <= 0) throw ArgumentError('Expense ID must be valid.');
    if (category.trim().isEmpty) throw ArgumentError('Expense category cannot be blank.');
    if (payMode.trim().isEmpty) throw ArgumentError('Payment mode cannot be blank.');
    if (accountId <= 0) throw ArgumentError('Choose a valid cash/bank account.');
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be finite and greater than zero.');
    }
    if (!_isIsoDate(date)) throw ArgumentError('Expense date must be a valid yyyy-MM-dd date.');
  }

  static const String _balanceSql = '''
    SELECT a.*, a.opening_balance + COALESCE(SUM(
      CASE t.direction WHEN 'in' THEN t.amount WHEN 'out' THEN -t.amount ELSE 0 END
    ), 0) AS balance
    FROM accounts a LEFT JOIN account_txns t ON t.account_id = a.id
  ''';

  /// All accounts with their live balance, cash first.
  Future<List<Account>> accounts() async {
    final db = await _db;
    final rows = await db.rawQuery(
        "$_balanceSql GROUP BY a.id ORDER BY CASE a.kind WHEN 'cash' THEN 0 ELSE 1 END, a.name COLLATE NOCASE");
    return rows.map(Account.fromMap).toList();
  }

  Future<int> addBank(Account a) async {
    final db = await _db;
    return db.insert('accounts', {
      'kind': 'bank',
      'name': a.name,
      'bank_name': a.bankName,
      'account_no': a.accountNo,
      'ifsc': a.ifsc,
      'upi_id': a.upiId,
      'opening_balance': a.openingBalance,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateDetails(Account a) async {
    final db = await _db;
    await db.update(
      'accounts',
      {
        'name': a.name,
        'bank_name': a.bankName,
        'account_no': a.accountNo,
        'ifsc': a.ifsc,
        'upi_id': a.upiId,
      },
      where: 'id = ?',
      whereArgs: [a.id],
    );
  }

  /// Only bank accounts with no transactions can be deleted.
  Future<bool> deleteBank(int id) async {
    final db = await _db;
    final used = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM account_txns WHERE account_id = ?', [id])) ??
        0;
    if (used > 0) return false;
    await db.delete('accounts', where: "id = ? AND kind = 'bank'", whereArgs: [id]);
    return true;
  }

  Future<double> totalBalance(String kind) async {
    final list = await accounts();
    return list
        .where((a) => a.kind == kind)
        .fold<double>(0, (s, a) => s + a.balance);
  }

  Future<List<AccountTxn>> txns({int? accountId, int limit = 200}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT t.*, a.name AS account_name FROM account_txns t '
      'JOIN accounts a ON a.id = t.account_id '
      '${accountId == null ? '' : 'WHERE t.account_id = ? '}'
      'ORDER BY t.txn_date DESC, t.id DESC LIMIT $limit',
      [if (accountId != null) accountId],
    );
    return rows.map(AccountTxn.fromMap).toList();
  }

  /// Validates transfer inputs before any account history is changed.
  static void validateTransfer({
    required int fromId,
    required int toId,
    required double amount,
  }) {
    if (fromId <= 0 || toId <= 0) {
      throw ArgumentError('Choose two valid accounts.');
    }
    if (fromId == toId) {
      throw ArgumentError('Choose two different accounts.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be finite and greater than zero.');
    }
  }

  /// Moves money between two accounts (bank transfer, cash deposit or
  /// cash withdrawal). Both sides are saved together or not at all.
  Future<void> transfer({
    required int fromId,
    required int toId,
    required double amount,
    required String kind,
    required String date,
    String note = '',
  }) async {
    validateTransfer(fromId: fromId, toId: toId, amount: amount);
    final db = await _db;
    await db.transaction((txn) async {
      final accounts = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id IN (?, ?)',
        whereArgs: [fromId, toId],
      );
      if (accounts.length != 2) {
        throw StateError('One of the selected accounts no longer exists. Refresh and try again.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.insert('account_txns', {
        'account_id': fromId,
        'direction': 'out',
        'amount': amount,
        'kind': kind,
        'ref': '',
        'note': note,
        'txn_date': date,
        'created_at': now,
      });
      await txn.insert('account_txns', {
        'account_id': toId,
        'direction': 'in',
        'amount': amount,
        'kind': kind,
        'ref': '',
        'note': note,
        'txn_date': date,
        'created_at': now,
      });
    });
  }

  Future<void> addManualTxn({
    required int accountId,
    required bool isIn,
    required double amount,
    required String date,
    String note = '',
  }) async {
    validateManualTransaction(accountId: accountId, amount: amount, date: date);
    final db = await _db;
    await db.insert('account_txns', {
      'account_id': accountId,
      'direction': isIn ? 'in' : 'out',
      'amount': amount,
      'kind': 'other',
      'ref': '',
      'note': note,
      'txn_date': date,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ---- Expenses ----

  Future<int> addExpense({
    required String category,
    required String date,
    required double amount,
    required int accountId,
    required String payMode,
    String notes = '',
  }) async {
    validateExpense(category: category, date: date, amount: amount, accountId: accountId, payMode: payMode);
    final db = await _db;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('expenses', {
        'category': category,
        'expense_date': date,
        'amount': amount,
        'account_id': accountId,
        'pay_mode': payMode,
        'notes': notes,
        'created_at': now,
      });
      await txn.insert('account_txns', {
        'account_id': accountId,
        'direction': 'out',
        'amount': amount,
        'kind': 'expense',
        'ref': 'EXP-$id',
        'note': category,
        'txn_date': date,
        'created_at': now,
      });
      return id;
    });
  }

  Future<void> deleteExpense(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('account_txns',
          where: "kind = 'expense' AND ref = ?", whereArgs: ['EXP-$id']);
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Replaces an expense and its linked account transaction atomically.
  /// The old account entry is removed before the corrected one is recorded.
  Future<void> updateExpense({
    required int id,
    required String category,
    required String date,
    required double amount,
    required int accountId,
    required String payMode,
    String notes = '',
  }) async {
    validateExpense(id: id, category: category, date: date, amount: amount, accountId: accountId, payMode: payMode);
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'expenses',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isEmpty) {
        throw StateError('This expense no longer exists. Refresh and try again.');
      }
      final account = await txn.query(
        'accounts',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [accountId],
      );
      if (account.isEmpty) {
        throw StateError('The selected cash/bank account no longer exists.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'expenses',
        {
          'category': category,
          'expense_date': date,
          'amount': amount,
          'account_id': accountId,
          'pay_mode': payMode,
          'notes': notes,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'account_txns',
        where: "kind = 'expense' AND ref = ?",
        whereArgs: ['EXP-$id'],
      );
      await txn.insert('account_txns', {
        'account_id': accountId,
        'direction': 'out',
        'amount': amount,
        'kind': 'expense',
        'ref': 'EXP-$id',
        'note': category,
        'txn_date': date,
        'created_at': now,
      });
    });
  }

  Future<List<Expense>> expenses({String? from, String? to}) async {
    final db = await _db;
    final rows = await db.query(
      'expenses',
      where: (from != null && to != null)
          ? 'expense_date >= ? AND expense_date <= ?'
          : null,
      whereArgs: (from != null && to != null) ? [from, to] : null,
      orderBy: 'expense_date DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> expenseTotal(String from, String to) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM expenses '
      'WHERE expense_date >= ? AND expense_date <= ?',
      [from, to],
    );
    return (rows.first['t'] as num).toDouble();
  }
}
