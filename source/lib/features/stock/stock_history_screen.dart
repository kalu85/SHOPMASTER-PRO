import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/product_repository.dart';
import '../../core/models/product.dart';
import '../../core/models/stock_movement.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key, required this.product});

  final Product product;

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  late final Future<List<StockMovement>> _future =
      ProductRepository.instance.movements(widget.product.id!);
  String _direction = 'all';
  DateTimeRange? _dateRange;

  List<StockMovement> _filter(List<StockMovement> rows) {
    return rows.where((movement) {
      final directionMatches = _direction == 'all' ||
          (_direction == 'in' && movement.qtyChange > 0) ||
          (_direction == 'out' && movement.qtyChange < 0);
      final date = movement.createdAt;
      final rangeMatches = _dateRange == null ||
          (!date.isBefore(DateTime(
            _dateRange!.start.year,
            _dateRange!.start.month,
            _dateRange!.start.day,
          )) &&
              !date.isAfter(DateTime(
                _dateRange!.end.year,
                _dateRange!.end.month,
                _dateRange!.end.day,
                23,
                59,
                59,
                999,
              )));
      return directionMatches && rangeMatches;
    }).toList();
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _exportCsv(List<StockMovement> rows) async {
    final lines = <String>[
      ['Product', 'Date', 'Movement type', 'Quantity change', 'Reason', 'Note']
          .map(_csvCell)
          .join(','),
      for (final movement in rows)
        [
          widget.product.name,
          movement.createdAt.toIso8601String(),
          movement.qtyChange > 0
              ? 'Stock in'
              : movement.qtyChange < 0
                  ? 'Stock out'
                  : 'No change',
          movement.qtyChange,
          movement.reason,
          movement.note,
        ].map(_csvCell).join(','),
    ];
    final directory = await getTemporaryDirectory();
    final safeName = widget.product.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final file = File(p.join(
      directory.path,
      'stock_history_${safeName.isEmpty ? 'product' : safeName}.csv',
    ));
    await file.writeAsString('\uFEFF${lines.join('\n')}');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SHOPMASTER PRO stock history',
      text: 'Stock history for ${widget.product.name} (${rows.length} movements)',
    );
  }

  Future<void> _chooseDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dateRange,
      helpText: 'Filter stock movement dates',
    );
    if (selected != null) setState(() => _dateRange = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.product.name}: stock history'),
        actions: [
          IconButton(
            onPressed: _chooseDates,
            tooltip: 'Filter by date',
            icon: const Icon(Icons.date_range),
          ),
          if (_dateRange != null || _direction != 'all')
            IconButton(
              onPressed: () => setState(() {
                _dateRange = null;
                _direction = 'all';
              }),
              tooltip: 'Clear filters',
              icon: const Icon(Icons.filter_alt_off),
            ),
        ],
      ),
      body: FutureBuilder<List<StockMovement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load history: ${snap.error}'));
          }
          final allRows = snap.data ?? [];
          final rows = _filter(allRows);
          final totalIn = rows
              .where((m) => m.qtyChange > 0)
              .fold<double>(0, (sum, m) => sum + m.qtyChange);
          final totalOut = rows
              .where((m) => m.qtyChange < 0)
              .fold<double>(0, (sum, m) => sum + m.qtyChange.abs());
          final net = totalIn - totalOut;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('All')),
                            ButtonSegment(value: 'in', label: Text('Stock in')),
                            ButtonSegment(value: 'out', label: Text('Stock out')),
                          ],
                          selected: {_direction},
                          onSelectionChanged: (value) =>
                              setState(() => _direction = value.first),
                        ),
                        if (_dateRange != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} – ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _total('In', totalIn, AppColors.sales),
                                _total('Out', totalOut, AppColors.reports),
                                _total('Net', net, AppColors.neutral),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${rows.length} of ${allRows.length} movements',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: rows.isEmpty ? null : () => _exportCsv(rows),
                              icon: const Icon(Icons.file_download_outlined),
                              label: const Text('Export CSV'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(allRows.isEmpty
                                ? 'No stock movements yet.'
                                : 'No movements match these filters.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final m = rows[i];
                              final up = m.qtyChange >= 0;
                              return Card(
                                child: ListTile(
                                  title: Text(m.reason),
                                  subtitle: Text(
                                    m.note.isEmpty
                                        ? dateTimeFmt.format(m.createdAt)
                                        : '${dateTimeFmt.format(m.createdAt)}\n${m.note}',
                                  ),
                                  isThreeLine: m.note.isNotEmpty,
                                  trailing: Text(
                                    '${up ? '+' : ''}${fmtQty(m.qtyChange)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: up
                                          ? AppColors.sales
                                          : AppColors.reports,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _total(String label, double value, Color color) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            fmtQty(value),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      );
}
