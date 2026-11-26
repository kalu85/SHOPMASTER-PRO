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

  group('GST invoice header and line reconciliation', () {
    test('accepts matching totals within the two-paise tolerance', () {
      expect(gstDocumentTotalsMismatch(
        headerTaxable: 1000, headerCgst: 90, headerSgst: 90,
        headerIgst: 0, headerTotal: 1180,
        linesTaxable: 1000, linesCgst: 90.01, linesSgst: 89.99,
        linesIgst: 0, linesTotal: 1180,
      ), isFalse);
    });

    test('flags a difference larger than the tolerance', () {
      expect(gstDocumentTotalsMismatch(
        headerTaxable: 1000, headerCgst: 90, headerSgst: 90,
        headerIgst: 0, headerTotal: 1180,
        linesTaxable: 999.97, linesCgst: 90, linesSgst: 90,
        linesIgst: 0, linesTotal: 1179.97,
      ), isTrue);
    });

    test('flags non-finite values rather than hiding them', () {
      expect(gstDocumentTotalsMismatch(
        headerTaxable: double.infinity, headerCgst: 0, headerSgst: 0,
        headerIgst: 0, headerTotal: 0, linesTaxable: 0, linesCgst: 0,
        linesSgst: 0, linesIgst: 0, linesTotal: 0,
      ), isTrue);
    });
  });

}
