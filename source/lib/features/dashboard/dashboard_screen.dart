import 'package:flutter/material.dart';

import '../../core/data/account_repository.dart';
import 'profit_overview_card.dart';
import '../../core/data/invoice_repository.dart';
import '../../core/data/party_repository.dart';
import '../../core/models/account.dart';
import '../../core/models/invoice.dart';
import '../../core/data/product_repository.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/stat_card.dart';

/// Overview screen. All figures are read live from the local database.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenModule});

  /// Navigates to a module by its id (see appModules).
  final void Function(String moduleId) onOpenModule;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _stockItems = 0;
  double _outstanding = 0;
  double _todaySales = 0;
  double _todayPurchases = 0;
  double _cash = 0;
  double _bank = 0;
  List<Product> _lowStock = const [];
  List<Invoice> _recent = const [];
  List<AccountTxn> _txns = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ProductRepository.instance.count();
      final low = await ProductRepository.instance.lowStock();
      final out = await PartyRepository.instance.customerOutstanding();
      final today = isoDateFmt.format(DateTime.now());
      final sales =
          await InvoiceRepository.instance.netTotalOn(InvoiceKind.sale, today);
      final purchases = await InvoiceRepository.instance
          .netTotalOn(InvoiceKind.purchase, today);
      final recent = await InvoiceRepository.instance.recent();
      final cash = await AccountRepository.instance.totalBalance('cash');
      final bank = await AccountRepository.instance.totalBalance('bank');
      final txns = await AccountRepository.instance.txns(limit: 6);
      if (!mounted) return;
      setState(() {
        _stockItems = items;
        _lowStock = low;
        _outstanding = out;
        _todaySales = sales;
        _todayPurchases = purchases;
        _recent = recent;
        _cash = cash;
        _bank = bank;
        _txns = txns;
      });
    } catch (_) {
      // Database unavailable (e.g. in tests): keep the zero values.
    }
  }

  @override
  Widget build(BuildContext context) {
    final onOpenModule = widget.onOpenModule;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 3 : (width >= 640 ? 2 : 1);
        const gap = 14.0;
        final cardWidth = (width - 32 - gap * (columns - 1)) / columns;
        final halfWidth =
            columns == 1 ? width - 32 : (width - 32 - gap) / 2;

        final stats = <Widget>[
          StatCard(
            label: "Today's Sales",
            value: inr.format(_todaySales),
            icon: Icons.trending_up_rounded,
            color: AppColors.sales,
            onTap: () => onOpenModule('sale'),
          ),
          StatCard(
            label: "Today's Purchases",
            value: inr.format(_todayPurchases),
            icon: Icons.shopping_bag_rounded,
            color: AppColors.purchases,
            onTap: () => onOpenModule('purchase'),
          ),
          StatCard(
            label: 'Total Outstanding',
            value: inr.format(_outstanding),
            icon: Icons.hourglass_bottom_rounded,
            color: AppColors.reports,
            onTap: () => onOpenModule('parties'),
          ),
          StatCard(
            label: 'Cash Balance',
            value: inr.format(_cash),
            icon: Icons.payments_rounded,
            color: AppColors.bankUpi,
            onTap: () => onOpenModule('cashbank'),
          ),
          StatCard(
            label: 'Bank Balance',
            value: inr.format(_bank),
            icon: Icons.account_balance_rounded,
            color: AppColors.suppliers,
            onTap: () => onOpenModule('cashbank'),
          ),
          StatCard(
            label: 'Total Stock Items',
            value: '$_stockItems',
            icon: Icons.inventory_2_rounded,
            color: AppColors.stock,
            onTap: () => onOpenModule('stock'),
          ),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _QuickActions(onOpenModule: onOpenModule),
            const SizedBox(height: 16),
            const ProfitOverviewCard(),
            const SizedBox(height: 16),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final s in stats) SizedBox(width: cardWidth, child: s),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: halfWidth,
                  child: _LowStockCard(products: _lowStock),
                ),
                SizedBox(
                  width: halfWidth,
                  child: _RecentInvoicesCard(invoices: _recent),
                ),
                SizedBox(
                  width: width - 32,
                  child: _EmptyListCard(
                    title: 'Recent Transactions',
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.bankUpi,
                    message: 'No transactions yet.',
                    lines: [
                      for (final t in _txns)
                        '${t.direction == 'in' ? '+' : '-'} ${inr.format(t.amount)}  '
                            '${t.accountName}  ${t.note.isEmpty ? t.kind : t.note}',
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenModule});

  final void Function(String moduleId) onOpenModule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Quick actions',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sales),
            onPressed: () => onOpenModule('sale'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Sale'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.purchases),
            onPressed: () => onOpenModule('purchase'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Purchase'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.white, side: const BorderSide(color: AppColors.cyan)),
            onPressed: () => onOpenModule('help'),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('How to use app'),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.stock),
                const SizedBox(width: 10),
                Text(
                  'Low-Stock Alerts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (products.isEmpty)
              const Text(
                'No low-stock items.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final p in products)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${fmtQty(p.currentStock)} / min ${fmtQty(p.minStock)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              p.isNegative ? AppColors.reports : AppColors.stock,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RecentInvoicesCard extends StatelessWidget {
  const _RecentInvoicesCard({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, color: AppColors.sales),
                const SizedBox(width: 10),
                Text(
                  'Recent Invoices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (invoices.isEmpty)
              const Text(
                'No invoices yet.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final inv in invoices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        inv.number,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inv.partyName.isEmpty ? 'Walk-in' : inv.partyName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                      Text(inr.format(inv.grandTotal)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.message,
    this.lines = const [],
  });

  final List<String> lines;
  final String title;
  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            if (lines.isEmpty)
              Text(message, style: const TextStyle(color: AppColors.textMuted))
            else
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(l, overflow: TextOverflow.ellipsis),
                ),
          ],
        ),
      ),
    );
  }
}
