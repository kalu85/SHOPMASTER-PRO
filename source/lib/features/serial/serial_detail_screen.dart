import 'package:flutter/material.dart';

import '../../core/data/serial_repository.dart';
import '../../core/models/serial.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/serials.dart';
import '../invoices/invoice_detail_screen.dart';
import '../../core/data/invoice_repository.dart';

Color warrantyColor(WarrantyState s) => switch (s) {
      WarrantyState.active => AppColors.sales,
      WarrantyState.expiring => AppColors.stock,
      WarrantyState.expired => AppColors.reports,
      WarrantyState.none => AppColors.neutral,
    };

String warrantyStateLabel(WarrantyState s) => switch (s) {
      WarrantyState.active => 'Active',
      WarrantyState.expiring => 'Expiring soon',
      WarrantyState.expired => 'Expired',
      WarrantyState.none => 'No warranty',
    };

/// One serial number: where it was bought, who it was sold to, warranty
/// dates (shown here only, never on the invoice) and warranty claims.
class SerialDetailScreen extends StatefulWidget {
  const SerialDetailScreen({super.key, required this.serialId});

  final int serialId;

  @override
  State<SerialDetailScreen> createState() => _SerialDetailScreenState();
}

class _SerialDetailScreenState extends State<SerialDetailScreen> {
  SerialRecord? _rec;
  List<WarrantyClaim> _claims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await SerialRepository.instance.byId(widget.serialId);
    final c = r == null
        ? <WarrantyClaim>[]
        : await SerialRepository.instance.claims(r.id);
    if (!mounted) return;
    setState(() {
      _rec = r;
      _claims = c;
      _loading = false;
    });
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 130,
                child: Text(k,
                    style: const TextStyle(color: AppColors.textMuted))),
            Expanded(
                child: Text(v.isEmpty ? '-' : v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Future<void> _openInvoice(int? id) async {
    if (id == null) return;
    final inv = await InvoiceRepository.instance.byId(id);
    if (inv == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoice: inv)));
  }

  Future<void> _addClaim() async {
    final c = TextEditingController();
    final issue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New warranty claim'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'What is the problem?', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (issue == null || issue.isEmpty) return;
    await SerialRepository.instance.addClaim(
      serialId: widget.serialId,
      date: isoDateFmt.format(DateTime.now()),
      issue: issue,
    );
    await _load();
  }

  Future<void> _closeClaim(WarrantyClaim claim) async {
    final c = TextEditingController(text: claim.resolution);
    String status = 'resolved';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Update claim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setS(() => status = v ?? 'open'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Resolution / note',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final note = c.text.trim();
    c.dispose();
    if (ok != true) return;
    await SerialRepository.instance.updateClaim(claim.id, status, note);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _rec;
    return Scaffold(
      appBar: AppBar(title: Text(r?.serial ?? 'Serial number')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? const Center(child: Text('This serial number no longer exists'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _kv('Serial', r.serial),
                                _kv('Item', r.productName),
                                _kv('Status', r.statusLabel),
                                _kv('Bought on', r.purchaseNumber),
                                _kv('Sold on', r.saleNumber),
                                _kv('Customer', r.customerName),
                                _kv('Phone', r.customerPhone),
                                _kv('Sold date',
                                    r.soldDate == null ? '' : prettyDate(r.soldDate!)),
                              ],
                            ),
                          ),
                        ),
                        if (r.warrantyExpiry != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Warranty',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      const Spacer(),
                                      Chip(
                                        label: Text(warrantyStateLabel(r.warranty)),
                                        backgroundColor: warrantyColor(r.warranty)
                                            .withValues(alpha: 0.18),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  _kv('Duration', warrantyLabel(r.warrantyMonths)),
                                  _kv('Starts',
                                      r.warrantyStart == null ? '' : prettyDate(r.warrantyStart!)),
                                  _kv('Expires', prettyDate(r.warrantyExpiry!)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (r.purchaseInvoiceId != null)
                              OutlinedButton(
                                  onPressed: () => _openInvoice(r.purchaseInvoiceId),
                                  child: const Text('Open purchase bill')),
                            if (r.saleInvoiceId != null)
                              OutlinedButton(
                                  onPressed: () => _openInvoice(r.saleInvoiceId),
                                  child: const Text('Open sales invoice')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Warranty claims',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (r.status == 'sold')
                              FilledButton.icon(
                                onPressed: _addClaim,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New claim'),
                              ),
                          ],
                        ),
                        if (_claims.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No claims.',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        for (final c in _claims)
                          Card(
                            child: ListTile(
                              onTap: () => _closeClaim(c),
                              title: Text(c.issue),
                              subtitle: Text(
                                  '${prettyDate(c.date)}  •  ${c.status.toUpperCase()}${c.resolution.isEmpty ? '' : '\n${c.resolution}'}'),
                              isThreeLine: c.resolution.isNotEmpty,
                              trailing: const Icon(Icons.edit_outlined),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
