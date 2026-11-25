/// Pure GST / NON-GST calculation. No Flutter or database code here so it
/// can be unit tested.
///
/// Rules:
/// - Item rate is the price BEFORE tax (tax is added on top).
/// - Discount is a rupee amount per line, taken off before tax.
/// - NON-GST invoices never calculate or collect tax.
/// - Intra-state supply: tax splits into CGST + SGST (half each).
/// - Inter-state supply: the whole tax is IGST.
double round2(double v) => (v * 100).round() / 100;

class LineInput {
  const LineInput({
    required this.qty,
    required this.rate,
    this.discount = 0,
    this.gstRate = 0,
  });

  final double qty;
  final double rate;
  final double discount;
  final int gstRate;
}

class LineResult {
  const LineResult({
    required this.gross,
    required this.discount,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.amount,
  });

  final double gross;
  final double discount;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;

  /// Line total including tax.
  final double amount;

  double get gst => cgst + sgst + igst;
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.lines,
    required this.subtotal,
    required this.discountTotal,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.grandTotal,
  });

  final List<LineResult> lines;

  /// Sum of qty x rate before discount.
  final double subtotal;
  final double discountTotal;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;

  double get totalGst => round2(cgst + sgst + igst);
}

class GstCalculator {
  GstCalculator._();

  static LineResult line(
    LineInput input, {
    required bool isGst,
    required bool isInterstate,
  }) {
    final gross = round2(input.qty * input.rate);
    var disc = input.discount;
    if (disc < 0) disc = 0;
    if (disc > gross) disc = gross;
    disc = round2(disc);
    final taxable = round2(gross - disc);

    var cgst = 0.0;
    var sgst = 0.0;
    var igst = 0.0;
    if (isGst) {
      final gst = round2(taxable * input.gstRate / 100);
      if (isInterstate) {
        igst = gst;
      } else {
        cgst = round2(gst / 2);
        sgst = round2(gst - cgst);
      }
    }
    return LineResult(
      gross: gross,
      discount: disc,
      taxable: taxable,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      amount: round2(taxable + cgst + sgst + igst),
    );
  }

  static InvoiceTotals totals(
    List<LineInput> inputs, {
    required bool isGst,
    required bool isInterstate,
  }) {
    final lines = [
      for (final i in inputs)
        line(i, isGst: isGst, isInterstate: isInterstate),
    ];
    double sum(double Function(LineResult) f) =>
        round2(lines.fold<double>(0, (a, l) => a + f(l)));
    return InvoiceTotals(
      lines: lines,
      subtotal: sum((l) => l.gross),
      discountTotal: sum((l) => l.discount),
      taxable: sum((l) => l.taxable),
      cgst: sum((l) => l.cgst),
      sgst: sum((l) => l.sgst),
      igst: sum((l) => l.igst),
      grandTotal: sum((l) => l.amount),
    );
  }
}
