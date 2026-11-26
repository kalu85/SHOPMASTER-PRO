import 'csv_safety.dart';

/// CSV export for the supplier-wise stock reorder worksheet.
class StockReorderCsvRow {
  const StockReorderCsvRow({
    required this.supplier,
    required this.item,
    required this.currentStock,
    required this.minimumStock,
    required this.soldLast30Days,
    required this.suggestedOrderQty,
    required this.purchaseRate,
  });

  final String supplier;
  final String item;
  final double currentStock;
  final double minimumStock;
  final double soldLast30Days;
  final double suggestedOrderQty;
  final double purchaseRate;

  double get estimatedCost => suggestedOrderQty * purchaseRate;
}

/// Returns UTF-8 CSV text with a BOM for spreadsheet compatibility.
/// All cells are quoted so commas, quotes and line breaks remain safe.
String buildStockReorderCsv({
  required List<StockReorderCsvRow> rows,
  required DateTime preparedAt,
}) {
final output = StringBuffer()
    ..write('\uFEFF')
    ..writeln([
      'Prepared on',
      'Supplier',
      'Item',
      'Current stock',
      'Minimum stock',
      'Units sold (last 30 days)',
      'Suggested order quantity',
      'Purchase rate (INR)',
      'Estimated cost (INR)',
    ].map(csvSafeCell).join(','));

  for (final row in rows) {
    output.writeln([
      preparedAt.toIso8601String(),
      row.supplier,
      row.item,
      row.currentStock,
      row.minimumStock,
      row.soldLast30Days,
      row.suggestedOrderQty,
      row.purchaseRate,
      row.estimatedCost,
    ].map(csvSafeCell).join(','));
  }
  return output.toString();
}
