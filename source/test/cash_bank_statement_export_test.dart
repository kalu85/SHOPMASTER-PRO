import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/models/account.dart';
import 'package:shopmaster_pro/core/utils/cash_bank_statement_export.dart';

void main() {
  group('buildCashBankStatementCsv', () {
    const cash = Account(
      id: 1,
      kind: 'cash',
      name: 'Cash',
      openingBalance: 1000,
    );
    const bank = Account(
      id: 2,
      kind: 'bank',
      name: 'Main Bank',
      openingBalance: 5000,
    );

    test('exports opening balances and chronological running balances', () {
      final csv = buildCashBankStatementCsv(
        accounts: const [cash, bank],
        transactions: const [
          AccountTxn(
            id: 2,
            accountId: 1,
            accountName: 'Cash',
            direction: 'out',
            amount: 200,
            kind: 'expense',
            ref: 'EXP-1',
            note: 'Rent',
            date: '2026-11-02',
          ),
          AccountTxn(
            id: 1,
            accountId: 1,
            accountName: 'Cash',
            direction: 'in',
            amount: 750,
            kind: 'receipt',
            ref: '',
            note: 'Customer payment',
            date: '2026-11-01',
          ),
        ],
      );

      final lines = csv.split('\n');
      expect(csv, startsWith('\uFEFF'));
      expect(csv, contains('"Cash","Opening balance"'));
      expect(csv, contains('"Main Bank","Opening balance"'));
      expect(lines.indexWhere((line) => line.contains('2026-11-01')),
          lessThan(lines.indexWhere((line) => line.contains('2026-11-02'))));
      expect(csv, contains('"750.00","","1750.00"'));
      expect(csv, contains('"","200.00","1550.00"'));
    });

    test('escapes user supplied transaction text safely', () {
      final csv = buildCashBankStatementCsv(
        accounts: const [cash],
        transactions: const [
          AccountTxn(
            id: 1,
            accountId: 1,
            accountName: 'Cash',
            direction: 'in',
            amount: 5,
            kind: 'other',
            ref: '',
            note: '=HYPERLINK("unsafe")',
            date: '2026-11-01',
          ),
        ],
      );
      expect(csv, contains('"\'=HYPERLINK(""unsafe"")"'));
    });

    test('does not export transactions for accounts outside the selection', () {
      final csv = buildCashBankStatementCsv(
        accounts: const [cash],
        transactions: const [
          AccountTxn(
            id: 1,
            accountId: 99,
            accountName: 'Hidden account',
            direction: 'in',
            amount: 10,
            kind: 'receipt',
            ref: '',
            note: '',
            date: '2026-11-01',
          ),
        ],
      );
      expect(csv, isNot(contains('Hidden account')));
    });
  });
}
