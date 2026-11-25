import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';

/// Review expiry dates recorded on purchase invoice lines.
/// Quantities shown are the original purchased line quantities, not live batch balances.
class ExpiryBatchesScreen extends StatefulWidget {
  const ExpiryBatchesScreen({super.key});

  @override
  State<ExpiryBatchesScreen> createState() => _ExpiryBatchesScreenState();
}

class _ExpiryBatchesScreenState extends State<ExpiryBatchesScreen> {
  late Future<List<Map<String, Object?>>> _future = _load();

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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch expiry tracker'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
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
                child: Text('No expiry dates recorded yet. Add an expiry date to a purchase invoice item to track it here.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('This tracker lists purchased invoice lines with expiry dates. Quantities are original purchase quantities; current remaining batch stock is not calculated yet.'),
                ),
              ),
              for (final row in rows)
                Builder(builder: (context) {
                  final expiry = DateTime.tryParse(row['expiry_date'] as String? ?? '');
                  final days = expiry == null ? null : expiry.difference(todayOnly).inDays;
                  final expired = days != null && days < 0;
                  final soon = days != null && days <= 30;
                  final color = expired ? AppColors.reports : (soon ? AppColors.stock : AppColors.sales);
                  final status = days == null ? 'Date unavailable' : expired ? 'Expired ${-days} day(s) ago' : days == 0 ? 'Expires today' : 'Expires in $days day(s)';
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined, color: color),
                      title: Text(row['name'] as String? ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if ((row['batch_number'] as String? ?? '').isNotEmpty) 'Batch: ${row['batch_number']}',
                        'Purchased qty: ${row['qty']}',
                        'Purchase: ${row['invoice_number']}',
                        if ((row['party_name'] as String? ?? '').isNotEmpty) 'Supplier: ${row['party_name']}',
                        'Expiry: ${row['expiry_date']}',
                      ].join(' • ')),
                      trailing: Text(status, textAlign: TextAlign.end, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
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
