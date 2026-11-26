import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/app_database.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/stock_reorder_export.dart';

/// Inventory health, reorder suggestions, supplier grouping and slow-stock hints.
class SmartInventoryCard extends StatefulWidget {
  const SmartInventoryCard({super.key});

  @override
  State<SmartInventoryCard> createState() => _SmartInventoryCardState();
}

class _SmartInventoryCardState extends State<SmartInventoryCard> {
  bool _loading = true;
  String? _error;
  double _stockValue = 0;
  List<_ReorderItem> _reorder = [];
  List<String> _slow = [];
  List<String> _fast = [];
  int _deadStock = 0;
  Map<String, List<String>> _bySupplier = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await AppDatabase.instance.db;
      final rows = await db.query('products',
          where: 'is_service = 0', orderBy: 'name COLLATE NOCASE');
      final products = rows.map(Product.fromMap).toList();
      final sales = await db.rawQuery("""
        SELECT product_id, SUM(-qty_change) AS sold
        FROM stock_movements
        WHERE qty_change < 0 AND reason LIKE 'Sale%'
          AND substr(created_at, 1, 10) >= date('now', '-30 days')
        GROUP BY product_id
      """);
      final sold30 = <int, double>{
        for (final row in sales)
          row['product_id'] as int: (row['sold'] as num).toDouble(),
      };
      final lastSales = await db.rawQuery("""
        SELECT product_id, MAX(created_at) AS last_sale
        FROM stock_movements
        WHERE qty_change < 0 AND reason LIKE 'Sale%'
        GROUP BY product_id
      """);
      final lastSale = <int, String>{
        for (final row in lastSales)
          row['product_id'] as int: row['last_sale'] as String,
      };
      double value = 0;
      final reorder = <_ReorderItem>[];
      final slow = <String>[];
      final fast = <String>[];
      var dead = 0;
      final suppliers = <String, List<String>>{};
      final now = DateTime.now();
      for (final p in products) {
        value += p.currentStock * p.purchaseRate;
        if (p.minStock > 0 && p.currentStock <= p.minStock) {
          final sold = sold30[p.id] ?? 0;
          final target = (p.minStock * 2).clamp(
              p.minStock, p.minStock + sold);
          final qty = (target - p.currentStock).clamp(0, double.infinity).toDouble();
          final supplier = p.supplierName.trim().isEmpty
              ? 'Supplier not assigned'
              : p.supplierName.trim();
          reorder.add(_ReorderItem(p, qty, supplier, sold));
          (suppliers[supplier] ??= []).add(
              '${p.name}: ${fmtQty(qty)}');
        }
        final monthly = sold30[p.id] ?? 0;
        if (monthly >= 5) fast.add('${p.name} • ${fmtQty(monthly)} sold');
        if (p.currentStock > 0 && monthly == 0) {
          final stamp = lastSale[p.id];
          if (stamp == null) {
            dead++;
            slow.add('${p.name} • no recorded sales');
          } else {
            final date = DateTime.tryParse(stamp);
            if (date != null && now.difference(date).inDays >= 90) {
              dead++;
              slow.add('${p.name} • no sale in 90+ days');
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _stockValue = value;
        _reorder = reorder;
        _slow = slow;
        _fast = fast;
        _deadStock = dead;
        _bySupplier = suppliers;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Inventory insights could not be loaded.';
        _loading = false;
      });
    }
  }

  Future<void> _copyReorderList() async {
    if (_reorder.isEmpty) return;
    final buffer = StringBuffer('SHOPMASTER PRO - PURCHASE REORDER LIST\n');
    buffer.writeln('Prepared: ${DateTime.now().toLocal().toString().substring(0, 16)}');
    buffer.writeln();
    for (final entry in _bySupplier.entries) {
      buffer.writeln(entry.key);
      for (final line in entry.value) {
        buffer.writeln('  • $line');
      }
      buffer.writeln();
    }
    buffer.writeln('Please confirm availability and rates before ordering.');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supplier-wise reorder list copied.')),
    );
  }

  Future<void> _exportReorderCsv() async {
    if (_reorder.isEmpty) return;
    try {
      final csv = buildStockReorderCsv(
        preparedAt: DateTime.now(),
        rows: [
          for (final item in _reorder)
            StockReorderCsvRow(
              supplier: item.supplier,
              item: item.product.name,
              currentStock: item.product.currentStock,
              minimumStock: item.product.minStock,
              soldLast30Days: item.soldLast30Days,
              suggestedOrderQty: item.quantity,
              purchaseRate: item.product.purchaseRate,
            ),
        ],
      );
      final directory = await getTemporaryDirectory();
      final file = File(p.join(directory.path, 'shopmaster_stock_reorder.csv'));
      await file.writeAsString(csv, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'SHOPMASTER PRO stock reorder list',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the reorder spreadsheet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_graph_rounded, color: AppColors.stock),
            const SizedBox(width: 8),
            Expanded(child: Text('Smart Inventory',
                style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              tooltip: 'Refresh inventory insights',
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
          if (_loading) const LinearProgressIndicator()
          else if (_error != null) Text(_error!)
          else ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              _metric('Stock value', inr.format(_stockValue), Icons.inventory_2),
              _metric('Reorder items', '${_reorder.length}', Icons.shopping_cart),
              _metric('Dead / slow stock', '$_deadStock', Icons.hourglass_bottom),
            ]),
            const SizedBox(height: 12),
            if (_reorder.isNotEmpty) ...[
              Row(children: [
                const Expanded(child: Text('Suggested reorder',
                    style: TextStyle(fontWeight: FontWeight.w700))),
                OutlinedButton.icon(
                  onPressed: _copyReorderList,
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copy list'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportReorderCsv,
                  icon: const Icon(Icons.table_chart_rounded, size: 17),
                  label: const Text('Export CSV'),
                ),
              ]),
              for (final item in _reorder.take(8))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.product.name),
                  subtitle: Text(item.supplier),
                  trailing: Text('Order ${fmtQty(item.quantity)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              if (_bySupplier.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Group purchase list by supplier'),
                  children: [
                    for (final entry in _bySupplier.entries)
                      ListTile(
                        dense: true,
                        title: Text(entry.key),
                        subtitle: Text(entry.value.join('  •  ')),
                      ),
                  ],
                ),
            ] else
              const Text('No items currently need reordering.',
                  style: TextStyle(color: AppColors.textMuted)),
            if (_fast.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Fast-moving products (${_fast.length})'),
                children: [for (final item in _fast.take(10))
                  ListTile(dense: true, title: Text(item))],
              ),
            if (_slow.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Dead / slow-stock review (${_slow.length})'),
                children: [for (final item in _slow.take(15))
                  ListTile(dense: true, title: Text(item))],
              ),
            const SizedBox(height: 4),
            const Text(
              'Suggestions use the minimum-stock setting and recorded sales in the last 30 days. Stock value uses current purchase rates. Review quantities before ordering.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
    width: 145,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: AppColors.stock),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
    ]),
  );
}

class _ReorderItem {
  const _ReorderItem(
    this.product,
    this.quantity,
    this.supplier,
    this.soldLast30Days,
  );

  final Product product;
  final double quantity;
  final String supplier;
  final double soldLast30Days;
}
