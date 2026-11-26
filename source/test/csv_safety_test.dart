import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/utils/csv_safety.dart';
import 'package:shopmaster_pro/core/data/report_repository.dart';

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

    test('protects report titles, rows and summaries', () {
      final report = ReportData(
        title: '=IMPORTXML("unsafe")',
        columns: const ['Party', 'Amount'],
        rows: const [['@SUM(A1:A2)', '-50.00']],
        summary: const ['+HYPERLINK("unsafe")'],
      );
      final csv = report.toCsv();

      expect(csv, contains('"\'=IMPORTXML(""unsafe"")"'));
      expect(csv, contains('"\'@SUM(A1:A2)"'));
      expect(csv, contains('"-50.00"'));
      expect(csv, contains('"\'+HYPERLINK(""unsafe"")"'));
    });

    test('quotes every cell in a row', () {
      expect(csvSafeRow(['Item', 'Cable, Type A', -25]), '"Item","Cable, Type A","-25"');
    });
  });
}
