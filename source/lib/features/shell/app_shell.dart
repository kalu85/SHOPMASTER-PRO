import 'package:flutter/material.dart';

import '../../core/models/app_module.dart';
import '../../core/theme/app_colors.dart';
import '../dashboard/dashboard_screen.dart';
import '../help/shop_guide_screen.dart';
import '../../core/models/invoice.dart' show InvoiceKind;
import '../invoices/invoices_screen.dart';
import '../parties/parties_screen.dart';
import '../backup/backup_screen.dart';
import '../cashbank/cash_bank_screen.dart';
import '../connect/gmail_screen.dart';
import '../connect/whatsapp_screen.dart';
import '../expenses/expenses_screen.dart';
import '../placeholder/module_placeholder_screen.dart';
import '../reports/reports_screen.dart';
import '../search/search_screen.dart';
import '../serial/serial_screen.dart';
import '../settings/shop_settings_screen.dart';
import '../stock/stock_screen.dart';
import '../warranty/warranty_screen.dart';

/// Responsive shell: permanent sidebar on wide screens (Windows),
/// drawer on narrow screens (Android phones).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _wideBreakpoint = 900;
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  void _openById(String id) {
    final i = appModules.indexWhere((m) => m.id == id);
    if (i >= 0) _select(i);
  }

  Widget _body() {
    final module = appModules[_index];
    if (module.id == 'overview') {
      return DashboardScreen(onOpenModule: _openById);
    }
    if (module.id == 'sale') {
      return const InvoicesScreen(
          key: ValueKey('sale'), kind: InvoiceKind.sale);
    }
    if (module.id == 'purchase') {
      return const InvoicesScreen(
          key: ValueKey('purchase'), kind: InvoiceKind.purchase);
    }
    if (module.id == 'stock') return const StockScreen();
    if (module.id == 'parties') return const PartiesScreen();
    switch (module.id) {
      case 'cashbank':
        return const CashBankScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'reports':
        return const ReportsScreen();
      case 'warranty':
        return const WarrantyScreen();
      case 'serial':
        return const SerialScreen();
      case 'whatsapp':
        return const WhatsAppScreen();
      case 'gmail':
        return const GmailScreen();
      case 'backup':
        return const BackupScreen();
      case 'settings':
        return const ShopSettingsScreen();
      case 'search':
        return SearchScreen(onOpenModule: _openById);
      case 'help':
        return ShopGuideScreen(onOpenModule: _openById);
    }
    return ModulePlaceholderScreen(module: module);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final module = appModules[_index];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(selectedIndex: _index, onSelected: _select),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: module.title,
                    onSearchTap: () => _openById('search'),
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SHOPMASTER PRO',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Global Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _openById('search'),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: _Sidebar(
          selectedIndex: _index,
          width: double.infinity,
          onSelected: (i) {
            Navigator.of(context).pop();
            _select(i);
          },
        ),
      ),
      body: _body(),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onSearchTap});

  final String title;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.navy,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 320,
            child: TextField(
              readOnly: true,
              onTap: onSearchTap,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Search products, parties, invoices...',
                hintStyle: const TextStyle(color: AppColors.neutral),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.cyan),
                filled: true,
                fillColor: AppColors.navyLight,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navyBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navyBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelected,
    this.width = 260,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.cyan,
                          size: 30),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SHOPMASTER PRO',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: appModules.length,
                itemBuilder: (context, i) {
                  final m = appModules[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color: selected
                          ? m.color.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onSelected(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              Icon(m.icon, color: m.color, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  m.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.white
                                        : const Color(0xFFCBD5E1),
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
  }
}
