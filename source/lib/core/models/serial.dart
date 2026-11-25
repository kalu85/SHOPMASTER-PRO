import '../utils/serials.dart';

class SerialRecord {
  const SerialRecord({
    required this.id,
    required this.serial,
    this.productId,
    this.productName = '',
    this.purchaseInvoiceId,
    this.purchaseNumber = '',
    this.saleInvoiceId,
    this.saleNumber = '',
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.soldDate,
    this.warrantyMonths = 0,
    this.warrantyStart,
    this.warrantyExpiry,
    required this.status,
  });

  final int id;
  final String serial;
  final int? productId;
  final String productName;
  final int? purchaseInvoiceId;
  final String purchaseNumber;
  final int? saleInvoiceId;
  final String saleNumber;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final String? soldDate;
  final int warrantyMonths;
  final String? warrantyStart;
  final String? warrantyExpiry;

  /// 'in_stock', 'sold' or 'returned'
  final String status;

  WarrantyState get warranty => warrantyState(warrantyExpiry, DateTime.now());

  String get statusLabel => switch (status) {
        'sold' => 'Sold',
        'returned' => 'Returned to supplier',
        _ => 'In stock',
      };

  factory SerialRecord.fromMap(Map<String, Object?> m) => SerialRecord(
        id: (m['id'] as num).toInt(),
        serial: m['serial'] as String,
        productId: m['product_id'] as int?,
        productName: m['product_name'] as String,
        purchaseInvoiceId: m['purchase_invoice_id'] as int?,
        purchaseNumber: m['purchase_number'] as String,
        saleInvoiceId: m['sale_invoice_id'] as int?,
        saleNumber: m['sale_number'] as String,
        customerId: m['customer_id'] as int?,
        customerName: m['customer_name'] as String,
        customerPhone: m['customer_phone'] as String,
        soldDate: m['sold_date'] as String?,
        warrantyMonths: (m['warranty_months'] as num).toInt(),
        warrantyStart: m['warranty_start'] as String?,
        warrantyExpiry: m['warranty_expiry'] as String?,
        status: m['status'] as String,
      );
}

class WarrantyClaim {
  const WarrantyClaim({
    required this.id,
    required this.serialId,
    required this.date,
    required this.issue,
    required this.status,
    required this.resolution,
  });

  final int id;
  final int serialId;
  final String date;
  final String issue;

  /// 'open', 'resolved' or 'rejected'
  final String status;
  final String resolution;

  factory WarrantyClaim.fromMap(Map<String, Object?> m) => WarrantyClaim(
        id: (m['id'] as num).toInt(),
        serialId: (m['serial_id'] as num).toInt(),
        date: m['claim_date'] as String,
        issue: m['issue'] as String,
        status: m['status'] as String,
        resolution: m['resolution'] as String,
      );
}

/// Thrown when a serial number breaks a rule (duplicate, already sold...).
class SerialException implements Exception {
  SerialException(this.message);
  final String message;

  @override
  String toString() => message;
}
