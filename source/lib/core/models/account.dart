class Account {
  const Account({
    this.id,
    required this.kind,
    required this.name,
    this.bankName = '',
    this.accountNo = '',
    this.ifsc = '',
    this.upiId = '',
    this.openingBalance = 0,
    this.balance = 0,
  });

  final int? id;

  /// 'cash' or 'bank'
  final String kind;
  final String name;
  final String bankName;
  final String accountNo;
  final String ifsc;
  final String upiId;
  final double openingBalance;

  /// Opening balance plus all money in, minus all money out.
  final double balance;

  bool get isCash => kind == 'cash';

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        kind: m['kind'] as String,
        name: m['name'] as String,
        bankName: m['bank_name'] as String,
        accountNo: m['account_no'] as String,
        ifsc: m['ifsc'] as String,
        upiId: m['upi_id'] as String,
        openingBalance: (m['opening_balance'] as num).toDouble(),
        balance: ((m['balance'] ?? m['opening_balance']) as num).toDouble(),
      );
}

class AccountTxn {
  const AccountTxn({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.direction,
    required this.amount,
    required this.kind,
    required this.ref,
    required this.note,
    required this.date,
  });

  final int id;
  final int accountId;
  final String accountName;

  /// 'in' or 'out'
  final String direction;
  final double amount;
  final String kind;
  final String ref;
  final String note;
  final String date;

  bool get isIn => direction == 'in';

  factory AccountTxn.fromMap(Map<String, Object?> m) => AccountTxn(
        id: (m['id'] as num).toInt(),
        accountId: (m['account_id'] as num).toInt(),
        accountName: (m['account_name'] as String?) ?? '',
        direction: m['direction'] as String,
        amount: (m['amount'] as num).toDouble(),
        kind: m['kind'] as String,
        ref: m['ref'] as String,
        note: m['note'] as String,
        date: m['txn_date'] as String,
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.date,
    required this.amount,
    required this.accountId,
    required this.payMode,
    required this.notes,
  });

  final int id;
  final String category;
  final String date;
  final double amount;
  final int? accountId;
  final String payMode;
  final String notes;

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: (m['id'] as num).toInt(),
        category: m['category'] as String,
        date: m['expense_date'] as String,
        amount: (m['amount'] as num).toDouble(),
        accountId: m['account_id'] as int?,
        payMode: m['pay_mode'] as String,
        notes: m['notes'] as String,
      );
}

const List<String> kExpenseCategories = [
  'Rent',
  'Electricity',
  'Salary',
  'Transport',
  'Tea & Food',
  'Repairs',
  'Internet & Phone',
  'Marketing',
  'Other',
];
