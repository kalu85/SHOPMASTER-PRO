import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/utils/serials.dart';

void main() {
  group('serialKey', () {
    test('trims and compares serial identifiers without letter-case differences', () {
      expect(serialKey('  AbC-123  '), 'abc-123');
      expect(serialKey('ABC-123'), serialKey('abc-123'));
    });
  });

  group('parseSerials', () {
    test('splits on commas, new lines and semicolons and trims', () {
      expect(parseSerials('A1, B2\nC3;  D4 ,, '), ['A1', 'B2', 'C3', 'D4']);
    });
    test('empty text gives no serials', () {
      expect(parseSerials('  \n , '), isEmpty);
    });
  });

  group('addMonths', () {
    test('simple month', () {
      expect(addMonths(DateTime(2026, 11, 24), 1), DateTime(2026, 12, 24));
    });
    test('year rollover', () {
      expect(addMonths(DateTime(2026, 11, 24), 3), DateTime(2027, 2, 24));
    });
    test('12 months is one year', () {
      expect(addMonths(DateTime(2026, 11, 24), 12), DateTime(2027, 11, 24));
    });
    test('31 Jan + 1 month clamps to end of February', () {
      expect(addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });
    test('36 months', () {
      expect(addMonths(DateTime(2026, 2, 28), 36), DateTime(2029, 2, 28));
    });
  });

  group('warrantyState', () {
    final now = DateTime(2026, 11, 24, 15, 30);
    test('no expiry means no warranty', () {
      expect(warrantyState(null, now), WarrantyState.none);
      expect(warrantyState('', now), WarrantyState.none);
    });
    test('expired yesterday', () {
      expect(warrantyState('2026-11-23', now), WarrantyState.expired);
    });
    test('expires today is still valid (expiring)', () {
      expect(warrantyState('2026-11-24', now), WarrantyState.expiring);
    });
    test('within 30 days is expiring, after is active', () {
      expect(warrantyState('2026-12-24', now), WarrantyState.expiring);
      expect(warrantyState('2026-12-25', now), WarrantyState.active);
    });
  });

  test('warrantyLabel', () {
    expect(warrantyLabel(0), '-');
    expect(warrantyLabel(6), '6 months');
    expect(warrantyLabel(12), '1 year');
    expect(warrantyLabel(24), '2 years');
    expect(warrantyLabel(18), '18 months');
  });

  group('purchaseReturnSerialError', () {
    test('rejects a serial missing from the register', () {
      expect(
        purchaseReturnSerialError(
          serial: 'SN-1', exists: false, status: 'in_stock'),
        contains('not found'),
      );
    });
    test('rejects sold and already returned serials', () {
      expect(
        purchaseReturnSerialError(
          serial: 'SN-1', exists: true, status: 'sold'),
        contains('sold'),
      );
      expect(
        purchaseReturnSerialError(
          serial: 'SN-1', exists: true, status: 'returned'),
        contains('already returned'),
      );
    });
    test('rejects a serial belonging to another product', () {
      expect(
        purchaseReturnSerialError(
          serial: 'SN-1',
          exists: true,
          status: 'in_stock',
          serialProductId: 10,
          itemProductId: 11,
        ),
        contains('different item'),
      );
    });
    test('accepts an in-stock serial for the matching product', () {
      expect(
        purchaseReturnSerialError(
          serial: 'SN-1',
          exists: true,
          status: 'in_stock',
          serialProductId: 10,
          itemProductId: 10,
        ),
        isNull,
      );
    });
  });
}
