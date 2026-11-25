import 'package:flutter/material.dart';

import '../../core/data/product_repository.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'adjust_stock_dialog.dart';
import 'product_form_screen.dart';
import 'stock_history_screen.dart';
import 'smart_inventory_card.dart';
import 'expiry_batches_screen.dart';

/// Items and Stock module (amber department colour).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _repo = ProductRepository.instance;
  final _search = TextEditingController();
  List<Product> _items = [];
  Map<int, String> _suppliers = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.list(query: _search.text);
      final sup = await _repo.lastSuppliers();
      if (!mounted) return;
      setState(() {
        _suppliers = sup;
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load items: $e';
      });
    }
  }

  Future<void> _openForm([Product? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (saved == true) _load();
  }

  Future<void> _adjust(Product p) async {
    final done = await showAdjustStockDialog(context, p);
    if (done == true) _load();
  }

  Future<void> _history(Product p) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => StockHistoryScreen(product: p)),
    );
  }

  Future<void> _delete(Product p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete item?',
      message:
          '"${p.name}" and its stock history will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _repo.delete(p.id!);
    _load();
  }

  String _subtitle(Product p) {
    final parts = <String>[
      if (p.category.isNotEmpty) p.category,
      if (p.hsn.isNotEmpty) 'HSN ${p.hsn}',
      'Sale ${inr.format(p.saleRate)}',
      if (p.purchaseRate > 0) 'Buy ${inr.format(p.purchaseRate)}',
      'GST ${p.gstRate}%',
      if ((_suppliers[p.id] ?? p.supplierName).isNotEmpty)
        'Supplier ${_suppliers[p.id] ?? p.supplierName}',
    ];
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.stock,
        foregroundColor: AppColors.navy,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search name, category, HSN or barcode',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpiryBatchesScreen())),
                    icon: const Icon(Icons.event_busy_rounded),
                    label: const Text('Batch expiry tracker'),
                  ),
                ),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const SmartInventoryCard(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _search.text.isEmpty
                  ? 'No items yet. Tap "Add item" to create your first product.'
                  : 'No items match your search.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) return const SmartInventoryCard();
        final p = _items[i - 1];
        return Card(
          child: ListTile(
            onTap: () => _openForm(p),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_subtitle(p)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StockChip(product: p),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _openForm(p);
                      case 'adjust':
                        _adjust(p);
                      case 'history':
                        _history(p);
                      case 'delete':
                        _delete(p);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'adjust',
                      enabled: !p.isService,
                      child: const Text('Adjust stock'),
                    ),
                    PopupMenuItem(
                      value: 'history',
                      enabled: !p.isService,
                      child: const Text('Stock history'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    late final Color color;
    late final String text;
    if (p.isService) {
      color = AppColors.neutral;
      text = 'Service';
    } else if (p.isNegative) {
      color = AppColors.reports;
      text = '${fmtQty(p.currentStock)} (negative)';
    } else if (p.isLow) {
      color = AppColors.stock;
      text = '${fmtQty(p.currentStock)} low';
    } else {
      color = AppColors.sales;
      text = fmtQty(p.currentStock);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: p.isService ? AppColors.textMuted : color,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
