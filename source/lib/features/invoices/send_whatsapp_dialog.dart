import 'package:flutter/material.dart';

import '../../core/data/invoice_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/invoice.dart';
import '../../core/services/contact_service.dart';
import '../../core/utils/format.dart';

/// Asked right after a sale is saved: type or confirm the customer's mobile
/// number, then open WhatsApp with the invoice message ready. WhatsApp never
/// lets an app send silently, so the shop owner always presses Send; the PDF
/// is attached from the PDF screen (Share PDF).
/// Returns the invoice when the person chose "PDF" (the caller opens it).
Future<Invoice?> offerWhatsApp(BuildContext context, Invoice inv) {
  return showDialog<Invoice>(
    context: context,
    builder: (_) => _SendDialog(invoice: inv),
  );
}

class _SendDialog extends StatefulWidget {
  const _SendDialog({required this.invoice});
  final Invoice invoice;

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  late final TextEditingController _phone;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.invoice.partyPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  /// Returns the invoice with the typed number saved on it, or null if the
  /// number is not usable.
  Future<Invoice?> _prepare() async {
    final digits = ContactService.normalisePhone(_phone.text);
    if (digits.length < 12) {
      setState(() => _error = 'Enter the 10-digit mobile number');
      return null;
    }
    final typed = _phone.text.trim();
    if (typed != widget.invoice.partyPhone) {
      await InvoiceRepository.instance
          .setPartyPhone(widget.invoice.id!, typed);
    }
    return (await InvoiceRepository.instance.byId(widget.invoice.id!)) ??
        widget.invoice;
  }

  Future<void> _sendMessage() async {
    final inv = await _prepare();
    if (inv == null) return;
    final shop = await SettingsRepository.instance.load();
    final b = StringBuffer(
        'Hello${inv.partyName.isEmpty ? '' : ' ${inv.partyName}'},\n');
    b.write('Thank you for shopping with ${shop.shopName}.\n');
    b.write(
        '${docTitle(inv.kind, inv.docType)} ${inv.number} dated ${prettyDate(inv.invoiceDate)}: '
        '${inr.format(inv.grandTotal)}.');
    if (inv.docType == DocType.invoice && inv.due > 0) {
      b.write('\nBalance due: ${inr.format(inv.due)}.');
    }
    final ok = await ContactService.whatsApp(inv.partyPhone, b.toString());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Could not open WhatsApp');
    }
  }

  Future<void> _openPdf() async {
    final inv = await _prepare();
    if (inv == null || !mounted) return;
    Navigator.of(context).pop(inv);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send to customer on WhatsApp?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Customer mobile number',
              prefixText: '+91 ',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 10),
          const Text(
            'WhatsApp opens with the message typed in; you press Send. '
            'To send the PDF, use "PDF" and tap Share PDF.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip')),
        OutlinedButton(onPressed: _openPdf, child: const Text('PDF')),
        FilledButton(onPressed: _sendMessage, child: const Text('WhatsApp')),
      ],
    );
  }
}
