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

  group('GST line tax calculation review', () {
    test('accepts tax matching taxable value and GST rate', () {
      expect(gstLineTaxAmountMismatch(
        taxable: 1000, gstRate: 18, cgst: 90, sgst: 90, igst: 0,
      ), isFalse);
    });

    test('accepts differences within two paise', () {
      expect(gstLineTaxAmountMismatch(
        taxable: 1000, gstRate: 18, cgst: 90.01, sgst: 89.99, igst: 0,
      ), isFalse);
    });

    test('flags tax totals that do not match the GST rate', () {
      expect(gstLineTaxAmountMismatch(
        taxable: 1000, gstRate: 18, cgst: 90, sgst: 89.97, igst: 0,
      ), isTrue);
    });

    test('flags invalid or non-finite line inputs', () {
      expect(gstLineTaxAmountMismatch(
        taxable: -1, gstRate: 18, cgst: 0, sgst: 0, igst: 0,
      ), isTrue);
      expect(gstLineTaxAmountMismatch(
        taxable: 1000, gstRate: 101, cgst: 0, sgst: 0, igst: 0,
      ), isTrue);
      expect(gstLineTaxAmountMismatch(
        taxable: double.infinity, gstRate: 18, cgst: 90, sgst: 90, igst: 0,
      ), isTrue);
    });
  });

  group('outstanding ageing date buckets', () {
    final today = DateTime(2026, 11, 26, 17, 30);

    test('uses calendar dates for 0, 30, 31, 60, 61, 90 and 91 days', () {
      expect(outstandingAgeBucket('2026-11-26', today), '0-30 days');
      expect(outstandingAgeBucket('2026-10-27', today), '0-30 days');
      expect(outstandingAgeBucket('2026-10-26', today), '31-60 days');
      expect(outstandingAgeBucket('2026-09-27', today), '31-60 days');
      expect(outstandingAgeBucket('2026-09-26', today), '61-90 days');
      expect(outstandingAgeBucket('2026-08-28', today), '61-90 days');
      expect(outstandingAgeBucket('2026-08-27', today), 'Over 90 days');
    });

    test('keeps future and invalid dates out of ageing buckets', () {
      expect(outstandingAgeBucket('2026-11-27', today), 'Future dated');
      expect(outstandingAgeBucket('2026-02-30', today), 'Invalid date');
      expect(outstandingAgeBucket('', today), 'Invalid date');
      expect(outstandingAgeBucket(null, today), 'Invalid date');
    });
  });

}
