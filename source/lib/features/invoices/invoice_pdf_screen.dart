import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/data/invoice_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/invoice.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// PDF preview of one document (A4 or 80mm) with print, share, WhatsApp
/// and email. Nothing is sent automatically: the share sheet / chat opens
/// and the person taps send.
class InvoicePdfScreen extends StatefulWidget {
  const InvoicePdfScreen({super.key, required this.invoice, this.autoShareOnOpen = false});

  final Invoice invoice;
  final bool autoShareOnOpen;

  @override
  State<InvoicePdfScreen> createState() => _InvoicePdfScreenState();
}

class _InvoicePdfScreenState extends State<InvoicePdfScreen> {
  bool _thermal = false;
  ShopSettings? _shop;
  List<InvoiceItem>? _items;
  String? _error;
  Uint8List? _bytes;
  bool _autoShareStarted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = await SettingsRepository.instance.load();
      final items = await InvoiceRepository.instance.items(widget.invoice.id!);
      _shop = shop;
      _items = items;
      await _render();
      if (widget.autoShareOnOpen && mounted && !_autoShareStarted) {
        _autoShareStarted = true;
        await _share();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _render() async {
    final bytes = await PdfService.invoice(
      widget.invoice,
      _items!,
      _shop!,
      thermal: _thermal,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  String get _fileName =>
      '${widget.invoice.number}${_thermal ? '_80mm' : ''}.pdf';

  String get _message {
    final inv = widget.invoice;
    final who = inv.partyName.isEmpty ? '' : ' ${inv.partyName}';
    final b = StringBuffer('Hello$who,\n');
    b.write(
        '${docTitle(inv.kind, inv.docType)} ${inv.number} dated ${prettyDate(inv.invoiceDate)} '
        'for ${inr.format(inv.grandTotal)}.');
    if (inv.docType == DocType.invoice && inv.due > 0) {
      b.write('\nBalance due: ${inr.format(inv.due)}.');
    }
    b.write('\n${_shop?.shopName ?? ''}');
    return b.toString();
  }

  Future<void> _share() async {
    if (_bytes == null) return;
    await Printing.sharePdf(
      bytes: _bytes!,
      filename: _fileName,
      subject: '${widget.invoice.number} from ${_shop?.shopName ?? ''}',
      body: _message,
    );
  }

  Future<void> _print() async {
    if (_bytes == null) return;
    final data = _bytes!;
    await Printing.layoutPdf(
      name: _fileName,
      onLayout: (_) async => data,
    );
  }

  /// Opens WhatsApp with the message typed in. The PDF is attached by the
  /// person from "Share PDF" (WhatsApp cannot be given a file by link).
  Future<void> _whatsApp() async {
    final ok =
        await ContactService.whatsApp(widget.invoice.partyPhone, _message);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _email() async {
    final ok = await ContactService.email(
      '',
      '${widget.invoice.number} from ${_shop?.shopName ?? ''}',
      _message,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email app found')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.invoice.number} PDF')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('A4'),
                    icon: Icon(Icons.description_outlined)),
                ButtonSegment(
                    value: true,
                    label: Text('80mm receipt'),
                    icon: Icon(Icons.receipt_long_outlined)),
              ],
              selected: {_thermal},
              onSelectionChanged: (s) async {
                setState(() {
                  _thermal = s.first;
                  _bytes = null;
                });
                if (_items != null) await _render();
              },
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text('Could not create the PDF: $_error'))
                : !ready
                    ? const Center(child: CircularProgressIndicator())
                    : PdfPreview(
                        key: ValueKey('${widget.invoice.id}$_thermal'),
                        build: (_) async => _bytes!,
                        useActions: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        pdfFileName: _fileName,
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: ready ? _print : null,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue),
                    onPressed: ready ? _share : null,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: ready ? _whatsApp : null,
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp chat'),
                  ),
                  OutlinedButton.icon(
                    onPressed: ready ? _email : null,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
