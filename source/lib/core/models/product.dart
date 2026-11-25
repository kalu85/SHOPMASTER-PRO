import '../utils/format.dart';

class Product {
  const Product({
    this.id,
    required this.name,
    this.category = '',
    this.hsn = '',
    this.barcode,
    this.purchaseRate = 0,
    this.saleRate = 0,
    this.gstRate = 0,
    this.openingStock = 0,
    this.currentStock = 0,
    this.minStock = 0,
    this.isService = false,
    this.supplierId,
    this.supplierName = '',
  });

  final int? id;
  final String name;
  final String category;
  final String hsn;
  final String? barcode;
  final double purchaseRate;
  final double saleRate;
  final int gstRate;
  final double openingStock;
  final double currentStock;
  final double minStock;

  /// Service / non-stock item: never changes inventory.
  final bool isService;

  /// Usual supplier of this item (optional).
  final int? supplierId;
  final String supplierName;

  /// Owner-only buy price hint, e.g. for the sales screens.
  /// [purchaseRate] is stored without GST.
  String get buyPriceLabel {
    if (purchaseRate <= 0) return 'Buy price not set';
    final base = 'Buy ${inr.format(purchaseRate)}';
    if (gstRate == 0) return base;
    final withGst = purchaseRate * (100 + gstRate) / 100;
    return '$base (${inr.format(withGst)} with GST)';
  }

  bool get isNegative => !isService && currentStock < 0;
  bool get isLow =>
      !isService && !isNegative && minStock > 0 && currentStock <= minStock;

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String,
        hsn: m['hsn'] as String,
        barcode: m['barcode'] as String?,
        purchaseRate: (m['purchase_rate'] as num).toDouble(),
        saleRate: (m['sale_rate'] as num).toDouble(),
        gstRate: (m['gst_rate'] as num).toInt(),
        openingStock: (m['opening_stock'] as num).toDouble(),
        currentStock: (m['current_stock'] as num).toDouble(),
        minStock: (m['min_stock'] as num).toDouble(),
        isService: (m['is_service'] as num).toInt() == 1,
        supplierId: m['supplier_id'] as int?,
        supplierName: (m['supplier_name'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'category': category,
        'hsn': hsn,
        'barcode': (barcode == null || barcode!.isEmpty) ? null : barcode,
        'purchase_rate': purchaseRate,
        'sale_rate': saleRate,
        'gst_rate': gstRate,
        'opening_stock': openingStock,
        'current_stock': currentStock,
        'min_stock': minStock,
        'is_service': isService ? 1 : 0,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
      };
}
