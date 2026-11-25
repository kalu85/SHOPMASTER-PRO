import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/report_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// List of all reports.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in kReports)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.reports),
                  title: Text(r.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportViewScreen(info: r))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReportViewScreen extends StatefulWidget {
  const ReportViewScreen({super.key, required this.info});

  final ReportInfo info;

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  late DateTimeRange _range;
  ReportGroup _group = ReportGroup.day;
  ReportData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, now.day));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _error = null;
    });
    try {
      final d = await ReportRepository.instance.build(
        widget.info.type,
        from: isoDateFmt.format(_range.start),
        to: isoDateFmt.format(_range.end),
        group: _group,
      );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      _load();
    }
  }

  String get _slug =>
      widget.info.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  Future<void> _exportCsv() async {
    final d = _data;
    if (d == null) return;
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, '$_slug.csv'));
    await f.writeAsString(d.toCsv());
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')],
        subject: d.title);
  }

  Future<void> _exportPdf() async {
    final d = _data;
    if (d == null) return;
    final shop = await SettingsRepository.instance.load();
    final bytes = await PdfService.report(d, shop);
    await Printing.sharePdf(bytes: bytes, filename: '$_slug.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: Text(info.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (info.usesDates)
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                        '${dateFmt.format(_range.start)} - ${dateFmt.format(_range.end)}'),
                  ),
                if (info.grouped)
                  SegmentedButton<ReportGroup>(
                    segments: const [
                      ButtonSegment(value: ReportGroup.day, label: Text('Daily')),
                      ButtonSegment(
                          value: ReportGroup.month, label: Text('Monthly')),
                      ButtonSegment(
                          value: ReportGroup.year, label: Text('Yearly')),
                    ],
                    selected: {_group},
                    onSelectionChanged: (s) {
                      _group = s.first;
                      _load();
                    },
                  ),
                FilledButton.icon(
                  onPressed: d == null ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.bankUpi),
                  onPressed: d == null ? null : _exportCsv,
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Spreadsheet (CSV)'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text('Could not build the report: $_error'))
                : d == null
                    ? const Center(child: CircularProgressIndicator())
                    : d.rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No data for this report.',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                                const SizedBox(height: 8),
                                for (final s in d.summary) Text(s),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DataTable(
                                    headingRowColor: WidgetStatePropertyAll(
                                        AppColors.lightBlue),
                                    columns: [
                                      for (final c in d.columns)
                                        DataColumn(
                                            label: Text(c,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800))),
                                    ],
                                    rows: [
                                      for (final r in d.rows)
                                        DataRow(cells: [
                                          for (final c in r)
                                            DataCell(Text(c)),
                                        ]),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  for (final s in d.summary)
                                    Text(s,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
