import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';

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

          return ListView(
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
          );
        },
      ),
    );
  }
}
