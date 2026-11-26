import '../models/account.dart';
import 'csv_safety.dart';

/// Builds a cash/bank statement with an independent running balance per
/// account. Transactions are ordered oldest first for statement readability.
String buildCashBankStatementCsv({
  required List<Account> accounts,
  required List<AccountTxn> transactions,
}) {
  final byId = {for (final account in accounts) account.id!: account};
  final balances = <int, double>{
    for (final account in accounts) account.id!: account.openingBalance,
  };
  final output = StringBuffer()
    ..write('\uFEFF')
    ..writeln(csvSafeRow([
      'Date',
      'Account',
      'Type',
      'Reference',
      'Description',
      'Money in (INR)',
      'Money out (INR)',
      'Running balance (INR)',
    ]));

  for (final account in accounts) {
    output.writeln(csvSafeRow([
      '',
      account.name,
      'Opening balance',
      '',
      'Opening balance',
      account.openingBalance > 0 ? account.openingBalance.toStringAsFixed(2) : '',
      account.openingBalance < 0 ? (-account.openingBalance).toStringAsFixed(2) : '',
      account.openingBalance.toStringAsFixed(2),
    ]));
  }

  final ordered = [...transactions]
    ..sort((a, b) {
      final dateOrder = a.date.compareTo(b.date);
      return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
    });

  for (final txn in ordered) {
    final account = byId[txn.accountId];
    if (account == null) continue;
    final next = (balances[txn.accountId] ?? 0) +
        (txn.isIn ? txn.amount : -txn.amount);
    balances[txn.accountId] = next;
    output.writeln(csvSafeRow([
      txn.date,
      account.name,
      txn.kind,
      txn.ref,
      txn.note,
      txn.isIn ? txn.amount.toStringAsFixed(2) : '',
      txn.isIn ? '' : txn.amount.toStringAsFixed(2),
      next.toStringAsFixed(2),
    ]));
  }

  return output.toString();
}
