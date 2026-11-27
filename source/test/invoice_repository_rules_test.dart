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

  group('InvoiceRepository document validation', () {
    const validInvoice = Invoice(
      kind: InvoiceKind.sale,
      docType: DocType.invoice,
      isGst: true,
      invoiceDate: '2026-11-26',
      subtotal: 100,
      discountTotal: 0,
      taxableTotal: 100,
      cgst: 9,
      sgst: 9,
      igst: 0,
      grandTotal: 118,
      paid: 50,
    );

    const validItem = InvoiceItem(
      name: 'Phone',
      qty: 1,
      rate: 100,
      taxable: 100,
      amount: 118,
    );

    test('accepts valid invoice data', () {
      expect(
        () => InvoiceRepository.validateDocument(validInvoice, [validItem]),
        returnsNormally,
      );
    });

    test('rejects payments greater than the invoice total', () {
      final overpaid = Invoice(
        kind: InvoiceKind.sale,
        docType: DocType.invoice,
        isGst: true,
        invoiceDate: '2026-11-26',
        subtotal: 100,
        discountTotal: 0,
        taxableTotal: 100,
        cgst: 9,
        sgst: 9,
        igst: 0,
        grandTotal: 118,
        paid: 118.01,
      );
      expect(
        () => InvoiceRepository.validateDocument(overpaid, [validItem]),
        throwsArgumentError,
      );
    });

    test('rejects zero and negative quantities', () {
      for (final quantity in [0.0, -1.0]) {
        expect(
          () => InvoiceRepository.validateDocument(
            validInvoice,
            [InvoiceItem(
              name: 'Phone',
              qty: quantity,
              rate: 100,
              taxable: 100,
              amount: 100,
            )],
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects non-finite and negative money values', () {
      for (final amount in [double.nan, double.infinity, -1.0]) {
        expect(
          () => InvoiceRepository.validateDocument(
            validInvoice,
            [InvoiceItem(
              name: 'Phone',
              qty: 1,
              rate: amount,
              taxable: 100,
              amount: 100,
            )],
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects invalid invoice calendar dates', () {
      for (final date in ['2026-02-30', '2026/11/26', 'not-a-date']) {
        final invalid = Invoice(
          kind: InvoiceKind.sale,
          docType: DocType.invoice,
          isGst: true,
          invoiceDate: date,
          subtotal: 100,
          discountTotal: 0,
          taxableTotal: 100,
          cgst: 9,
          sgst: 9,
          igst: 0,
          grandTotal: 118,
        );
        expect(
          () => InvoiceRepository.validateDocument(invalid, [validItem]),
          throwsArgumentError,
        );
      }
    });

    test('rejects malformed batch expiry dates but accepts a real date', () {
      const validExpiryItem = InvoiceItem(
        name: 'Phone',
        qty: 1,
        rate: 100,
        taxable: 100,
        amount: 100,
        expiryDate: '2027-02-28',
      );
      expect(
        () => InvoiceRepository.validateDocument(validInvoice, [validExpiryItem]),
        returnsNormally,
      );
      for (final date in ['2027-02-29', '2027-13-01', '28-02-2027']) {
        final invalidItem = InvoiceItem(
          name: 'Phone',
          qty: 1,
          rate: 100,
          taxable: 100,
          amount: 100,
          expiryDate: date,
        );
        expect(
          () => InvoiceRepository.validateDocument(validInvoice, [invalidItem]),
          throwsArgumentError,
        );
      }
    });

    test('rejects invalid GST rates and blank item names', () {
      expect(
        () => InvoiceRepository.validateDocument(validInvoice, [
          const InvoiceItem(
            name: 'Phone',
            qty: 1,
            rate: 100,
            gstRate: 101,
            taxable: 100,
            amount: 100,
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => InvoiceRepository.validateDocument(validInvoice, [
          const InvoiceItem(
            name: '  ',
            qty: 1,
            rate: 100,
            taxable: 100,
            amount: 100,
          ),
        ]),
        throwsArgumentError,
      );
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
