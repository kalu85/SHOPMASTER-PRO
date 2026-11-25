import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/serial_repository.dart';
import '../../core/models/product.dart';
import '../../core/models/serial.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../invoices/pickers.dart';
import 'serial_detail_screen.dart';

/// Serial Tracking: every serial number with its purchase, sale and
/// warranty history.
class SerialScreen extends StatefulWidget {
  const SerialScreen({super.key});

  @override
  State<SerialScreen> createState() => _SerialScreenState();
}

class _SerialScreenState extends State<SerialScreen> {
  final _q = TextEditingController();
  String? _status;
  List<SerialRecord> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r =
        await SerialRepository.instance.list(status: _status, query: _q.text);
    if (!mounted) return;
    setState(() {
      _rows = r;
      _loading = false;
    });
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) return;
    final lines = <String>[
      [
        'Serial number', 'Product', 'Status', 'Purchase invoice', 'Sale invoice',
        'Customer', 'Customer phone', 'Sold date', 'Warranty months',
        'Warranty start', 'Warranty expiry',
      ].map(_csvCell).join(','),
      for (final r in _rows)
        [
          r.serial, r.productName, r.statusLabel, r.purchaseNumber, r.saleNumber,
          r.customerName, r.customerPhone, r.soldDate, r.warrantyMonths,
          r.warrantyStart, r.warrantyExpiry,
        ].map(_csvCell).join(','),
    ];
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, 'shopmaster_serial_register.csv'));
    await file.writeAsString('\uFEFF${lines.join('\n')}');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SHOPMASTER PRO serial register',
      text: 'Serial register export (${_rows.length} records)',
    );
  }

  Future<void> _add() async {
    final c = TextEditingController();
    Product? product;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add serial number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                decoration: const InputDecoration(
                    labelText: 'Serial number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final ch = await pickProduct(ctx);
                  if (ch != null) setS(() => product = ch.product);
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(product?.name ?? 'Choose item (optional)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Serial numbers bought on a purchase invoice are added automatically. Use this only for stock you already had.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    final serial = c.text.trim();
    c.dispose();
    if (ok != true) return;
    try {
      await SerialRepository.instance.addManual(
        serial: serial,
        productId: product?.id,
        productName: product?.name ?? '',
      );
      await _load();
    } on SerialException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Color _statusColor(String s) => switch (s) {
        'sold' => AppColors.sales,
        'returned' => AppColors.reports,
        _ => AppColors.stock,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.serialTracking,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add serial'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _q,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Serial, item, customer, invoice...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in const {
                  null: 'All',
                  'in_stock': 'In stock',
                  'sold': 'Sold',
                  'returned': 'Returned',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        _status = e.key;
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loading ? 'Loading serials...' : '${_rows.length} serial records (up to 300)',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading || _rows.isEmpty ? null : _exportCsv,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No serial numbers yet. Type serial numbers on a purchase or sales invoice line and they appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          return Card(
                            child: ListTile(
                              onTap: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => SerialDetailScreen(
                                            serialId: r.id)));
                                _load();
                              },
                              title: Text(r.serial,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text([
                                if (r.productName.isNotEmpty) r.productName,
                                if (r.customerName.isNotEmpty) r.customerName,
                                if (r.soldDate != null) prettyDate(r.soldDate!),
                              ].join('  •  ')),
                              trailing: Chip(
                                label: Text(r.statusLabel),
                                backgroundColor:
                                    _statusColor(r.status).withValues(alpha: 0.18),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
