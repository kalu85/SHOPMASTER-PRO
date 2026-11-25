import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/report_repository.dart';

void main() {
  test('GSTR-3B working paper is available in the reports list', () {
    final report = kReports.firstWhere(
      (item) => item.type == ReportType.gstr3bPreparation,
    );

    expect(report.usesDates, isTrue);
    expect(report.title, contains('GSTR-3B'));
    expect(report.title, contains('working paper'));
  });
}
