import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/invoice_repository.dart';
import 'package:shopmaster_pro/core/models/invoice.dart';
import 'package:shopmaster_pro/core/utils/gst_calculator.dart';

void main() {
  group('GST (intra-state: CGST + SGST)', () {
    test('1000 x 2 at 18% with 100 discount', () {
      final t = GstCalculator.totals(
        const [LineInput(qty: 2, rate: 1000, discount: 100, gstRate: 18)],
        isGst: true,
        isInterstate: false,
      );
      expect(t.subtotal, 2000);
      expect(t.discountTotal, 100);
      expect(t.taxable, 1900);
      expect(t.cgst, 171);
      expect(t.sgst, 171);
      expect(t.igst, 0);
      expect(t.totalGst, 342);
      expect(t.grandTotal, 2242);
    });

    test('CGST + SGST always equals the line GST (odd paise)', () {
      final r = GstCalculator.line(
        const LineInput(qty: 1, rate: 10.01, gstRate: 5),
        isGst: true,
        isInterstate: false,
      );
      expect(round2(r.cgst + r.sgst), round2(r.taxable * 5 / 100));
    });
  });

  group('GST (inter-state: IGST)', () {
    test('whole tax goes to IGST', () {
      final t = GstCalculator.totals(
        const [LineInput(qty: 1, rate: 1000, gstRate: 12)],
        isGst: true,
        isInterstate: true,
      );
      expect(t.igst, 120);
      expect(t.cgst, 0);
      expect(t.sgst, 0);
      expect(t.grandTotal, 1120);
    });
  });

  group('NON-GST', () {
    test('never calculates tax, even if a GST rate is set', () {
      final t = GstCalculator.totals(
        const [LineInput(qty: 3, rate: 500, gstRate: 28)],
        isGst: false,
        isInterstate: false,
      );
      expect(t.cgst, 0);
      expect(t.sgst, 0);
      expect(t.igst, 0);
      expect(t.totalGst, 0);
      expect(t.grandTotal, 1500);
    });
  });

  test('discount cannot exceed the line value', () {
    final r = GstCalculator.line(
      const LineInput(qty: 1, rate: 100, discount: 500, gstRate: 18),
      isGst: true,
      isInterstate: false,
    );
    expect(r.taxable, 0);
    expect(r.amount, 0);
  });

  group('Stock and balance directions', () {
    test('stock', () {
      expect(InvoiceRepository.stockDirection(InvoiceKind.sale, DocType.invoice), -1);
      expect(InvoiceRepository.stockDirection(InvoiceKind.sale, DocType.returnNote), 1);
      expect(InvoiceRepository.stockDirection(InvoiceKind.purchase, DocType.invoice), 1);
      expect(InvoiceRepository.stockDirection(InvoiceKind.purchase, DocType.returnNote), -1);
      expect(InvoiceRepository.stockDirection(InvoiceKind.sale, DocType.quotation), 0);
    });

    test('party balance', () {
      expect(InvoiceRepository.balanceDirection(DocType.invoice), 1);
      expect(InvoiceRepository.balanceDirection(DocType.returnNote), -1);
    });
  });
}
