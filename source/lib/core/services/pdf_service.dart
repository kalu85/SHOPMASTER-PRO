import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/report_repository.dart';
import '../data/settings_repository.dart';
import '../models/invoice.dart';
import '../utils/format.dart';
import '../utils/serials.dart';

/// Builds invoice and report PDFs (A4 and 80mm thermal).
class PdfService {
  PdfService._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static final PdfColor _navy = PdfColor.fromHex('#0B1A33');
  static final PdfColor _blue = PdfColor.fromHex('#2979FF');
  static final PdfColor _light = PdfColor.fromHex('#EAF4FF');
  static final PdfColor _grey = PdfColor.fromHex('#64748B');
  static final PdfColor _line = PdfColor.fromHex('#B8CCE4');

  static const List<String> _invoiceTerms = [
    'E.& O.E.',
    '1. Goods once sold will not be taken back.',
    '2. In case burnt, serial no tampered, broken item not covered in warranty. Show the bill copy at the time of warranty.',
    "3. All warranties are provided by manufacturer's as per their Standard warranty terms.",
  ];

  static pw.Widget _termsBox({double fontSize = 8.5}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Terms & Conditions',
              style: pw.TextStyle(
                  fontSize: fontSize + 0.5,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          for (final term in _invoiceTerms)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(term,
                  style: pw.TextStyle(fontSize: fontSize, lineSpacing: 1.5)),
            ),
        ],
      ),
    );
  }

  static Future<pw.ThemeData> _theme() async {
    _regular ??=
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    _bold ??=
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    return pw.ThemeData.withFont(base: _regular!, bold: _bold!);
  }

  static Future<Uint8List> _logoBytes(ShopSettings shop) async {
    if (shop.logoPath.isNotEmpty) {
      final f = File(shop.logoPath);
      if (await f.exists()) return f.readAsBytes();
    }
    final data = await rootBundle.load('assets/logo.png');
    return data.buffer.asUint8List();
  }

  static String _num(double v) => v.toStringAsFixed(2);

  /// UPI payment link used for the QR code.
  static String upiLink(ShopSettings shop, Invoice inv) {
    final b = StringBuffer('upi://pay?pa=${Uri.encodeComponent(shop.upiId)}');
    b.write('&pn=${Uri.encodeComponent(shop.shopName)}');
    if (inv.due > 0) b.write('&am=${inv.due.toStringAsFixed(2)}');
    b.write('&cu=INR&tn=${Uri.encodeComponent(inv.number)}');
    return b.toString();
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    double size = 8.5,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _kv(String k, String v,
      {bool bold = false, double size = 9.5, PdfColor? color}) {
    final style = pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(k, style: style), pw.Text(v, style: style)],
      ),
    );
  }

  static String _receivedLabel(Invoice inv) {
    if (inv.docType == DocType.returnNote) return 'Refunded';
    return inv.kind == InvoiceKind.sale ? 'Received amount' : 'Paid amount';
  }

  static String _partyLabel(Invoice inv) =>
      inv.kind == InvoiceKind.sale ? 'Bill to' : 'Supplier';

  static String _partyName(Invoice inv) => inv.partyName.isEmpty
      ? (inv.kind == InvoiceKind.sale ? 'Walk-in customer' : 'No supplier')
      : inv.partyName;

  /// Invoice PDF. [thermal] = true gives an 80mm receipt.
  static Future<Uint8List> invoice(
    Invoice inv,
    List<InvoiceItem> items,
    ShopSettings shop, {
    required bool thermal,
  }) async {
    final theme = await _theme();
    final logo = pw.MemoryImage(await _logoBytes(shop));
    final doc = pw.Document(title: inv.number, author: shop.shopName);
    if (thermal) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        build: (ctx) => _thermalBody(inv, items, shop, logo),
      ));
    } else {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        build: (ctx) => _a4Body(inv, items, shop, logo),
      ));
    }
    return doc.save();
  }

  // ---------------- A4 ----------------

  static List<pw.Widget> _a4Body(
    Invoice inv,
    List<InvoiceItem> items,
    ShopSettings shop,
    pw.MemoryImage logo,
  ) {
    final isGst = inv.isGst;
    final isSale = inv.kind == InvoiceKind.sale;
    final isQuote = inv.docType == DocType.quotation;

    // Header: logo upper-left, shop details upper-right.
    final header = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logo, width: 62, height: 62),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(shop.shopName,
                  style: pw.TextStyle(
                      fontSize: 19,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              if (shop.address.isNotEmpty)
                pw.Text(shop.address,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9.5)),
              if (shop.phone.isNotEmpty)
                pw.Text('Phone: ${shop.phone}',
                    style: const pw.TextStyle(fontSize: 9.5)),
              if (isGst && shop.gstin.isNotEmpty)
                pw.Text('GSTIN: ${shop.gstin}',
                    style: pw.TextStyle(
                        fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );

    final title = pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(pdfHeading(inv),
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13)),
          pw.Text('No: ${inv.number}     Date: ${prettyDate(inv.invoiceDate)}',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
        ],
      ),
    );

    final party = pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _light,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(_partyLabel(inv),
              style: pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text(_partyName(inv),
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (inv.partyPhone.isNotEmpty)
            pw.Text('Phone: ${inv.partyPhone}',
                style: const pw.TextStyle(fontSize: 9.5)),
          if (inv.partyAddress.isNotEmpty)
            pw.Text('Address: ${inv.partyAddress}',
                style: const pw.TextStyle(fontSize: 9.5)),
          if (isGst && inv.partyGstin.isNotEmpty)
            pw.Text('GSTIN: ${inv.partyGstin}',
                style: const pw.TextStyle(fontSize: 9.5)),
        ],
      ),
    );

    // Item table. Exact column order:
    // No. | Item | HSN | Serial No. | Warranty | Qty | Rate | Tax | Discount | Amount
    final heads = <String>[
      'No.', 'Item', 'HSN', 'Serial No.', 'Warranty', 'Qty', 'Rate',
      if (isGst) 'Tax',
      'Discount', 'Amount',
    ];
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(24),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FixedColumnWidth(48),
      3: const pw.FlexColumnWidth(2.2),
      4: const pw.FixedColumnWidth(50),
      5: const pw.FixedColumnWidth(30),
      6: const pw.FixedColumnWidth(54),
      if (isGst) 7: const pw.FixedColumnWidth(34),
      (isGst ? 8 : 7): const pw.FixedColumnWidth(50),
      (isGst ? 9 : 8): const pw.FixedColumnWidth(62),
    };
    final rightFrom = 5; // Qty onwards are numbers
    pw.Widget head(int i) => _cell(
          heads[i],
          bold: true,
          size: 8.5,
          color: PdfColors.white,
          align: i >= rightFrom ? pw.TextAlign.right : pw.TextAlign.left,
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: _navy),
        children: [for (var i = 0; i < heads.length; i++) head(i)],
      ),
    ];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final serials = parseSerials(it.serials).join('\n');
      rows.add(pw.TableRow(
        decoration: i.isOdd ? pw.BoxDecoration(color: _light) : null,
        children: [
          _cell('${i + 1}'),
          _cell(it.name),
          _cell(it.hsn),
          _cell(serials, size: 7.5),
          _cell(warrantyLabel(it.warrantyMonths)),
          _cell(fmtQty(it.qty), align: pw.TextAlign.right),
          _cell(_num(it.rate), align: pw.TextAlign.right),
          if (isGst) _cell('${it.gstRate}%', align: pw.TextAlign.right),
          _cell(_num(it.discount), align: pw.TextAlign.right),
          _cell(_num(it.amount), align: pw.TextAlign.right, bold: true),
        ],
      ));
    }
    final table = pw.Table(
      columnWidths: widths,
      border: pw.TableBorder.all(color: _line, width: 0.5),
      children: rows,
    );

    // GST summary (hidden completely in NON-GST mode).
    final gstSummary = isGst
        ? pw.Container(
            width: 190,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: 0.5),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GST summary',
                    style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _blue)),
                pw.SizedBox(height: 3),
                _kv('Taxable amount', _num(inv.taxableTotal), size: 9),
                _kv('CGST', _num(inv.cgst), size: 9),
                _kv('SGST', _num(inv.sgst), size: 9),
                _kv('IGST', _num(inv.igst), size: 9),
                pw.Divider(thickness: 0.5, color: _line),
                _kv('Total GST', _num(inv.totalGst), bold: true, size: 9),
              ],
            ),
          )
        : pw.SizedBox(width: 190);

    final totals = pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _light,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          _kv('Subtotal', _num(inv.subtotal)),
          _kv('Discount', _num(inv.discountTotal)),
          pw.Divider(thickness: 0.5, color: _line),
          _kv('Grand total', _num(inv.grandTotal), bold: true, size: 11.5),
          if (!isQuote) ...[
            _kv(_receivedLabel(inv), _num(inv.paid)),
            _kv('Due amount', _num(inv.due),
                bold: true, color: inv.due > 0 ? PdfColors.red800 : null),
          ],
        ],
      ),
    );

    // Bank / UPI / QR (sales documents only).
    final hasBank = shop.bankName.isNotEmpty ||
        shop.accountNo.isNotEmpty ||
        shop.ifsc.isNotEmpty;
    final hasUpi = shop.upiId.isNotEmpty;
    final payInfo = (isSale && !isQuote && (hasBank || hasUpi))
        ? pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _line, width: 0.5),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Payment details',
                          style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: _blue)),
                      pw.SizedBox(height: 3),
                      if (shop.bankName.isNotEmpty)
                        pw.Text('Bank: ${shop.bankName}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (shop.accountNo.isNotEmpty)
                        pw.Text('A/c No: ${shop.accountNo}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (shop.ifsc.isNotEmpty)
                        pw.Text('IFSC: ${shop.ifsc}',
                            style: const pw.TextStyle(fontSize: 9)),
                      if (hasUpi)
                        pw.Text('UPI: ${shop.upiId}',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                if (hasUpi)
                  pw.Column(
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: upiLink(shop, inv),
                        width: 70,
                        height: 70,
                      ),
                      pw.Text('Scan to pay',
                          style: pw.TextStyle(fontSize: 7.5, color: _grey)),
                    ],
                  ),
              ],
            ),
          )
        : null;

    final footer = pw.Column(
      children: [
        pw.SizedBox(height: 26),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 150, height: 0.7, color: PdfColors.black),
                pw.SizedBox(height: 3),
                pw.Text('Authorised Shop Signature',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.Text(
            shop.footer.isEmpty ? 'Thank you for your business!' : shop.footer,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _blue),
          ),
        ),
      ],
    );

    return [
      header,
      title,
      party,
      pw.SizedBox(height: 10),
      table,
      pw.SizedBox(height: 10),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [gstSummary, totals],
      ),
      if (payInfo != null) ...[pw.SizedBox(height: 10), payInfo],
      pw.SizedBox(height: 10),
      _termsBox(),
      if (inv.notes.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('Notes: ${inv.notes}', style: const pw.TextStyle(fontSize: 9)),
      ],
      footer,
    ];
  }

  // ---------------- 80mm thermal ----------------

  static pw.Widget _thermalBody(
    Invoice inv,
    List<InvoiceItem> items,
    ShopSettings shop,
    pw.MemoryImage logo,
  ) {
    const fs = 8.0;
    final isGst = inv.isGst;
    final isSale = inv.kind == InvoiceKind.sale;
    final isQuote = inv.docType == DocType.quotation;
    pw.Widget center(String t, {double size = fs, bool bold = false}) =>
        pw.Center(
          child: pw.Text(
            t,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );
    pw.Widget rule() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Divider(thickness: 0.5, height: 1),
        );
    pw.Widget row(String k, String v, {bool bold = false, double size = fs}) =>
        _kv(k, v, bold: bold, size: size);

    final children = <pw.Widget>[
      pw.Center(child: pw.Image(logo, width: 38, height: 38)),
      pw.SizedBox(height: 3),
      center(shop.shopName, size: 11, bold: true),
      if (shop.address.isNotEmpty) center(shop.address),
      if (shop.phone.isNotEmpty) center('Phone: ${shop.phone}'),
      if (isGst && shop.gstin.isNotEmpty) center('GSTIN: ${shop.gstin}', bold: true),
      rule(),
      center(pdfHeading(inv), size: 10, bold: true),
      row('No', inv.number),
      row('Date', prettyDate(inv.invoiceDate)),
      rule(),
      pw.Text('${_partyLabel(inv)}: ${_partyName(inv)}',
          style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold)),
      if (inv.partyPhone.isNotEmpty)
        pw.Text('Phone: ${inv.partyPhone}', style: const pw.TextStyle(fontSize: fs)),
      if (inv.partyAddress.isNotEmpty)
        pw.Text(inv.partyAddress, style: const pw.TextStyle(fontSize: fs)),
      if (isGst && inv.partyGstin.isNotEmpty)
        pw.Text('GSTIN: ${inv.partyGstin}',
            style: const pw.TextStyle(fontSize: fs)),
      rule(),
    ];

    // Each item as a small block: No. Item / HSN / Serial No. / Warranty /
    // Qty x Rate / Tax / Discount / Amount, in the same order as the A4 table.
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final serials = parseSerials(it.serials);
      children.addAll([
        pw.Text('${i + 1}. ${it.name}',
            style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold)),
        if (it.hsn.isNotEmpty)
          pw.Text('HSN: ${it.hsn}', style: const pw.TextStyle(fontSize: 7)),
        if (serials.isNotEmpty)
          pw.Text('Serial No.: ${serials.join(', ')}',
              style: const pw.TextStyle(fontSize: 7)),
        if (it.warrantyMonths > 0)
          pw.Text('Warranty: ${warrantyLabel(it.warrantyMonths)}',
              style: const pw.TextStyle(fontSize: 7)),
        row(
          '${fmtQty(it.qty)} x ${_num(it.rate)}'
          '${isGst ? '  Tax ${it.gstRate}%' : ''}'
          '${it.discount > 0 ? '  Disc ${_num(it.discount)}' : ''}',
          _num(it.amount),
        ),
        pw.SizedBox(height: 2),
      ]);
    }
    children.add(rule());

    if (isGst) {
      children.addAll([
        pw.Text('GST summary',
            style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold)),
        row('Taxable amount', _num(inv.taxableTotal)),
        row('CGST', _num(inv.cgst)),
        row('SGST', _num(inv.sgst)),
        row('IGST', _num(inv.igst)),
        row('Total GST', _num(inv.totalGst), bold: true),
        rule(),
      ]);
    }

    children.addAll([
      row('Subtotal', _num(inv.subtotal)),
      row('Discount', _num(inv.discountTotal)),
      row('Grand total', _num(inv.grandTotal), bold: true, size: 10),
      if (!isQuote) ...[
        row(_receivedLabel(inv), _num(inv.paid)),
        row('Due amount', _num(inv.due), bold: true),
      ],
      rule(),
    ]);

    final hasBank = shop.bankName.isNotEmpty ||
        shop.accountNo.isNotEmpty ||
        shop.ifsc.isNotEmpty;
    if (isSale && !isQuote) {
      if (hasBank) {
        children.addAll([
          if (shop.bankName.isNotEmpty)
            pw.Text('Bank: ${shop.bankName}', style: const pw.TextStyle(fontSize: 7.5)),
          if (shop.accountNo.isNotEmpty)
            pw.Text('A/c No: ${shop.accountNo}', style: const pw.TextStyle(fontSize: 7.5)),
          if (shop.ifsc.isNotEmpty)
            pw.Text('IFSC: ${shop.ifsc}', style: const pw.TextStyle(fontSize: 7.5)),
        ]);
      }
      if (shop.upiId.isNotEmpty) {
        children.addAll([
          pw.Text('UPI: ${shop.upiId}', style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: upiLink(shop, inv),
              width: 80,
              height: 80,
            ),
          ),
          center('Scan to pay', size: 7),
        ]);
      }
      if (hasBank || shop.upiId.isNotEmpty) children.add(rule());
    }

    children.addAll([
      rule(),
      pw.Text('Terms & Conditions',
          style: pw.TextStyle(fontSize: fs, fontWeight: pw.FontWeight.bold)),
      for (final term in _invoiceTerms)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(term, style: const pw.TextStyle(fontSize: 7)),
        ),
      pw.SizedBox(height: 5),
    ]);

    children.addAll([
      pw.SizedBox(height: 14),
      pw.Center(
        child: pw.Column(
          children: [
            pw.Container(width: 110, height: 0.6, color: PdfColors.black),
            pw.SizedBox(height: 2),
            pw.Text('Authorised Shop Signature',
                style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      center(
        shop.footer.isEmpty ? 'Thank you for your business!' : shop.footer,
        size: 8.5,
        bold: true,
      ),
    ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // ---------------- Reports ----------------

  /// Generic table PDF for any report or statement.
  static Future<Uint8List> report(ReportData data, ShopSettings shop) async {
    final theme = await _theme();
    final doc = pw.Document(title: data.title, author: shop.shopName);
    final wide = data.columns.length > 6;
    doc.addPage(pw.MultiPage(
      pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      theme: theme,
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(shop.shopName,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12, color: _navy)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: _grey)),
          ],
        ),
      ),
      build: (ctx) => [
        pw.Text(data.title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(color: _navy),
              children: [
                for (final c in data.columns)
                  _cell(c, bold: true, size: 8, color: PdfColors.white),
              ],
            ),
            for (var i = 0; i < data.rows.length; i++)
              pw.TableRow(
                decoration: i.isOdd ? pw.BoxDecoration(color: _light) : null,
                children: [
                  for (final c in data.rows[i]) _cell(c, size: 8),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        for (final s in data.summary)
          pw.Text(s,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ));
    return doc.save();
  }
}
