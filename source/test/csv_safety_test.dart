import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/utils/csv_safety.dart';

void main() {
  group('CSV spreadsheet safety', () {
    test('quotes and escapes ordinary values', () {
      expect(csvSafeCell('ABC, "Wholesale"'), '"ABC, ""Wholesale"""');
    });

    test('neutralizes formula prefixes and leading whitespace', () {
      expect(csvSafeCell('=1+1'), '"\'=1+1"');
      expect(csvSafeCell('  @SUM(A1:A2)'), '"\'  @SUM(A1:A2)"');
      expect(csvSafeCell('\t=cmd'), '"\'\t=cmd"');
      expect(csvSafeCell('-1+1'), '"\'-1+1"');
    });

    test('preserves numeric negative values as numbers', () {
      expect(csvSafeCell('-125.50'), '"-125.50"');
      expect(csvSafeCell('+12'), '"+12"');
      expect(csvSafeCell('0'), '"0"');
    });

    test('quotes every cell in a row', () {
      expect(csvSafeRow(['Item', 'Cable, Type A', -25]), '"Item","Cable, Type A","-25"');
    });
  });
}
