import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/account_repository.dart';

void main() {
  group('AccountRepository transfer validation', () {
    test('accepts a positive finite transfer between different accounts', () {
      expect(
        () => AccountRepository.validateTransfer(
          fromId: 1,
          toId: 2,
          amount: 125.50,
        ),
        returnsNormally,
      );
    });

    test('rejects transferring an account to itself', () {
      expect(
        () => AccountRepository.validateTransfer(
          fromId: 1,
          toId: 1,
          amount: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid account identifiers', () {
      expect(
        () => AccountRepository.validateTransfer(
          fromId: 0,
          toId: 2,
          amount: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rejects zero and negative amounts', () {
      for (final amount in [0.0, -1.0]) {
        expect(
          () => AccountRepository.validateTransfer(
            fromId: 1,
            toId: 2,
            amount: amount,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects non-finite amounts', () {
      for (final amount in [double.nan, double.infinity, double.negativeInfinity]) {
        expect(
          () => AccountRepository.validateTransfer(
            fromId: 1,
            toId: 2,
            amount: amount,
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
