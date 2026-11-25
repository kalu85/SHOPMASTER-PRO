import 'package:flutter_test/flutter_test.dart';
import 'package:shopmaster_pro/core/data/invoice_repository.dart';
import 'package:shopmaster_pro/core/models/invoice.dart';

void main() {
  group('InvoiceRepository stock direction', () {
    test('sale invoice removes stock', () {
      expect(
        InvoiceRepository.stockDirection(InvoiceKind.sale, DocType.invoice),
        -1,
      );
    });

    test('sale return restores stock', () {
      expect(
        InvoiceRepository.stockDirection(InvoiceKind.sale, DocType.returnNote),
        1,
      );
    });

    test('purchase invoice adds stock', () {
      expect(
        InvoiceRepository.stockDirection(InvoiceKind.purchase, DocType.invoice),
        1,
      );
    });

    test('purchase return removes stock', () {
      expect(
        InvoiceRepository.stockDirection(
          InvoiceKind.purchase,
          DocType.returnNote,
        ),
        -1,
      );
    });

    test('quotations never change stock', () {
      for (final kind in InvoiceKind.values) {
        expect(
          InvoiceRepository.stockDirection(kind, DocType.quotation),
          0,
        );
      }
    });
  });

  group('InvoiceRepository account and balance directions', () {
    test('sale invoice and purchase return bring money in', () {
      expect(
        InvoiceRepository.moneyComesIn(InvoiceKind.sale, DocType.invoice),
        isTrue,
      );
      expect(
        InvoiceRepository.moneyComesIn(
          InvoiceKind.purchase,
          DocType.returnNote,
        ),
        isTrue,
      );
    });

    test('purchase invoice and sale return pay money out', () {
      expect(
        InvoiceRepository.moneyComesIn(InvoiceKind.purchase, DocType.invoice),
        isFalse,
      );
      expect(
        InvoiceRepository.moneyComesIn(InvoiceKind.sale, DocType.returnNote),
        isFalse,
      );
    });

    test('returns reduce party balance; invoices increase it', () {
      expect(InvoiceRepository.balanceDirection(DocType.invoice), 1);
      expect(InvoiceRepository.balanceDirection(DocType.returnNote), -1);
      expect(InvoiceRepository.balanceDirection(DocType.quotation), 1);
    });
  });

  test('invoice due is rounded to two decimal places', () {
    const invoice = Invoice(
      kind: InvoiceKind.sale,
      docType: DocType.invoice,
      isGst: false,
      invoiceDate: '2026-11-25',
      subtotal: 100,
      discountTotal: 0,
      taxableTotal: 100,
      cgst: 0,
      sgst: 0,
      igst: 0,
      grandTotal: 100.10,
      paid: 33.333,
    );

    expect(invoice.due, 66.77);
  });

  test('document prefixes remain distinct', () {
    expect(numberPrefix(InvoiceKind.sale, DocType.invoice), 'INV');
    expect(numberPrefix(InvoiceKind.sale, DocType.returnNote), 'SR');
    expect(numberPrefix(InvoiceKind.purchase, DocType.invoice), 'PUR');
    expect(numberPrefix(InvoiceKind.purchase, DocType.returnNote), 'PR');
  });
}
