/// CSV helpers that prevent spreadsheet formula execution from user text.
///
/// Spreadsheet programs may evaluate cells beginning with =, +, -, or @ as
/// formulas. Prefixes such as tabs and line breaks are also treated as
/// dangerous. Numeric values remain numeric, including negative amounts.
String csvSafeCell(Object? value) {
  final raw = value?.toString() ?? '';
  final numeric = RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(raw);
  final formulaLike = RegExp(r'^[\s\u0000-\u001F]*[=+@-]').hasMatch(raw);
  final safe = formulaLike && !numeric ? "'$raw" : raw;
  return '"${safe.replaceAll('"', '""')}"';
}

/// Builds a spreadsheet-compatible CSV row with every cell quoted.
String csvSafeRow(Iterable<Object?> values) =>
    values.map(csvSafeCell).join(',');
