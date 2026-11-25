/// Splits typed serial numbers (one per line, or separated by commas).
List<String> parseSerials(String raw) => raw
    .split(RegExp(r'[\n,;]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Adds calendar months, clamping the day (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  var y = d.year;
  var m = d.month + months;
  y += (m - 1) ~/ 12;
  m = (m - 1) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

enum WarrantyState { none, active, expiring, expired }

/// [expiryIso] is yyyy-MM-dd. "Expiring" means within [soonDays] days.
WarrantyState warrantyState(String? expiryIso, DateTime now,
    {int soonDays = 30}) {
  if (expiryIso == null || expiryIso.isEmpty) return WarrantyState.none;
  final exp = DateTime.tryParse(expiryIso);
  if (exp == null) return WarrantyState.none;
  final today = DateTime(now.year, now.month, now.day);
  if (exp.isBefore(today)) return WarrantyState.expired;
  if (exp.difference(today).inDays <= soonDays) return WarrantyState.expiring;
  return WarrantyState.active;
}

String warrantyLabel(int months) {
  if (months <= 0) return '-';
  if (months % 12 == 0) {
    final y = months ~/ 12;
    return y == 1 ? '1 year' : '$y years';
  }
  return '$months months';
}

/// Canonical comparison key for serial identifiers (case-insensitive).
String serialKey(String serial) => serial.trim().toLowerCase();
