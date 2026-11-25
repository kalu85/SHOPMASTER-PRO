class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.qtyChange,
    required this.reason,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final double qtyChange;
  final String reason;
  final String note;
  final DateTime createdAt;

  factory StockMovement.fromMap(Map<String, Object?> m) => StockMovement(
        id: (m['id'] as num).toInt(),
        productId: (m['product_id'] as num).toInt(),
        qtyChange: (m['qty_change'] as num).toDouble(),
        reason: m['reason'] as String,
        note: m['note'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
