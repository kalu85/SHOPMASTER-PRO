import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/data/invoice_attachment_repository.dart';

import '../../core/data/invoice_repository.dart';
import '../../core/models/invoice.dart';
import '../../core/models/serial.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'invoice_form_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/serials.dart';
import 'invoice_pdf_screen.dart';

/// Read-only view of a saved document with PDF, print and share.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key, required this.invoice});

  final Invoice invoice;

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => InvoiceFormScreen(
          kind: invoice.kind, docType: invoice.docType, existing: invoice),
    ));
    if (saved == true && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${invoice.number}?',
      message: 'This removes the document and puts stock, serial numbers, '
          'the party balance and the cash/bank balance back as they were '
          'before it. The number will not be reused. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await InvoiceRepository.instance.delete(invoice.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Deleted ${invoice.number}')));
      Navigator.of(context).pop(true);
    } on SerialException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Widget _row(String label, double value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(inr.format(value), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final isSale = inv.kind == InvoiceKind.sale;
    final accent = isSale ? AppColors.sales : AppColors.purchases;
    final isQuotation = inv.docType == DocType.quotation;
    final party = inv.partyName.isEmpty
        ? (isSale ? 'Walk-in customer' : 'No supplier')
        : inv.partyName;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.number),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _edit(context),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(context),
          ),
          IconButton(
            tooltip: 'PDF / Print / Share',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InvoicePdfScreen(invoice: inv))),
          ),
        ],
      ),
      body: Align(
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
                      Row(
                        children: [
                          Text(
                            docTitle(inv.kind, inv.docType),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(inv.isGst ? 'GST' : 'NON-GST'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        prettyDate(inv.invoiceDate),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const Divider(height: 24),
                      Text(
                        party,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (inv.partyPhone.isNotEmpty) Text(inv.partyPhone),
                      if (inv.partyAddress.isNotEmpty) Text(inv.partyAddress),
                      if (inv.isGst && inv.partyGstin.isNotEmpty)
                        Text('GSTIN: ${inv.partyGstin}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<InvoiceItem>>(
                future: InvoiceRepository.instance.items(inv.id!),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text('Could not load items: ${snap.error}');
                  }
                  final items = snap.data ?? [];
                  return Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Card(
                          child: ListTile(
                            leading: Text('${i + 1}'),
                            title: Text(
                              items[i].name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                '${fmtQty(items[i].qty)} × ${inr.format(items[i].rate)}',
                                if (items[i].discount > 0)
                                  'Disc ${inr.format(items[i].discount)}',
                                if (inv.isGst) 'GST ${items[i].gstRate}%',
                                if (inv.isGst && items[i].hsn.isNotEmpty)
                                  'HSN ${items[i].hsn}',
                                if (items[i].serials.isNotEmpty)
                                  'Serial ${items[i].serials}',
                                if (items[i].warrantyMonths > 0)
                                  'Warranty ${warrantyLabel(items[i].warrantyMonths)}',
                              ].join('  •  '),
                            ),
                            trailing: Text(
                              inr.format(items[i].amount),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Subtotal', inv.subtotal),
                      if (inv.discountTotal > 0)
                        _row('Discount', -inv.discountTotal),
                      if (inv.isGst) ...[
                        _row('Taxable amount', inv.taxableTotal),
                        if (inv.isInterstate)
                          _row('IGST', inv.igst)
                        else ...[
                          _row('CGST', inv.cgst),
                          _row('SGST', inv.sgst),
                        ],
                        _row('Total GST', inv.totalGst),
                      ],
                      const Divider(),
                      _row('Grand total', inv.grandTotal, bold: true),
                      if (!isQuotation) ...[
                        const SizedBox(height: 6),
                        _row(
                          inv.docType == DocType.returnNote
                              ? 'Refunded'
                              : (isSale ? 'Received' : 'Paid'),
                          inv.paid,
                        ),
                        _row(
                          'Due amount',
                          inv.due,
                          bold: true,
                          color: inv.due > 0 ? AppColors.reports : null,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Payment mode: ${inv.payMode}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (inv.kind == InvoiceKind.purchase && inv.docType == DocType.invoice) ...[
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, Object?>>>(
                  future: InvoiceAttachmentRepository.instance.list(inv.id!),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
                    final files = snap.data ?? [];
                    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Supplier bill attachments', style: TextStyle(fontWeight: FontWeight.w700)),
                        if (files.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No bill files attached')),
                        for (final file in files)
                          ListTile(contentPadding: EdgeInsets.zero,
                            leading: Icon((file['file_name'] as String).toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image),
                            title: Text(file['file_name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(tooltip: 'Share attachment', icon: const Icon(Icons.share_rounded),
                              onPressed: () async {
                                final path = file['file_path'] as String;
                                await Share.shareXFiles([XFile(path)], text: file['file_name'] as String);
                              }),
                          ),
                      ],
                    )));
                  },
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InvoicePdfScreen(invoice: inv))),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF  •  Print  •  Share'),
              ),
              if (inv.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Notes: ${inv.notes}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
