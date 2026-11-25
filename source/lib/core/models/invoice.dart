import '../utils/gst_calculator.dart';

enum InvoiceKind { sale, purchase }

enum DocType { invoice, quotation, returnNote }

const List<String> kPayModes = ['Cash', 'UPI', 'Bank', 'Card', 'Credit'];

String docTypeToDb(DocType t) => switch (t) {
      DocType.invoice => 'invoice',
      DocType.quotation => 'quotation',
      DocType.returnNote => 'return',
    };

DocType docTypeFromDb(String s) => switch (s) {
      'quotation' => DocType.quotation,
      'return' => DocType.returnNote,
      _ => DocType.invoice,
    };

/// Number prefix per document type.
String numberPrefix(InvoiceKind k, DocType t) {
  if (k == InvoiceKind.sale) {
    return switch (t) {
      DocType.invoice => 'INV',
      DocType.quotation => 'QT',
      DocType.returnNote => 'SR',
    };
  }
  return switch (t) {
    DocType.invoice => 'PUR',
    DocType.quotation => 'PQ',
    DocType.returnNote => 'PR',
  };
}

String docTitle(InvoiceKind k, DocType t) {
  if (k == InvoiceKind.sale) {
    return switch (t) {
      DocType.invoice => 'Sales Invoice',
      DocType.quotation => 'Quotation',
      DocType.returnNote => 'Sales Return',
    };
  }
  return switch (t) {
    DocType.invoice => 'Purchase Invoice',
    DocType.quotation => 'Purchase Quotation',
    DocType.returnNote => 'Purchase Return',
  };
}

/// Heading printed on the PDF: TAX INVOICE (GST) / SALES INVOICE (NON-GST).
String pdfHeading(Invoice inv) {
  if (inv.kind == InvoiceKind.sale && inv.docType == DocType.invoice) {
    return inv.isGst ? 'TAX INVOICE' : 'SALES INVOICE';
  }
  return docTitle(inv.kind, inv.docType).toUpperCase();
}

class Invoice {
  const Invoice({
    this.id,
    required this.kind,
    required this.docType,
    this.number = '',
    this.partyId,
    this.partyName = '',
    this.partyPhone = '',
    this.partyAddress = '',
    this.partyGstin = '',
    required this.isGst,
    this.isInterstate = false,
    required this.invoiceDate,
    required this.subtotal,
    required this.discountTotal,
    required this.taxableTotal,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.grandTotal,
    this.paid = 0,
    this.payMode = 'Cash',
    this.accountId,
    this.notes = '',
  });

  final int? id;
  final InvoiceKind kind;
  final DocType docType;
  final String number;
  final int? partyId;
  final String partyName;
  final String partyPhone;
  final String partyAddress;
  final String partyGstin;
  final bool isGst;
  final bool isInterstate;

  /// yyyy-MM-dd
  final String invoiceDate;
  final double subtotal;
  final double discountTotal;
  final double taxableTotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;
  final double paid;
  final String payMode;

  /// Cash/bank account that received or paid the money.
  final int? accountId;
  final String notes;

  double get totalGst => round2(cgst + sgst + igst);
  double get due => round2(grandTotal - paid);

  factory Invoice.fromMap(Map<String, Object?> m) => Invoice(
        id: m['id'] as int?,
        kind: InvoiceKind.values.byName(m['kind'] as String),
        docType: docTypeFromDb(m['doc_type'] as String),
        number: m['number'] as String,
        partyId: m['party_id'] as int?,
        partyName: m['party_name'] as String,
        partyPhone: m['party_phone'] as String,
        partyAddress: m['party_address'] as String,
        partyGstin: m['party_gstin'] as String,
        isGst: (m['is_gst'] as num).toInt() == 1,
        isInterstate: (m['is_interstate'] as num).toInt() == 1,
        invoiceDate: m['invoice_date'] as String,
        subtotal: (m['subtotal'] as num).toDouble(),
        discountTotal: (m['discount_total'] as num).toDouble(),
        taxableTotal: (m['taxable_total'] as num).toDouble(),
        cgst: (m['cgst'] as num).toDouble(),
        sgst: (m['sgst'] as num).toDouble(),
        igst: (m['igst'] as num).toDouble(),
        grandTotal: (m['grand_total'] as num).toDouble(),
        paid: (m['paid'] as num).toDouble(),
        payMode: m['pay_mode'] as String,
        accountId: m['account_id'] as int?,
        notes: m['notes'] as String,
      );

  Map<String, Object?> toMap() => {
        'kind': kind.name,
        'doc_type': docTypeToDb(docType),
        'number': number,
        'party_id': partyId,
        'party_name': partyName,
        'party_phone': partyPhone,
        'party_address': partyAddress,
        'party_gstin': partyGstin,
        'is_gst': isGst ? 1 : 0,
        'is_interstate': isInterstate ? 1 : 0,
        'invoice_date': invoiceDate,
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'taxable_total': taxableTotal,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'grand_total': grandTotal,
        'paid': paid,
        'due': due,
        'pay_mode': payMode,
        'account_id': accountId,
        'notes': notes,
      };
}

class InvoiceItem {
  const InvoiceItem({
    this.productId,
    required this.name,
    this.hsn = '',
    required this.qty,
    required this.rate,
    this.discount = 0,
    this.gstRate = 0,
    required this.taxable,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    required this.amount,
    this.serials = '',
    this.warrantyMonths = 0,
    this.purchaseRateSnapshot = 0,
  });

  final int? productId;
  final String name;
  final String hsn;
  final double qty;
  final double rate;
  final double discount;
  final int gstRate;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double amount;

  /// Serial numbers, comma separated.
  final String serials;

  /// Warranty duration in months. The start and expiry dates are stored on
  /// the serial record only and are never printed on the invoice.
  final int warrantyMonths;

  /// Product cost captured when this invoice line was saved.
  final double purchaseRateSnapshot;

  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
        productId: m['product_id'] as int?,
        name: m['name'] as String,
        hsn: m['hsn'] as String,
        qty: (m['qty'] as num).toDouble(),
        rate: (m['rate'] as num).toDouble(),
        discount: (m['discount'] as num).toDouble(),
        gstRate: (m['gst_rate'] as num).toInt(),
        taxable: (m['taxable'] as num).toDouble(),
        cgst: (m['cgst'] as num).toDouble(),
        sgst: (m['sgst'] as num).toDouble(),
        igst: (m['igst'] as num).toDouble(),
        amount: (m['amount'] as num).toDouble(),
        serials: (m['serials'] as String?) ?? '',
        warrantyMonths: ((m['warranty_months'] as num?) ?? 0).toInt(),
        purchaseRateSnapshot: ((m['purchase_rate_snapshot'] as num?) ?? 0).toDouble(),
      );

  Map<String, Object?> toMap(int invoiceId) => {
        'invoice_id': invoiceId,
        'product_id': productId,
        'name': name,
        'hsn': hsn,
        'qty': qty,
        'rate': rate,
        'discount': discount,
        'gst_rate': gstRate,
        'taxable': taxable,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'amount': amount,
        'serials': serials,
        'warranty_months': warrantyMonths,
        'purchase_rate_snapshot': purchaseRateSnapshot,
      };
}
