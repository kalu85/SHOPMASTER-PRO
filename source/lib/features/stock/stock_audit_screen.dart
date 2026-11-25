import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Read-only reconciliation of current product stock against recorded movements.
class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({super.key});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  late Future<List<Map<String, Object?>>> _future = _load();
  bool _showOnlyDifferences = false;

  Future<List<Map<String, Object?>>> _load() async {
    final db = await AppDatabase.instance.db;
    return db.rawQuery(
      "SELECT p.id, p.name, p.current_stock, "
      "COALESCE(SUM(sm.qty_change), 0) AS movement_stock, "
      "COUNT(sm.id) AS movement_count "
      "FROM products p LEFT JOIN stock_movements sm ON sm.product_id = p.id "
      "WHERE p.is_service = 0 "
      "GROUP BY p.id, p.name, p.current_stock "
      "ORDER BY p.name COLLATE NOCASE",
    );
  }

  void _refresh() => setState(() => _future = _load());

  double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock reconciliation audit'),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not run stock audit: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? [];
          final differences = rows.where((row) =>
              (_number(row['current_stock']) - _number(row['movement_stock'])).abs() > 0.000001).toList();
          final visible = _showOnlyDifferences ? differences : rows;
          final movementTotal = rows.fold<double>(0, (sum, row) => sum + _number(row['movement_stock']));
          final currentTotal = rows.fold<double>(0, (sum, row) => sum + _number(row['current_stock']));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _summary('Products checked', rows.length, AppColors.neutral),
                _summary('Differences', differences.length,
                    differences.isEmpty ? AppColors.sales : AppColors.reports),
              ]),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current stock total: ${fmtQty(currentTotal)}'),
                      Text('Movement ledger total: ${fmtQty(movementTotal)}'),
                      const SizedBox(height: 6),
                      const Text(
                        'Read-only check: compares each item’s saved current stock with the sum of its recorded stock movements. It does not change stock.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show differences only'),
                value: _showOnlyDifferences,
                onChanged: (value) => setState(() => _showOnlyDifferences = value),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(rows.isEmpty ? 'No stock products to audit.' : 'No differences found.',
                      textAlign: TextAlign.center),
                ),
              for (final row in visible)
                Builder(builder: (context) {
                  final current = _number(row['current_stock']);
                  final ledger = _number(row['movement_stock']);
                  final difference = current - ledger;
                  final hasDifference = difference.abs() > 0.000001;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        hasDifference ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: hasDifference ? AppColors.reports : AppColors.sales,
                      ),
                      title: Text(row['name'] as String? ?? 'Item'),
                      subtitle: Text(
                        'Current: ${fmtQty(current)} • Ledger: ${fmtQty(ledger)} • Movements: ${row['movement_count']}',
                      ),
                      trailing: Text(
                        '${difference > 0 ? '+' : ''}${fmtQty(difference)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: hasDifference ? AppColors.reports : AppColors.sales,
                        ),
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

  Widget _summary(String label, int value, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}
