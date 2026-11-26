import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/utils/stock_reorder_export.dart';

void main() {
  group('buildStockReorderCsv', () {
    test('writes the reorder worksheet and estimated cost', () {
      final csv = buildStockReorderCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [
          StockReorderCsvRow(
            supplier: 'ABC Traders',
            item: 'USB Cable',
            currentStock: 2,
            minimumStock: 5,
            soldLast30Days: 12,
            suggestedOrderQty: 10,
            purchaseRate: 25.5,
          ),
        ],
      );

      expect(csv, contains('Supplier'));
      expect(csv, contains('"ABC Traders","USB Cable"'));
      expect(csv, contains('"10","25.5","255.0"'));
      expect(csv, startsWith('\uFEFF'));
    });

    test('escapes commas, quotes and line breaks in supplier and item names', () {
      final csv = buildStockReorderCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [
          StockReorderCsvRow(
            supplier: 'ABC, "Wholesale"',
            item: 'Cable\nType A',
            currentStock: 0,
            minimumStock: 2,
            soldLast30Days: 1,
            suggestedOrderQty: 4,
            purchaseRate: 10,
          ),
        ],
      );

      expect(csv, contains('"ABC, ""Wholesale"""'));
      expect(csv, contains('"Cable\nType A"'));
    });

    test('exports only the header when there are no reorder items', () {
      final csv = buildStockReorderCsv(
        preparedAt: DateTime.utc(2026, 11, 26),
        rows: const [],
      );
      expect(csv.split('\n').where((line) => line.isNotEmpty).length, 1);
    });
  });
}
