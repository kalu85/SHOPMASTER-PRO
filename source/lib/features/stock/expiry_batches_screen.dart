import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/expiry_report_export.dart';

/// Review expiry dates recorded on purchase invoice lines.
/// Quantities shown are original purchased line quantities, not live batch balances.
class ExpiryBatchesScreen extends StatefulWidget {
  const ExpiryBatchesScreen({super.key});

  @override
  State<ExpiryBatchesScreen> createState() => _ExpiryBatchesScreenState();
}

class _ExpiryBatchesScreenState extends State<ExpiryBatchesScreen> {
  late Future<List<Map<String, Object?>>> _future = _load();
  String _filter = 'All';

  Future<List<Map<String, Object?>>> _load() async {
    final db = await AppDatabase.instance.db;
    return db.rawQuery(
      "SELECT ii.id, ii.name, ii.qty, ii.batch_number, ii.expiry_date, "
      "i.number AS invoice_number, i.invoice_date, i.party_name "
      "FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id "
      "WHERE i.kind = 'purchase' AND i.doc_type = 'invoice' "
      "AND ii.expiry_date IS NOT NULL AND ii.expiry_date != '' "
      "ORDER BY ii.expiry_date ASC, ii.id DESC",
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _export(List<Map<String, Object?>> rows, DateTime today) async {
    try {
      final csv = buildExpiryReportCsv(
        preparedAt: DateTime.now(),
        rows: [
          for (final row in rows)
            ExpiryExportRow(
              item: row['name'] as String? ?? 'Item',
              batchNumber: row['batch_number'] as String? ?? '',
              purchasedQuantity: (row['qty'] as num?)?.toDouble() ?? 0,
              purchaseInvoice: row['invoice_number'] as String? ?? '',
              supplier: row['party_name'] as String? ?? '',
              expiryDate: row['expiry_date'] as String? ?? '',
              daysLeft: _daysLeft(row, today),
            ),
        ],
      );
      final directory = await getTemporaryDirectory();
      final file = File(p.join(directory.path, 'shopmaster_batch_expiry.csv'));
      await file.writeAsString(csv, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SHOPMASTER PRO batch expiry report',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the expiry report.')),
      );
    }
  }

  int? _daysLeft(Map<String, Object?> row, DateTime today) {
    final expiry = DateTime.tryParse(row['expiry_date'] as String? ?? '');
    return expiry?.difference(today).inDays;
  }

  bool _matches(Map<String, Object?> row, DateTime today) {
    final days = _daysLeft(row, today);
    switch (_filter) {
      case 'Expired':
        return days != null && days < 0;
      case '30 days':
        return days != null && days >= 0 && days <= 30;
      case '90 days':
        return days != null && days > 30 && days <= 90;
      default:
        return true;
    }
  }

  Widget _summary(String label, int count, Color color) => Container(
    constraints: const BoxConstraints(minWidth: 95),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch expiry tracker'),
        actions: [IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load expiry records: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No expiry dates recorded yet. Add an expiry date to a purchase invoice item to track it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final expired = rows.where((r) => (_daysLeft(r, today) ?? 0) < 0).length;
          final within30 = rows.where((r) {
            final d = _daysLeft(r, today);
            return d != null && d >= 0 && d <= 30;
          }).length;
          final within90 = rows.where((r) {
            final d = _daysLeft(r, today);
            return d != null && d > 30 && d <= 90;
          }).length;
          final visible = rows.where((r) => _matches(r, today)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Export applies the selected filter: $_filter',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: visible.isEmpty ? null : () => _export(visible, today),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _summary('Expired', expired, AppColors.reports),
                _summary('Due in 30 days', within30, AppColors.stock),
                _summary('Due in 31–90 days', within90, AppColors.sales),
              ]),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Counts represent purchase invoice lines, not confirmed remaining stock. Check physical batch quantities before making stock or disposal decisions.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final filter in ['All', 'Expired', '30 days', '90 days'])
                  ChoiceChip(
                    label: Text(filter == '30 days'
                        ? 'Expiring in 30 days'
                        : filter == '90 days'
                            ? '31–90 days'
                            : filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ]),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No batches match this filter.', textAlign: TextAlign.center),
                ),
              for (final row in visible)
                Builder(builder: (context) {
                  final days = _daysLeft(row, today);
                  final isExpired = days != null && days < 0;
                  final isSoon = days != null && days <= 30;
                  final color = isExpired
                      ? AppColors.reports
                      : (isSoon ? AppColors.stock : AppColors.sales);
                  final status = days == null
                      ? 'Date unavailable'
                      : isExpired
                          ? 'Expired ${-days} day(s) ago'
                          : days == 0
                              ? 'Expires today'
                              : 'Expires in $days day(s)';
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined, color: color),
                      title: Text(
                        row['name'] as String? ?? 'Item',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text([
                        if ((row['batch_number'] as String? ?? '').isNotEmpty)
                          'Batch: ${row['batch_number']}',
                        'Purchased qty: ${row['qty']}',
                        'Purchase: ${row['invoice_number']}',
                        if ((row['party_name'] as String? ?? '').isNotEmpty)
                          'Supplier: ${row['party_name']}',
                        'Expiry: ${row['expiry_date']}',
                      ].join(' • ')),
                      trailing: Text(
                        status,
                        textAlign: TextAlign.end,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  );
                }),
            ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
