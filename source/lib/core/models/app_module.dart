import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One entry in the main navigation (the 15 modules from the brief).
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.phase,
    required this.summary,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;

  /// Build phase in which this module gets implemented.
  final int phase;
  final String summary;
}

const List<AppModule> appModules = [
  AppModule(
    id: 'overview',
    title: 'Overview',
    icon: Icons.dashboard_rounded,
    color: AppColors.cyan,
    phase: 1,
    summary: 'Business snapshot and quick actions.',
  ),
  AppModule(
    id: 'sale',
    title: 'Sale Counter',
    icon: Icons.point_of_sale_rounded,
    color: AppColors.sales,
    phase: 3,
    summary: 'GST / NON-GST invoices, quotations, returns, payments.',
  ),
  AppModule(
    id: 'purchase',
    title: 'Purchase Counter',
    icon: Icons.shopping_cart_checkout_rounded,
    color: AppColors.purchases,
    phase: 3,
    summary: 'Purchase invoices, returns, supplier payments.',
  ),
  AppModule(
    id: 'parties',
    title: 'Party Details',
    icon: Icons.groups_rounded,
    color: AppColors.customers,
    phase: 2,
    summary: 'Customers and suppliers with ledgers.',
  ),
  AppModule(
    id: 'stock',
    title: 'Items & Stock',
    icon: Icons.inventory_2_rounded,
    color: AppColors.stock,
    phase: 2,
    summary: 'Products, stock levels, adjustments and history.',
  ),
  AppModule(
    id: 'cashbank',
    title: 'Cash & Bank',
    icon: Icons.account_balance_rounded,
    color: AppColors.bankUpi,
    phase: 7,
    summary: 'Cash, bank accounts, UPI, transfers.',
  ),
  AppModule(
    id: 'expenses',
    title: 'Expenses',
    icon: Icons.receipt_long_rounded,
    color: AppColors.expenses,
    phase: 7,
    summary: 'Expense entries, categories and reports.',
  ),
  AppModule(
    id: 'reports',
    title: 'Reports',
    icon: Icons.bar_chart_rounded,
    color: AppColors.reports,
    phase: 8,
    summary: 'Sales, GST, stock, profit and loss, outstanding.',
  ),
  AppModule(
    id: 'warranty',
    title: 'Warranty',
    icon: Icons.verified_user_rounded,
    color: AppColors.warranty,
    phase: 6,
    summary: 'Warranty periods, expiry alerts and claims.',
  ),
  AppModule(
    id: 'serial',
    title: 'Serial Tracking',
    icon: Icons.qr_code_2_rounded,
    color: AppColors.serialTracking,
    phase: 6,
    summary: 'Trace every serial number end to end.',
  ),
  AppModule(
    id: 'whatsapp',
    title: 'WhatsApp Connect',
    icon: Icons.chat_rounded,
    color: AppColors.sales,
    phase: 10,
    summary: 'Share invoices, statements and reminders.',
  ),
  AppModule(
    id: 'gmail',
    title: 'Gmail Integration',
    icon: Icons.mail_rounded,
    color: AppColors.reports,
    phase: 10,
    summary: 'Send invoice PDFs by email via Google OAuth.',
  ),
  AppModule(
    id: 'backup',
    title: 'Backup & Restore',
    icon: Icons.cloud_sync_rounded,
    color: AppColors.blue,
    phase: 9,
    summary: 'Local and cloud backup, restore, sync status.',
  ),
  AppModule(
    id: 'settings',
    title: 'Shop Settings',
    icon: Icons.settings_rounded,
    color: AppColors.neutral,
    phase: 5,
    summary: 'Shop profile, invoice design, numbering, GST settings.',
  ),
  AppModule(
    id: 'search',
    title: 'Global Search',
    icon: Icons.search_rounded,
    color: AppColors.cyan,
    phase: 8,
    summary: 'Search products, parties, invoices, serials and more.',
  ),
];
