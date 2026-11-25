enum PartyType { customer, supplier }

class Party {
  const Party({
    this.id,
    required this.type,
    required this.name,
    this.phone = '',
    this.address = '',
    this.email = '',
    this.gstin = '',
    this.openingBalance = 0,
    this.currentBalance = 0,
  });

  final int? id;
  final PartyType type;
  final String name;
  final String phone;
  final String address;
  final String email;
  final String gstin;

  /// Customer: amount the customer owes you. Supplier: amount you owe them.
  final double openingBalance;
  final double currentBalance;

  factory Party.fromMap(Map<String, Object?> m) => Party(
        id: m['id'] as int?,
        type: PartyType.values.byName(m['type'] as String),
        name: m['name'] as String,
        phone: m['phone'] as String,
        address: m['address'] as String,
        email: m['email'] as String,
        gstin: m['gstin'] as String,
        openingBalance: (m['opening_balance'] as num).toDouble(),
        currentBalance: (m['current_balance'] as num).toDouble(),
      );
}
