import 'csv_safety.dart';

class ExpiryExportRow {
  const ExpiryExportRow({
    required this.item,
    required this.batchNumber,
    required this.purchasedQuantity,
    required this.purchaseInvoice,
    required this.supplier,
    required this.expiryDate,
    required this.daysLeft,
  });

  final String item;
  final String batchNumber;
  final double purchasedQuantity;
  final String purchaseInvoice;
  final String supplier;
  final String expiryDate;
  final int? daysLeft;

  String get status {
    final days = daysLeft;
    if (days == null) return 'Date unavailable';
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    return 'Upcoming';
  }
}

/// CSV for expiry review. Quantities are original purchase-line quantities,
/// not live remaining batch balances.
String buildExpiryReportCsv({
  required DateTime preparedAt,
  required List<ExpiryExportRow> rows,
}) {
  final output = StringBuffer()
    ..write('\uFEFF')
    ..writeln(csvSafeRow([
      'SHOPMASTER PRO — Batch expiry review',
      'Prepared on',
      preparedAt.toIso8601String(),
    ]))
    ..writeln(csvSafeCell(
      'Important: purchased quantities only; remaining batch stock is not tracked in this report.',
    ))
    ..writeln(csvSafeRow([
      'Item',
      'Batch number',
      'Purchased quantity',
      'Purchase invoice',
      'Supplier',
      'Expiry date',
      'Days left',
      'Status',
    ]));

  for (final row in rows) {
    output.writeln(csvSafeRow([
      row.item,
      row.batchNumber,
      row.purchasedQuantity,
      row.purchaseInvoice,
      row.supplier,
      row.expiryDate,
      row.daysLeft ?? '',
      row.status,
    ]));
  }
  return output.toString();
}
