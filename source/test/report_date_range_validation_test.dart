import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/report_repository.dart';

void main() {
  group('report date range validation', () {
    test('accepts a single day and an ascending range', () {
      expect(() => validateReportDateRange('2026-11-26', '2026-11-26'), returnsNormally);
      expect(() => validateReportDateRange('2026-01-01', '2026-11-26'), returnsNormally);
    });

    test('rejects malformed and non-calendar dates', () {
      for (final value in ['2026-1-01', '26-11-2026', '2026-02-29', '2026-13-01', '']) {
        expect(
          () => validateReportDateRange(value, '2026-11-26'),
          throwsArgumentError,
          reason: 'Expected invalid start date: $value',
        );
      }
      expect(
        () => validateReportDateRange('2026-11-01', '2026-02-30'),
        throwsArgumentError,
      );
    });

    test('rejects a reversed range', () {
      expect(
        () => validateReportDateRange('2026-11-27', '2026-11-26'),
        throwsArgumentError,
      );
    });
  });
}
