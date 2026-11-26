import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/utils/expiry_report_export.dart';

void main() {
  group('buildExpiryReportCsv', () {
    test('exports expiry details and makes quantity limitation explicit', () {
      final csv = buildExpiryReportCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [
          ExpiryExportRow(
            item: 'Milk',
            batchNumber: 'B-01',
            purchasedQuantity: 12,
            purchaseInvoice: 'PUR-001',
            supplier: 'ABC Traders',
            expiryDate: '2026-12-01',
            daysLeft: 5,
          ),
        ],
      );

      expect(csv, startsWith('\uFEFF'));
      expect(csv, contains('remaining batch stock is not tracked'));
      expect(csv, contains('"Milk","B-01","12.0","PUR-001","ABC Traders"'));
      expect(csv, contains('"5","Upcoming"'));
    });

    test('escapes supplier and item text safely for spreadsheets', () {
      final csv = buildExpiryReportCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [
          ExpiryExportRow(
            item: '=1+1',
            batchNumber: 'B,02',
            purchasedQuantity: 1,
            purchaseInvoice: 'PUR-002',
            supplier: '@SUM(A1:A2)',
            expiryDate: '2026-11-20',
            daysLeft: -6,
          ),
        ],
      );

      expect(csv, contains('"\'=1+1"'));
      expect(csv, contains('"B,02"'));
      expect(csv, contains('"\'@SUM(A1:A2)"'));
      expect(csv, contains('"Expired"'));
    });

    test('labels missing days as date unavailable', () {
      const row = ExpiryExportRow(
        item: 'Item',
        batchNumber: '',
        purchasedQuantity: 2,
        purchaseInvoice: 'PUR-003',
        supplier: '',
        expiryDate: 'invalid',
        daysLeft: null,
      );
      expect(row.status, 'Date unavailable');
    });

    test('exports a header when there are no rows', () {
      final csv = buildExpiryReportCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [],
      );
      expect(csv, contains('"Item","Batch number"'));
    });
  });
}
