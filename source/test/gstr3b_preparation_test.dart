import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/report_repository.dart';

void main() {
  test('combined CA GST report pack is available in the reports list', () {
    final report = kReports.firstWhere((item) => item.type == ReportType.caGstPack);
    expect(report.usesDates, isTrue);
    expect(report.title, contains('CA'));
    expect(report.title, contains('GST'));
  });

  test('GSTR-3B working paper is available in the reports list', () {
    final report = kReports.firstWhere(
      (item) => item.type == ReportType.gstr3bPreparation,
    );

    expect(report.usesDates, isTrue);
    expect(report.title, contains('GSTR-3B'));
    expect(report.title, contains('working paper'));
  });

  test('GSTIN format check accepts standard shape and rejects malformed values', () {
    expect(isGstinFormatValid('27AAPFU0939F1ZV'), isTrue);
    expect(isGstinFormatValid('27AAPFU0939F1Z'), isFalse);
    expect(isGstinFormatValid('not-a-gstin'), isFalse);
    expect(isGstinFormatValid('27aapfu0939f1zv'), isTrue);
  });
  test('GSTIN format review distinguishes blank and malformed values', () {
    expect(gstinFormatReview('27AAPFU0939F1ZV'), isNull);
    expect(gstinFormatReview('27aapfu0939f1zv'), isNull);
    expect(gstinFormatReview('  '), 'GSTIN is blank');
    expect(gstinFormatReview('27AAPFU0939F1Z'), 'GSTIN format is unexpected');
  });

}
