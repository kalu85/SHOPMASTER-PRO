import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/account_repository.dart';
import 'package:shopmaster_pro/core/data/report_repository.dart';

void main() {
  group('AccountRepository manual transaction validation', () {
    test('accepts valid manual cash/bank entries', () {
      expect(() => AccountRepository.validateManualTransaction(
        accountId: 1, amount: 250.50, date: '2026-11-26'), returnsNormally);
    });

    test('rejects invalid account, amount and date', () {
      expect(() => AccountRepository.validateManualTransaction(
        accountId: 0, amount: 10, date: '2026-11-26'), throwsArgumentError);
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => AccountRepository.validateManualTransaction(
          accountId: 1, amount: amount, date: '2026-11-26'), throwsArgumentError);
      }
      for (final date in ['2026-02-30', '26-11-2026', '']) {
        expect(() => AccountRepository.validateManualTransaction(
          accountId: 1, amount: 10, date: date), throwsArgumentError);
      }
    });
  });

  group('AccountRepository expense validation', () {
    test('accepts valid expense data for create and update', () {
      expect(() => AccountRepository.validateExpense(
        category: 'Rent', date: '2026-11-26', amount: 5000,
        accountId: 1, payMode: 'Bank'), returnsNormally);
      expect(() => AccountRepository.validateExpense(
        id: 12, category: 'Rent', date: '2026-11-26', amount: 5000,
        accountId: 1, payMode: 'Bank'), returnsNormally);
    });

    test('rejects blank category or payment mode', () {
      expect(() => AccountRepository.validateExpense(
        category: '  ', date: '2026-11-26', amount: 10,
        accountId: 1, payMode: 'Cash'), throwsArgumentError);
      expect(() => AccountRepository.validateExpense(
        category: 'Rent', date: '2026-11-26', amount: 10,
        accountId: 1, payMode: '  '), throwsArgumentError);
    });

    test('rejects invalid amounts, account IDs, expense IDs and dates', () {
      expect(() => AccountRepository.validateExpense(
        id: 0, category: 'Rent', date: '2026-11-26', amount: 10,
        accountId: 1, payMode: 'Cash'), throwsArgumentError);
      expect(() => AccountRepository.validateExpense(
        category: 'Rent', date: '2026-11-26', amount: 10,
        accountId: -1, payMode: 'Cash'), throwsArgumentError);
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => AccountRepository.validateExpense(
          category: 'Rent', date: '2026-11-26', amount: amount,
          accountId: 1, payMode: 'Cash'), throwsArgumentError);
      }
      expect(() => AccountRepository.validateExpense(
        category: 'Rent', date: '2026-02-30', amount: 10,
        accountId: 1, payMode: 'Cash'), throwsArgumentError);
    });
  });
  group('AccountRepository account detail validation', () {
    test('accepts named accounts and finite opening balances', () {
      expect(() => AccountRepository.validateAccountDetails(
        name: 'Main Bank', openingBalance: -250.0), returnsNormally);
    });

    test('rejects blank names, invalid IDs and non-finite balances', () {
      expect(() => AccountRepository.validateAccountDetails(
        name: '  ', openingBalance: 0), throwsArgumentError);
      expect(() => AccountRepository.validateAccountDetails(
        name: 'Cash', openingBalance: double.nan), throwsArgumentError);
      expect(() => AccountRepository.validateAccountDetails(
        name: 'Cash', openingBalance: double.infinity), throwsArgumentError);
      expect(() => AccountRepository.validateAccountDetails(
        name: 'Cash', openingBalance: 0, id: 0), throwsArgumentError);
    });
  });


  group('cash and bank report period balances', () {
    test('calculates opening and closing balances with prior and period activity', () {
      final result = accountPeriodBalances(
        accountOpeningBalance: 1000,
        priorNet: 250,
        periodIn: 500,
        periodOut: 300,
      );
      expect(result.opening, 1250);
      expect(result.closing, 1450);
    });

    test('supports overdraft and outgoing-heavy periods', () {
      final result = accountPeriodBalances(
        accountOpeningBalance: 100,
        priorNet: -250,
        periodIn: 20,
        periodOut: 70,
      );
      expect(result.opening, -150);
      expect(result.closing, -200);
    });

    test('rejects non-finite balance inputs and overflow', () {
      expect(
        () => accountPeriodBalances(
          accountOpeningBalance: double.infinity,
          priorNet: 0,
          periodIn: 0,
          periodOut: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => accountPeriodBalances(
          accountOpeningBalance: double.maxFinite,
          priorNet: double.maxFinite,
          periodIn: 0,
          periodOut: 0,
        ),
        throwsArgumentError,
      );
    });
  });

}
