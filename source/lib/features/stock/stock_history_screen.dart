import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.product.name}: stock history')),
      body: FutureBuilder<List<StockMovement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load history: ${snap.error}'));
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('No stock movements yet.'));
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          color: up ? AppColors.sales : AppColors.reports,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
