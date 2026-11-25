import 'package:intl/intl.dart';

/// Indian rupee formatter used across the app.
final NumberFormat inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// Quantity without trailing ".0" (5 -> "5", 2.5 -> "2.50").
String fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

final DateFormat dateTimeFmt = DateFormat('dd MMM yyyy, h:mm a');
final DateFormat dateFmt = DateFormat('dd MMM yyyy');
final DateFormat isoDateFmt = DateFormat('yyyy-MM-dd');

/// "2026-11-24" -> "24 Nov 2026" (falls back to the raw text).
String prettyDate(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : dateFmt.format(d);
}
