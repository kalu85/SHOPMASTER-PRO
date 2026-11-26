import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/invoice.dart';
import '../utils/csv_safety.dart';
import '../utils/serials.dart';

enum ReportType {
  salesSummary,
  purchaseSummary,
  gst,
  gstReadiness,
  gstr3bPreparation,
  caGstPack,
  nonGst,
  profitLoss,
  stock,
  lowStock,
  customerOutstanding,
  supplierOutstanding,
  outstandingAgeing,
  cash,
  bank,
  expenses,
  warranty,
  serials,
}

enum ReportGroup { day, month, year }

class ReportInfo {
  const ReportInfo(this.type, this.title, this.usesDates, {this.grouped = false});
  final ReportType type;
  final String title;
  final bool usesDates;

  /// Daily / monthly / yearly switch.
  final bool grouped;
}

const List<ReportInfo> kReports = [
  ReportInfo(ReportType.salesSummary, 'Sales (daily / monthly / yearly)', true,
      grouped: true),
  ReportInfo(
      ReportType.purchaseSummary, 'Purchases (daily / monthly / yearly)', true,
      grouped: true),
  ReportInfo(ReportType.gst, 'GST report', true),
  ReportInfo(ReportType.gstReadiness, 'CA preparation & GST data checks', true),
  ReportInfo(ReportType.gstr3bPreparation, 'GSTR-3B preparation (working paper)', true),
  ReportInfo(ReportType.caGstPack, 'GST report pack for CA', true),
  ReportInfo(ReportType.nonGst, 'NON-GST report', true),
  ReportInfo(ReportType.profitLoss, 'Profit and loss', true),
  ReportInfo(ReportType.stock, 'Stock report', false),
  ReportInfo(ReportType.lowStock, 'Low-stock report', false),
  ReportInfo(ReportType.customerOutstanding, 'Customer outstanding', false),
  ReportInfo(ReportType.supplierOutstanding, 'Supplier outstanding', false),
  ReportInfo(ReportType.outstandingAgeing, 'Outstanding ageing', false),
  ReportInfo(ReportType.cash, 'Cash report', true),
  ReportInfo(ReportType.bank, 'Bank report', true),
  ReportInfo(ReportType.expenses, 'Expense report', true),
  ReportInfo(ReportType.warranty, 'Warranty report', false),
  ReportInfo(ReportType.serials, 'Serial number report', false),
];

class ReportData {
  const ReportData({
    required this.title,
    required this.columns,
    required this.rows,
    this.summary = const [],
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String> summary;

  /// Spreadsheet-friendly CSV (opens in Excel / Google Sheets).
  String toCsv() {
    final b = StringBuffer();
    b.writeln(csvSafeCell(title));
    b.writeln(csvSafeRow(columns));
    for (final r in rows) {
      b.writeln(csvSafeRow(r));
    }
    if (summary.isNotEmpty) {
      b.writeln();
      for (final s in summary) {
        b.writeln(csvSafeCell(s));
      }
    }
    return b.toString();
  }
}

String money(num v) => v.toStringAsFixed(2);

double _d(Object? v) => ((v ?? 0) as num).toDouble();

/// Checks GSTIN shape only; it does not verify registration or checksum online.
bool isGstinFormatValid(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.length == 15 &&
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]').hasMatch(normalized);
}

/// Returns a review reason for a party GSTIN, or null when its shape is valid.
/// This is a format check only; registration must be verified separately.
String? gstinFormatReview(String value) {
  if (value.trim().isEmpty) return 'GSTIN is blank';
  if (!isGstinFormatValid(value)) return 'GSTIN format is unexpected';
  return null;
}

/// Validates report date filters as real ISO calendar dates in ascending order.
void validateReportDateRange(String from, String to) {
  DateTime? parse(String value) {
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        parsed.year.toString().padLeft(4, '0') != value.substring(0, 4) ||
        parsed.month.toString().padLeft(2, '0') != value.substring(5, 7) ||
        parsed.day.toString().padLeft(2, '0') != value.substring(8, 10)) {
      return null;
    }
    return parsed;
  }
  final start = parse(from);
  final end = parse(to);
  if (start == null || end == null) {
    throw ArgumentError('Report dates must be valid yyyy-MM-dd calendar dates.');
  }
  if (end.isBefore(start)) {
    throw ArgumentError('Report end date must be on or after the start date.');
  }
}
/// Returns true when saved invoice header totals differ from summed line totals.
/// A two-paise tolerance accommodates per-line rounding.
bool gstDocumentTotalsMismatch({
  required double headerTaxable,
  required double headerCgst,
  required double headerSgst,
  required double headerIgst,
  required double headerTotal,
  required double linesTaxable,
  required double linesCgst,
  required double linesSgst,
  required double linesIgst,
  required double linesTotal,
}) {
  const tolerance = 0.02;
  final pairs = <(double, double)>[
    (headerTaxable, linesTaxable), (headerCgst, linesCgst),
    (headerSgst, linesSgst), (headerIgst, linesIgst),
    (headerTotal, linesTotal),
  ];
  return pairs.any((pair) => !pair.$1.isFinite || !pair.$2.isFinite ||
      (pair.$1 - pair.$2).abs() > tolerance);
}

class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<ReportData> build(
    ReportType type, {
    required String from,
    required String to,
    ReportGroup group = ReportGroup.day,
  }) {
    switch (type) {
      case ReportType.salesSummary:
        return _summary(InvoiceKind.sale, from, to, group);
      case ReportType.purchaseSummary:
        return _summary(InvoiceKind.purchase, from, to, group);
      case ReportType.gst:
        return _gst(from, to);
      case ReportType.gstReadiness:
        return _gstReadiness(from, to);
      case ReportType.gstr3bPreparation:
        return _gstr3bPreparation(from, to);
      case ReportType.caGstPack:
        return _caGstPack(from, to);
      case ReportType.nonGst:
        return _nonGst(from, to);
      case ReportType.profitLoss:
        return _profitLoss(from, to);
      case ReportType.stock:
        return _stock(lowOnly: false);
      case ReportType.lowStock:
        return _stock(lowOnly: true);
      case ReportType.customerOutstanding:
        return _outstanding('customer');
      case ReportType.supplierOutstanding:
        return _outstanding('supplier');
      case ReportType.outstandingAgeing:
        return _outstandingAgeing();
      case ReportType.cash:
        return _accountReport('cash', from, to);
      case ReportType.bank:
        return _accountReport('bank', from, to);
      case ReportType.expenses:
        return _expenses(from, to);
      case ReportType.warranty:
        return _warranty();
      case ReportType.serials:
        return _serials();
    }
  }

  /// Groups unpaid invoices by age, using invoice date as the due-age proxy.
  /// The app does not currently store contractual due dates.
  Future<ReportData> _outstandingAgeing() async {
    final db = await _db;
    final today = DateTime.now();
    final rows = await db.rawQuery('''
      SELECT kind, number, party_name, invoice_date, due
      FROM invoices
      WHERE doc_type = 'invoice' AND due > 0.009
      ORDER BY invoice_date ASC, id ASC
    ''');
    final out = <List<String>>[];
    var current = 0.0, d30 = 0.0, d60 = 0.0, d90 = 0.0, total = 0.0;
    for (final row in rows) {
      final date = DateTime.tryParse(row['invoice_date'] as String? ?? '');
      final age = date == null ? 0 : today.difference(date).inDays;
      final due = _d(row['due']);
      final bucket = age <= 30 ? '0-30 days' : age <= 60 ? '31-60 days' : age <= 90 ? '61-90 days' : 'Over 90 days';
      if (age <= 30) { current += due; }
      else if (age <= 60) { d30 += due; }
      else if (age <= 90) { d60 += due; }
      else { d90 += due; }
      total += due;
      out.add([
        row['kind'] == 'sale' ? 'Customer' : 'Supplier',
        row['number'] as String? ?? '',
        row['party_name'] as String? ?? '',
        row['invoice_date'] as String? ?? '',
        age < 0 ? 'Future dated' : bucket,
        money(due),
      ]);
    }
    return ReportData(
      title: 'Outstanding ageing (age from invoice date)',
      columns: const ['Type', 'Invoice', 'Party', 'Invoice date', 'Age bucket', 'Due'],
      rows: out,
      summary: [
        '0-30 days: ${money(current)}',
        '31-60 days: ${money(d30)}',
        '61-90 days: ${money(d60)}',
        'Over 90 days: ${money(d90)}',
        'Total outstanding: ${money(total)}',
      ],
    );
  }

  Future<ReportData> _summary(
    InvoiceKind kind,
    String from,
    String to,
    ReportGroup group,
  ) async {
    final db = await _db;
    final n = switch (group) {
      ReportGroup.day => 10,
      ReportGroup.month => 7,
      ReportGroup.year => 4,
    };
    final rows = await db.rawQuery('''
      SELECT substr(invoice_date, 1, $n) AS p,
        SUM(CASE doc_type WHEN 'invoice' THEN 1 ELSE 0 END) AS cnt,
        SUM(CASE doc_type WHEN 'invoice' THEN taxable_total WHEN 'return' THEN -taxable_total ELSE 0 END) AS taxable,
        SUM(CASE doc_type WHEN 'invoice' THEN cgst + sgst + igst WHEN 'return' THEN -(cgst + sgst + igst) ELSE 0 END) AS gst,
        SUM(CASE doc_type WHEN 'invoice' THEN grand_total WHEN 'return' THEN -grand_total ELSE 0 END) AS total,
        SUM(CASE doc_type WHEN 'invoice' THEN paid WHEN 'return' THEN -paid ELSE 0 END) AS paid
      FROM invoices
      WHERE kind = ? AND doc_type != 'quotation' AND invoice_date BETWEEN ? AND ?
      GROUP BY p ORDER BY p DESC
    ''', [kind.name, from, to]);
    var tTaxable = 0.0, tGst = 0.0, tTotal = 0.0, tPaid = 0.0;
    var tCount = 0;
    final out = <List<String>>[];
    for (final r in rows) {
      tCount += (r['cnt'] as num).toInt();
      tTaxable += _d(r['taxable']);
      tGst += _d(r['gst']);
      tTotal += _d(r['total']);
      tPaid += _d(r['paid']);
      out.add([
        r['p'] as String,
        '${r['cnt']}',
        money(_d(r['taxable'])),
        money(_d(r['gst'])),
        money(_d(r['total'])),
        money(_d(r['paid'])),
      ]);
    }
    final label = kind == InvoiceKind.sale ? 'Sales' : 'Purchases';
    return ReportData(
      title: '$label report ($from to $to), returns deducted',
      columns: const ['Period', 'Invoices', 'Taxable', 'GST', 'Total', 'Paid'],
      rows: out,
      summary: [
        'Invoices: $tCount',
        'Taxable: ${money(tTaxable)}   GST: ${money(tGst)}',
        'Total: ${money(tTotal)}   Paid: ${money(tPaid)}   Due: ${money(tTotal - tPaid)}',
      ],
    );
  }

  Future<ReportData> _gst(String from, String to) async {
    final db = await _db;
    final rows = await db.query(
      'invoices',
      where:
          "is_gst = 1 AND doc_type != 'quotation' AND invoice_date BETWEEN ? AND ?",
      whereArgs: [from, to],
      orderBy: 'invoice_date, id',
    );
    var outGst = 0.0, inGst = 0.0;
    final out = <List<String>>[];
    for (final r in rows) {
      final sign = r['doc_type'] == 'return' ? -1.0 : 1.0;
      final gst = sign * (_d(r['cgst']) + _d(r['sgst']) + _d(r['igst']));
      final isSale = r['kind'] == 'sale';
      if (isSale) {
        outGst += gst;
      } else {
        inGst += gst;
      }
      out.add([
        r['invoice_date'] as String,
        '${isSale ? 'Sale' : 'Purchase'}${sign < 0 ? ' return' : ''}',
        r['number'] as String,
        r['party_name'] as String,
        r['party_gstin'] as String,
        money(sign * _d(r['taxable_total'])),
        money(sign * _d(r['cgst'])),
        money(sign * _d(r['sgst'])),
        money(sign * _d(r['igst'])),
        money(sign * _d(r['grand_total'])),
      ]);
    }
    return ReportData(
      title: 'GST report ($from to $to)',
      columns: const [
        'Date', 'Type', 'Number', 'Party', 'GSTIN', 'Taxable', 'CGST', 'SGST',
        'IGST', 'Total',
      ],
      rows: out,
      summary: [
        'GST collected on sales (output): ${money(outGst)}',
        'GST paid on purchases (input): ${money(inGst)}',
        'Net GST payable: ${money(outGst - inGst)}',
      ],
    );
  }

  /// GSTR-3B preparation working paper. This intentionally does not calculate
  /// eligible ITC or claim tax credits: the current schema does not capture
  /// ITC eligibility, reversals, reverse charge, exempt/zero-rated categories,
  /// imports, or portal-sourced adjustments.
  Future<ReportData> _gstr3bPreparation(String from, String to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT kind, doc_type, is_gst,
        SUM(CASE WHEN doc_type = 'invoice' THEN taxable_total
                 WHEN doc_type = 'return' THEN -taxable_total ELSE 0 END) AS taxable,
        SUM(CASE WHEN doc_type = 'invoice' THEN cgst
                 WHEN doc_type = 'return' THEN -cgst ELSE 0 END) AS cgst,
        SUM(CASE WHEN doc_type = 'invoice' THEN sgst
                 WHEN doc_type = 'return' THEN -sgst ELSE 0 END) AS sgst,
        SUM(CASE WHEN doc_type = 'invoice' THEN igst
                 WHEN doc_type = 'return' THEN -igst ELSE 0 END) AS igst,
        COUNT(*) AS documents
      FROM invoices
      WHERE doc_type IN ('invoice', 'return')
        AND invoice_date BETWEEN ? AND ?
      GROUP BY kind, is_gst
      ORDER BY kind, is_gst
    ''', [from, to]);

    var outwardTaxable = 0.0;
    var outputCgst = 0.0, outputSgst = 0.0, outputIgst = 0.0;
    var purchaseTaxable = 0.0;
    var purchaseCgst = 0.0, purchaseSgst = 0.0, purchaseIgst = 0.0;
    var nonGstSales = 0.0, nonGstPurchases = 0.0;
    var gstSalesDocuments = 0, gstPurchaseDocuments = 0;
    var nonGstDocuments = 0;

    for (final row in rows) {
      final isSale = row['kind'] == 'sale';
      final isGst = _d(row['is_gst']) == 1;
      final taxable = _d(row['taxable']);
      final cgst = _d(row['cgst']);
      final sgst = _d(row['sgst']);
      final igst = _d(row['igst']);
      if (!isGst) {
        nonGstDocuments += (row['documents'] as num).toInt();
        if (isSale) {
          nonGstSales += taxable;
        } else {
          nonGstPurchases += taxable;
        }
        continue;
      }
      if (isSale) {
        gstSalesDocuments += (row['documents'] as num).toInt();
        outwardTaxable += taxable;
        outputCgst += cgst;
        outputSgst += sgst;
        outputIgst += igst;
      } else {
        gstPurchaseDocuments += (row['documents'] as num).toInt();
        purchaseTaxable += taxable;
        purchaseCgst += cgst;
        purchaseSgst += sgst;
        purchaseIgst += igst;
      }
    }

    final outputTax = outputCgst + outputSgst + outputIgst;
    final recordedPurchaseTax = purchaseCgst + purchaseSgst + purchaseIgst;
    return ReportData(
      title: 'GSTR-3B preparation working paper ($from to $to)',
      columns: const ['Area', 'Particulars', 'Taxable / value', 'IGST', 'CGST', 'SGST'],
      rows: [
        ['3.1(a) draft basis', 'Recorded GST sales (returns deducted)',
          money(outwardTaxable), money(outputIgst), money(outputCgst), money(outputSgst)],
        ['Purchase review', 'GST recorded on purchase documents (not eligible ITC)',
          money(purchaseTaxable), money(purchaseIgst), money(purchaseCgst), money(purchaseSgst)],
        ['Classification review', 'Non-GST sales; classification not stored',
          money(nonGstSales), '', '', ''],
        ['Classification review', 'Non-GST purchases; classification not stored',
          money(nonGstPurchases), '', '', ''],
      ],
      summary: [
        'GST sales documents: $gstSalesDocuments; GST purchase documents: $gstPurchaseDocuments',
        'Output tax recorded: ${money(outputTax)}',
        'Input tax recorded on purchases: ${money(recordedPurchaseTax)} — NOT treated as eligible ITC.',
        'Non-GST documents needing classification: $nonGstDocuments',
        'Not a complete GSTR-3B: reverse charge, zero-rated, nil/exempt, non-GST classification, imports, ITC eligibility/reversals and other adjustments are not captured by this app data.',
        'No net tax payable or ITC claim is calculated. CA must reconcile with books, GSTR-2B and GST Portal before filing.',
        'Working paper only — not uploaded, submitted or filed with GST Portal.',
      ],
    );
  }

  /// CA preparation report: HSN-wise tax totals plus data-quality items to
  /// review. This is an internal working paper, not a GST return or filing.
  Future<ReportData> _gstReadiness(String from, String to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT i.id, i.kind, i.doc_type, i.number, i.invoice_date, i.party_name,
        i.party_gstin, i.is_gst, i.taxable_total AS header_taxable,
        i.cgst AS header_cgst, i.sgst AS header_sgst, i.igst AS header_igst,
        i.grand_total AS header_total, ii.name AS item_name, ii.hsn, ii.gst_rate,
        ii.taxable, ii.cgst, ii.sgst, ii.igst, ii.amount AS line_total
      FROM invoices i
      LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
      WHERE i.doc_type != 'quotation'
        AND i.invoice_date BETWEEN ? AND ?
      ORDER BY i.invoice_date, i.number, ii.id
    ''', [from, to]);

    final grouped = <String, Map<String, Object?>>{};
    final review = <List<String>>[];
    var outputTax = 0.0;
    var purchaseTax = 0.0;
    var nonGstDocuments = <String>{};
    var nonGstValue = 0.0;
    var missingHsn = 0;
    var blankPartyGstin = 0;
    var malformedPartyGstin = 0;
    final documentTotals = <int, Map<String, double>>{};
    final documentNumbers = <int, String>{};

    for (final row in rows) {
      final documentId = (row['id'] as num).toInt();
      documentNumbers[documentId] = row['number'] as String? ?? 'ID $documentId';
      final totals = documentTotals.putIfAbsent(documentId, () => {
        'headerTaxable': _d(row['header_taxable']),
        'headerCgst': _d(row['header_cgst']),
        'headerSgst': _d(row['header_sgst']),
        'headerIgst': _d(row['header_igst']),
        'headerTotal': _d(row['header_total']),
        'linesTaxable': 0.0, 'linesCgst': 0.0, 'linesSgst': 0.0,
        'linesIgst': 0.0, 'linesTotal': 0.0,
      });
      totals['linesTaxable'] = totals['linesTaxable']! + _d(row['taxable']);
      totals['linesCgst'] = totals['linesCgst']! + _d(row['cgst']);
      totals['linesSgst'] = totals['linesSgst']! + _d(row['sgst']);
      totals['linesIgst'] = totals['linesIgst']! + _d(row['igst']);
      totals['linesTotal'] = totals['linesTotal']! + _d(row['line_total']);
      final isSale = row['kind'] == 'sale';
      final isReturn = row['doc_type'] == 'return';
      final sign = isReturn ? -1.0 : 1.0;
      final isGst = (row['is_gst'] as num).toInt() == 1;
      final number = row['number'] as String? ?? '';
      final itemName = row['item_name'] as String? ?? '';
      final hsn = (row['hsn'] as String? ?? '').trim();
      final rate = (row['gst_rate'] as num?)?.toInt() ?? 0;
      final taxable = sign * _d(row['taxable']);
      final cgst = sign * _d(row['cgst']);
      final sgst = sign * _d(row['sgst']);
      final igst = sign * _d(row['igst']);
      final gst = cgst + sgst + igst;

      if (!isGst) {
        nonGstDocuments.add('${row['kind']}:$number');
        nonGstValue += sign * _d(row['taxable']);
        continue;
      }

      if (isSale) {
        outputTax += gst;
      } else {
        purchaseTax += gst;
      }

      if (hsn.isEmpty) {
        missingHsn++;
        review.add([
          'REVIEW',
          number,
          '$itemName: HSN is blank on a GST document; confirm the correct HSN',
          '',
          '',
          '',
          '',
        ]);
      } else {
        final key = '${row['kind']}|$hsn|$rate';
        final item = grouped.putIfAbsent(key, () => {
              'kind': row['kind'],
              'hsn': hsn,
              'rate': rate,
              'taxable': 0.0,
              'cgst': 0.0,
              'sgst': 0.0,
              'igst': 0.0,
            });
        item['taxable'] = (item['taxable'] as double) + taxable;
        item['cgst'] = (item['cgst'] as double) + cgst;
        item['sgst'] = (item['sgst'] as double) + sgst;
        item['igst'] = (item['igst'] as double) + igst;
      }

      final gstin = (row['party_gstin'] as String? ?? '').trim();
      final gstinIssue = gstinFormatReview(gstin);
      if (gstinIssue == 'GSTIN is blank') {
        blankPartyGstin++;
        review.add([
          'REVIEW',
          number,
          'Party GSTIN is blank; confirm whether this is B2C or GSTIN details are needed',
          '',
          '',
          '',
          '',
        ]);
      } else if (gstinIssue != null) {
        malformedPartyGstin++;
        review.add([
          'REVIEW',
          number,
          'Party GSTIN has an unexpected format: $gstin; verify it against the official GST Portal',
          '',
          '',
          '',
          '',
        ]);
      }
    }

    var mismatchedDocuments = 0;
    for (final entry in documentTotals.entries) {
      final totals = entry.value;
      if (gstDocumentTotalsMismatch(
        headerTaxable: totals['headerTaxable']!, headerCgst: totals['headerCgst']!,
        headerSgst: totals['headerSgst']!, headerIgst: totals['headerIgst']!,
        headerTotal: totals['headerTotal']!, linesTaxable: totals['linesTaxable']!,
        linesCgst: totals['linesCgst']!, linesSgst: totals['linesSgst']!,
        linesIgst: totals['linesIgst']!, linesTotal: totals['linesTotal']!,
      )) {
        mismatchedDocuments++;
        review.add([
          'TOTAL MISMATCH', documentNumbers[entry.key] ?? 'ID ${entry.key}',
          'Invoice header totals differ from summed saved item lines; inspect before CA reconciliation',
          money(totals['headerTaxable']! - totals['linesTaxable']!),
          money(totals['headerCgst']! - totals['linesCgst']!),
          money(totals['headerSgst']! - totals['linesSgst']!),
          money(totals['headerIgst']! - totals['linesIgst']!),
        ]);
      }
    }

    final productsWithoutHsn = await db.rawQuery('''
      SELECT name FROM products
      WHERE is_service = 0 AND TRIM(COALESCE(hsn, '')) = ''
      ORDER BY name COLLATE NOCASE
    ''');
    for (final product in productsWithoutHsn) {
      review.add([
        'CATALOG REVIEW',
        product['name'] as String? ?? '',
        'Product HSN is blank; confirm whether HSN applies and record it',
        '',
        '',
        '',
        '',
      ]);
    }

    final out = <List<String>>[
      for (final item in grouped.values)
        [
          'HSN SUMMARY',
          '${item['hsn']} / ${item['rate']}%',
          item['kind'] == 'sale' ? 'Sales (returns deducted)' : 'Purchases (returns deducted)',
          money(item['taxable'] as double),
          money(item['cgst'] as double),
          money(item['sgst'] as double),
          money(item['igst'] as double),
        ],
      ...review,
    ];

    return ReportData(
      title: 'CA preparation & GST data checks ($from to $to)',
      columns: const [
        'Section', 'Document / HSN', 'Details', 'Taxable', 'CGST', 'SGST', 'IGST',
      ],
      rows: out,
      summary: [
        'Output GST on recorded GST sales: ${money(outputTax)}',
        'Input GST recorded on purchases (eligibility must be checked by CA): ${money(purchaseTax)}',
        'Difference before CA adjustments: ${money(outputTax - purchaseTax)}',
        'GST document lines with missing HSN: $missingHsn',
        'GST document lines with blank party GSTIN (check B2B/B2C): $blankPartyGstin',
        'GST document lines with malformed party GSTIN format: $malformedPartyGstin',
        'Documents with header/line total mismatches (over 0.02 tolerance): $mismatchedDocuments',
        'Products without HSN in item catalogue: ${productsWithoutHsn.length}',
        'Non-GST documents in selected period: ${nonGstDocuments.length}; taxable base recorded: ${money(nonGstValue)}',
        'Non-GST records are not automatically exempt; CA should classify pre-registration, exempt and other supplies.',
        'Returns are deducted from their respective sales or purchase totals.',
        'Working paper only: not an official GSTR-1 / GSTR-3B return. CA must verify classification, exemptions, ITC eligibility and filing.',
      ],
    );
  }


  /// Combined CA-facing GST working paper. It contains only saved app data.
  Future<ReportData> _caGstPack(String from, String to) async {
    final db = await _db;
    final invoices = await db.query('invoices',
      where: "doc_type IN ('invoice', 'return') AND invoice_date BETWEEN ? AND ?",
      whereArgs: [from, to], orderBy: 'invoice_date, id');
    final items = await db.rawQuery('''
      SELECT i.kind, i.doc_type, i.is_gst, i.number, i.invoice_date,
        i.party_name, i.party_gstin, ii.name AS item_name, ii.hsn,
        ii.gst_rate, ii.taxable, ii.cgst, ii.sgst, ii.igst
      FROM invoices i JOIN invoice_items ii ON ii.invoice_id = i.id
      WHERE i.doc_type IN ('invoice', 'return') AND i.invoice_date BETWEEN ? AND ?
      ORDER BY i.invoice_date, i.number, ii.id
    ''', [from, to]);

    final out = <List<String>>[];
    final monthly = <String, Map<String, double>>{};
    final customerClass = <String, Map<String, double>>{};
    final hsnTotals = <String, Map<String, double>>{};
    var salesTaxable = 0.0, salesCgst = 0.0, salesSgst = 0.0, salesIgst = 0.0;
    var purchaseTaxable = 0.0, purchaseCgst = 0.0, purchaseSgst = 0.0, purchaseIgst = 0.0;
    var missingHsn = 0, missingGstin = 0, gstSaleDocs = 0, gstPurchaseDocs = 0;
    var nonGstDocs = 0, returns = 0;

    for (final inv in invoices) {
      final sale = inv['kind'] == 'sale';
      final isReturn = inv['doc_type'] == 'return';
      final gst = (inv['is_gst'] as num).toInt() == 1;
      final sign = isReturn ? -1.0 : 1.0;
      final date = inv['invoice_date'] as String? ?? '';
      final period = date.length >= 7 ? date.substring(0, 7) : date;
      final taxable = sign * _d(inv['taxable_total']);
      if (isReturn) returns++;
      if (!gst) { nonGstDocs++; continue; }
      if (sale) {
        gstSaleDocs++; salesTaxable += taxable;
        salesCgst += sign * _d(inv['cgst']); salesSgst += sign * _d(inv['sgst']); salesIgst += sign * _d(inv['igst']);
      } else {
        gstPurchaseDocs++; purchaseTaxable += taxable;
        purchaseCgst += sign * _d(inv['cgst']); purchaseSgst += sign * _d(inv['sgst']); purchaseIgst += sign * _d(inv['igst']);
      }
      final m = monthly.putIfAbsent(period, () => {'sales': 0, 'purchases': 0});
      final mk = sale ? 'sales' : 'purchases';
      m[mk] = (m[mk] ?? 0) + taxable;
      if (sale) {
        final gstin = (inv['party_gstin'] as String? ?? '').trim();
        final cls = gstin.isEmpty ? 'B2C / GSTIN blank - verify' : 'B2B (GSTIN recorded)';
        final g = customerClass.putIfAbsent(cls, () => {'taxable': 0, 'tax': 0});
        g['taxable'] = (g['taxable'] ?? 0) + taxable;
        g['tax'] = (g['tax'] ?? 0) + sign * (_d(inv['cgst']) + _d(inv['sgst']) + _d(inv['igst']));
      }
    }
    for (final row in items) {
      if ((row['is_gst'] as num).toInt() != 1) continue;
      final sign = row['doc_type'] == 'return' ? -1.0 : 1.0;
      final hsn = (row['hsn'] as String? ?? '').trim();
      if (hsn.isEmpty) { missingHsn++; continue; }
      final rate = (row['gst_rate'] as num?)?.toInt() ?? 0;
      final key = '${row['kind'] == 'sale' ? 'SALES' : 'PURCHASES'} | $hsn / $rate%';
      final g = hsnTotals.putIfAbsent(key, () => {'taxable': 0, 'cgst': 0, 'sgst': 0, 'igst': 0});
      g['taxable'] = (g['taxable'] ?? 0) + sign * _d(row['taxable']);
      g['cgst'] = (g['cgst'] ?? 0) + sign * _d(row['cgst']);
      g['sgst'] = (g['sgst'] ?? 0) + sign * _d(row['sgst']);
      g['igst'] = (g['igst'] ?? 0) + sign * _d(row['igst']);
    }

    out.add(['PERIOD SUMMARY', '', 'GST sales taxable', money(salesTaxable), 'Output GST ${money(salesCgst + salesSgst + salesIgst)}']);
    out.add(['PERIOD SUMMARY', '', 'GST purchase taxable', money(purchaseTaxable), 'Purchase GST recorded ${money(purchaseCgst + purchaseSgst + purchaseIgst)}; ITC not determined']);
    for (final e in monthly.entries) {
      out.add(['MONTHLY', e.key, 'Sales taxable', money(e.value['sales'] ?? 0), '']);
      out.add(['MONTHLY', e.key, 'Purchase taxable', money(e.value['purchases'] ?? 0), '']);
    }
    for (final e in customerClass.entries) {
      out.add(['B2B / B2C', '', e.key, money(e.value['taxable'] ?? 0), 'GST ${money(e.value['tax'] ?? 0)}']);
    }
    out.add(['TAX SPLIT', 'Output on sales', 'CGST', money(salesCgst), 'SGST ${money(salesSgst)}; IGST ${money(salesIgst)}']);
    out.add(['TAX SPLIT', 'Purchase ledger', 'CGST', money(purchaseCgst), 'SGST ${money(purchaseSgst)}; IGST ${money(purchaseIgst)} (not eligible ITC)']);
    for (final e in hsnTotals.entries) {
      final v = e.value;
      out.add(['HSN ${e.key.startsWith('SALES') ? 'SALES' : 'PURCHASES'}', '', e.key, money(v['taxable'] ?? 0), 'CGST ${money(v['cgst'] ?? 0)}; SGST ${money(v['sgst'] ?? 0)}; IGST ${money(v['igst'] ?? 0)}']);
    }
    for (final inv in invoices.where((r) => r['kind'] == 'sale' && (r['is_gst'] as num).toInt() == 1)) {
      final sign = inv['doc_type'] == 'return' ? -1.0 : 1.0;
      final gstin = (inv['party_gstin'] as String? ?? '').trim();
      out.add(['SALES REGISTER', inv['invoice_date'] as String? ?? '',
        '${inv['number']} / ${inv['party_name']}',
        money(sign * _d(inv['taxable_total'])),
        'GSTIN ${gstin.isEmpty ? 'blank - verify B2C/B2B' : gstin}; CGST ${money(sign * _d(inv['cgst']))}; SGST ${money(sign * _d(inv['sgst']))}; IGST ${money(sign * _d(inv['igst']))}']);
    }
    for (final inv in invoices.where((r) => r['kind'] == 'purchase' && (r['is_gst'] as num).toInt() == 1)) {
      final sign = inv['doc_type'] == 'return' ? -1.0 : 1.0;
      out.add(['PURCHASE REGISTER', inv['invoice_date'] as String? ?? '', '${inv['number']} / ${inv['party_name']}', money(sign * _d(inv['taxable_total'])), 'GSTIN ${inv['party_gstin'] ?? ''}; GST ${money(sign * (_d(inv['cgst']) + _d(inv['sgst']) + _d(inv['igst'])))}']);
    }
    // Invoice-wise line detail lets the CA trace each HSN amount back to its
    // source document. Returns are shown with negative values.
    for (final row in items) {
      final sign = row['doc_type'] == 'return' ? -1.0 : 1.0;
      final hsn = (row['hsn'] as String? ?? '').trim();
      final gstin = (row['party_gstin'] as String? ?? '').trim();
      out.add([
        'INVOICE HSN DETAIL',
        row['invoice_date'] as String? ?? '',
        '${row['number']} / ${row['party_name']} / ${row['item_name']}',
        money(sign * _d(row['taxable'])),
        '${row['kind'] == 'sale' ? 'Sales' : 'Purchase'}; HSN ${hsn.isEmpty ? 'MISSING' : hsn}; Rate ${row['gst_rate'] ?? 0}%; GSTIN ${gstin.isEmpty ? 'blank' : gstin}; CGST ${money(sign * _d(row['cgst']))}; SGST ${money(sign * _d(row['sgst']))}; IGST ${money(sign * _d(row['igst']))}',
      ]);
    }
    for (final inv in invoices.where((r) => (r['is_gst'] as num).toInt() == 1)) {
      final gstin = (inv['party_gstin'] as String? ?? '').trim();
      final number = inv['number'] as String? ?? '';
      final party = inv['party_name'] as String? ?? '';
      final kind = inv['kind'] == 'sale' ? 'Sales' : 'Purchase';
      if (gstin.isEmpty) {
        if (inv['kind'] == 'sale') missingGstin++;
        out.add([
          'DATA CHECK', number,
          '$kind party GSTIN blank; verify B2B/B2C or supplier details', '',
        ]);
      } else if (!isGstinFormatValid(gstin)) {
        out.add([
          'DATA CHECK', number,
          '$kind party $party has a GSTIN with an unexpected format: $gstin',
          '', 'Check the GSTIN against the official GST Portal before filing',
        ]);
      }
    }
    final productsWithoutHsn = await db.rawQuery("SELECT name FROM products WHERE is_service = 0 AND TRIM(COALESCE(hsn, '')) = '' ORDER BY name COLLATE NOCASE");
    for (final p in productsWithoutHsn) {
      out.add(['DATA CHECK', '', 'Catalogue item missing HSN: ${p['name']}', '', '']);
    }
    out.add(['RETURNS', '', 'Sales and purchase returns', '$returns documents', 'Returns are netted from relevant totals']);
    out.add(['GSTR-3B WORKING PAPER', '3.1(a) draft basis', 'Recorded outward taxable sales', money(salesTaxable), 'Output tax: IGST ${money(salesIgst)}, CGST ${money(salesCgst)}, SGST ${money(salesSgst)}']);
    out.add(['GSTR-3B WORKING PAPER', 'Purchase review', 'Purchase GST recorded; ITC eligibility not assessed', money(purchaseTaxable), 'IGST ${money(purchaseIgst)}, CGST ${money(purchaseCgst)}, SGST ${money(purchaseSgst)}']);
    out.add(['GSTR-3B WORKING PAPER', 'Classification review', 'Non-GST documents', '$nonGstDocs', 'Classify with CA; not automatically exempt']);

    return ReportData(
      title: 'SHOPMASTER PRO – GST report pack for CA ($from to $to)',
      columns: const ['Section', 'Date / Period', 'Document / Party / HSN', 'Taxable / Value', 'Tax / Review notes'],
      rows: out,
      summary: [
        'GST sales documents: $gstSaleDocs; GST purchase documents: $gstPurchaseDocs; returns: $returns; non-GST documents: $nonGstDocs',
        'Recorded output tax: ${money(salesCgst + salesSgst + salesIgst)} (CGST ${money(salesCgst)}, SGST ${money(salesSgst)}, IGST ${money(salesIgst)})',
        'Purchase-side GST recorded: ${money(purchaseCgst + purchaseSgst + purchaseIgst)} — not treated as eligible ITC.',
        'GST document lines with missing HSN: $missingHsn; sales invoices with blank party GSTIN: $missingGstin; catalogue items without HSN: ${productsWithoutHsn.length}',
        'CA must reconcile purchase invoices with GST Portal GSTR-2B and verify ITC, reverse charge, exempt/nil/zero-rated supplies, place of supply, amendments and other adjustments.',
        'This report uses only records saved in SHOPMASTER PRO. It is a CA working-paper pack, not an official GSTR-1/GSTR-3B, GSTN data, or a filed return.',
      ],
    );
  }

  Future<ReportData> _nonGst(String from, String to) async {
    final db = await _db;
    final rows = await db.query(
      'invoices',
      where:
          "is_gst = 0 AND doc_type != 'quotation' AND invoice_date BETWEEN ? AND ?",
      whereArgs: [from, to],
      orderBy: 'invoice_date, id',
    );
    var sales = 0.0, purchases = 0.0;
    final out = <List<String>>[];
    for (final r in rows) {
      final sign = r['doc_type'] == 'return' ? -1.0 : 1.0;
      final isSale = r['kind'] == 'sale';
      final total = sign * _d(r['grand_total']);
      if (isSale) {
        sales += total;
      } else {
        purchases += total;
      }
      out.add([
        r['invoice_date'] as String,
        '${isSale ? 'Sale' : 'Purchase'}${sign < 0 ? ' return' : ''}',
        r['number'] as String,
        r['party_name'] as String,
        money(total),
        money(sign * _d(r['paid'])),
        money(sign * _d(r['due'])),
      ]);
    }
    return ReportData(
      title: 'NON-GST report ($from to $to)',
      columns: const ['Date', 'Type', 'Number', 'Party', 'Total', 'Paid', 'Due'],
      rows: out,
      summary: [
        'NON-GST sales: ${money(sales)}',
        'NON-GST purchases: ${money(purchases)}',
      ],
    );
  }

  Future<ReportData> _profitLoss(String from, String to) async {
    final db = await _db;
    final rev = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE doc_type WHEN 'invoice' THEN taxable_total WHEN 'return' THEN -taxable_total ELSE 0 END), 0) AS t
      FROM invoices WHERE kind = 'sale' AND doc_type != 'quotation' AND invoice_date BETWEEN ? AND ?
    ''', [from, to]);
    final cogs = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE i.doc_type WHEN 'invoice' THEN ii.qty * COALESCE(NULLIF(ii.purchase_rate_snapshot, 0), p.purchase_rate, 0) WHEN 'return' THEN -ii.qty * COALESCE(NULLIF(ii.purchase_rate_snapshot, 0), p.purchase_rate, 0) ELSE 0 END), 0) AS t
      FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      LEFT JOIN products p ON p.id = ii.product_id
      WHERE i.kind = 'sale' AND i.doc_type != 'quotation' AND i.invoice_date BETWEEN ? AND ?
    ''', [from, to]);
    final exp = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS t FROM expenses WHERE expense_date BETWEEN ? AND ?',
        [from, to]);
    final revenue = _d(rev.first['t']);
    final cost = _d(cogs.first['t']);
    final expenses = _d(exp.first['t']);
    final gross = revenue - cost;
    final net = gross - expenses;
    return ReportData(
      title: 'Profit and loss ($from to $to)',
      columns: const ['Item', 'Amount'],
      rows: [
        ['Sales (excluding GST, returns deducted)', money(revenue)],
        ['Cost of goods sold', money(cost)],
        ['Gross profit', money(gross)],
        ['Expenses', money(expenses)],
        ['Net profit', money(net)],
      ],
      summary: const [
        'New invoices use the purchase cost saved on each line. Older invoices without a saved cost fall back to the current product purchase rate and remain estimates.',
      ],
    );
  }

  Future<ReportData> _stock({required bool lowOnly}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: lowOnly
          ? 'is_service = 0 AND min_stock > 0 AND current_stock <= min_stock'
          : 'is_service = 0',
      orderBy: 'name COLLATE NOCASE',
    );
    var value = 0.0;
    final out = <List<String>>[];
    for (final r in rows) {
      final stock = _d(r['current_stock']);
      final rate = _d(r['purchase_rate']);
      value += stock * rate;
      out.add([
        r['name'] as String,
        r['category'] as String,
        stock.toStringAsFixed(stock == stock.roundToDouble() ? 0 : 2),
        _d(r['min_stock']).toStringAsFixed(0),
        money(rate),
        money(stock * rate),
      ]);
    }
    return ReportData(
      title: lowOnly ? 'Low-stock report' : 'Stock report',
      columns: const ['Item', 'Category', 'Stock', 'Min', 'Purchase rate', 'Value'],
      rows: out,
      summary: ['Items: ${out.length}   Stock value: ${money(value)}'],
    );
  }

  Future<ReportData> _outstanding(String type) async {
    final db = await _db;
    final rows = await db.query(
      'parties',
      where: 'type = ? AND current_balance != 0',
      whereArgs: [type],
      orderBy: 'current_balance DESC',
    );
    var total = 0.0;
    final out = <List<String>>[];
    for (final r in rows) {
      total += _d(r['current_balance']);
      out.add([
        r['name'] as String,
        r['phone'] as String,
        money(_d(r['current_balance'])),
      ]);
    }
    final isCustomer = type == 'customer';
    return ReportData(
      title: isCustomer ? 'Customer outstanding' : 'Supplier outstanding',
      columns: [
        isCustomer ? 'Customer' : 'Supplier',
        'Phone',
        isCustomer ? 'To receive' : 'To pay',
      ],
      rows: out,
      summary: ['Total: ${money(total)}'],
    );
  }

  Future<ReportData> _accountReport(String kind, String from, String to) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT t.*, a.name AS account_name FROM account_txns t
      JOIN accounts a ON a.id = t.account_id
      WHERE a.kind = ? AND t.txn_date BETWEEN ? AND ?
      ORDER BY t.txn_date, t.id
    ''', [kind, from, to]);
    var tin = 0.0, tout = 0.0;
    final out = <List<String>>[];
    for (final r in rows) {
      final isIn = r['direction'] == 'in';
      final amt = _d(r['amount']);
      if (isIn) {
        tin += amt;
      } else {
        tout += amt;
      }
      out.add([
        r['txn_date'] as String,
        r['account_name'] as String,
        r['kind'] as String,
        '${r['ref']} ${r['note']}'.trim(),
        isIn ? money(amt) : '',
        isIn ? '' : money(amt),
      ]);
    }
    return ReportData(
      title: '${kind == 'cash' ? 'Cash' : 'Bank'} report ($from to $to)',
      columns: const ['Date', 'Account', 'Type', 'Details', 'In', 'Out'],
      rows: out,
      summary: [
        'Money in: ${money(tin)}   Money out: ${money(tout)}   Net: ${money(tin - tout)}',
      ],
    );
  }

  Future<ReportData> _expenses(String from, String to) async {
    final db = await _db;
    final rows = await db.query(
      'expenses',
      where: 'expense_date BETWEEN ? AND ?',
      whereArgs: [from, to],
      orderBy: 'expense_date, id',
    );
    var total = 0.0;
    final byCat = <String, double>{};
    final out = <List<String>>[];
    for (final r in rows) {
      final amt = _d(r['amount']);
      total += amt;
      byCat[r['category'] as String] =
          (byCat[r['category'] as String] ?? 0) + amt;
      out.add([
        r['expense_date'] as String,
        r['category'] as String,
        r['pay_mode'] as String,
        r['notes'] as String,
        money(amt),
      ]);
    }
    return ReportData(
      title: 'Expense report ($from to $to)',
      columns: const ['Date', 'Category', 'Mode', 'Notes', 'Amount'],
      rows: out,
      summary: [
        'Total expenses: ${money(total)}',
        for (final e in byCat.entries) '${e.key}: ${money(e.value)}',
      ],
    );
  }

  Future<ReportData> _warranty() async {
    final db = await _db;
    final rows = await db.query(
      'serials',
      where: "warranty_expiry IS NOT NULL AND status = 'sold'",
      orderBy: 'warranty_expiry',
    );
    final now = DateTime.now();
    var active = 0, expiring = 0, expired = 0;
    final out = <List<String>>[];
    for (final r in rows) {
      final st = warrantyState(r['warranty_expiry'] as String?, now);
      final label = switch (st) {
        WarrantyState.active => 'Active',
        WarrantyState.expiring => 'Expiring soon',
        WarrantyState.expired => 'Expired',
        WarrantyState.none => '-',
      };
      switch (st) {
        case WarrantyState.active:
          active++;
        case WarrantyState.expiring:
          expiring++;
        case WarrantyState.expired:
          expired++;
        case WarrantyState.none:
          break;
      }
      out.add([
        r['serial'] as String,
        r['product_name'] as String,
        r['customer_name'] as String,
        (r['sold_date'] as String?) ?? '',
        (r['warranty_expiry'] as String?) ?? '',
        label,
      ]);
    }
    return ReportData(
      title: 'Warranty report',
      columns: const ['Serial', 'Item', 'Customer', 'Sold', 'Expires', 'Status'],
      rows: out,
      summary: [
        'Active: $active   Expiring soon: $expiring   Expired: $expired',
      ],
    );
  }

  Future<ReportData> _serials() async {
    final db = await _db;
    final rows = await db.query('serials', orderBy: 'id DESC');
    return ReportData(
      title: 'Serial number report',
      columns: const ['Serial', 'Item', 'Status', 'Purchase', 'Sale', 'Customer'],
      rows: [
        for (final r in rows)
          [
            r['serial'] as String,
            r['product_name'] as String,
            r['status'] as String,
            r['purchase_number'] as String,
            r['sale_number'] as String,
            r['customer_name'] as String,
          ],
      ],
      summary: ['Total serial numbers: ${rows.length}'],
    );
  }
}
