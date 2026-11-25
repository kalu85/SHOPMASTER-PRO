import 'package:flutter/material.dart';

import 'serial_scanner_screen.dart';

import '../../core/models/product.dart';
import '../../core/utils/format.dart';
import '../../core/utils/serials.dart';
import '../stock/product_form_screen.dart' show kGstRates;

/// One editable row of an invoice that has not been saved yet.
class DraftLine {
  DraftLine({
    this.product,
    required this.name,
    this.hsn = '',
    this.qty = 1,
    required this.rate,
    this.discount = 0,
    this.gstRate = 0,
    this.serials = '',
    this.warrantyMonths = 0,
  });

  final Product? product;
  String name;
  String hsn;
  double qty;
  double rate;

  /// Rupee discount for the whole line.
  double discount;
  int gstRate;

  /// Serial numbers, one per line or comma separated.
  String serials;
  int warrantyMonths;

  DraftLine copy() => DraftLine(
        product: product,
        name: name,
        hsn: hsn,
        qty: qty,
        rate: rate,
        discount: discount,
        gstRate: gstRate,
        serials: serials,
        warrantyMonths: warrantyMonths,
      );
}

Future<DraftLine?> showLineDialog(
  BuildContext context,
  DraftLine line, {
  required bool showGst,
  bool showSerials = false,
  bool showWarranty = false,
  bool showCost = false,
}) {
  return showDialog<DraftLine>(
    context: context,
    builder: (_) => _LineDialog(
      line: line,
      showGst: showGst,
      showSerials: showSerials,
      showWarranty: showWarranty,
      showCost: showCost,
    ),
  );
}

class _LineDialog extends StatefulWidget {
  const _LineDialog({
    required this.line,
    required this.showGst,
    required this.showSerials,
    required this.showWarranty,
    required this.showCost,
  });

  final DraftLine line;
  final bool showGst;
  final bool showSerials;
  final bool showWarranty;

  /// Show the item's buy price (sales screens only).
  final bool showCost;

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  late final TextEditingController _name;
  late final TextEditingController _hsn;
  late final TextEditingController _qty;
  late final TextEditingController _rate;
  late final TextEditingController _discount;
  late final TextEditingController _serials;
  late final TextEditingController _customWarranty;
  late int _gst;
  late int _warranty;
  bool _customW = false;
  String? _error;

  static const List<int> _presets = [0, 3, 6, 12, 24, 36];

  bool get _custom => widget.line.product == null;

  @override
  void initState() {
    super.initState();
    final l = widget.line;
    _name = TextEditingController(text: l.name);
    _hsn = TextEditingController(text: l.hsn);
    _qty = TextEditingController(text: fmtQty(l.qty));
    _rate = TextEditingController(text: l.rate == 0 ? '' : fmtQty(l.rate));
    _discount =
        TextEditingController(text: l.discount == 0 ? '' : fmtQty(l.discount));
    _gst = kGstRates.contains(l.gstRate) ? l.gstRate : 0;
    _serials = TextEditingController(text: l.serials);
    _warranty = l.warrantyMonths;
    _customW = !_presets.contains(_warranty);
    _customWarranty =
        TextEditingController(text: _customW ? '$_warranty' : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _hsn.dispose();
    _qty.dispose();
    _rate.dispose();
    _discount.dispose();
    _serials.dispose();
    _customWarranty.dispose();
    super.dispose();
  }

  Future<void> _scanSerial() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SerialScannerScreen()),
    );
    if (value == null || !mounted) return;
    final current = parseSerials(_serials.text);
    if (!current.contains(value)) current.add(value);
    _serials.text = current.join(', ');
  }

  void _ok() {
    final qty = double.tryParse(_qty.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    final disc = double.tryParse(_discount.text.trim()) ?? 0;
    if (_custom && _name.text.trim().isEmpty) {
      setState(() => _error = 'Enter an item name');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Quantity must be greater than zero');
      return;
    }
    if (rate == null || rate < 0) {
      setState(() => _error = 'Enter a valid rate');
      return;
    }
    if (disc < 0) {
      setState(() => _error = 'Discount cannot be negative');
      return;
    }
    final serialList = parseSerials(_serials.text);
    if (widget.showSerials && serialList.isNotEmpty) {
      if (qty != qty.roundToDouble()) {
        setState(() => _error = 'Quantity must be a whole number for serial items');
        return;
      }
      if (serialList.length != qty.toInt()) {
        setState(() => _error =
            'You entered ${serialList.length} serial number(s) but quantity is ${qty.toInt()}');
        return;
      }
      if (serialList.toSet().length != serialList.length) {
        setState(() => _error = 'The same serial number is typed twice');
        return;
      }
    }
    var months = _warranty;
    if (_customW) {
      months = int.tryParse(_customWarranty.text.trim()) ?? -1;
      if (months < 0 || months > 240) {
        setState(() => _error = 'Warranty must be 0 to 240 months');
        return;
      }
    }
    final out = widget.line.copy()
      ..serials = widget.showSerials ? serialList.join(', ') : ''
      ..warrantyMonths = widget.showWarranty ? months : 0
      ..name = _custom ? _name.text.trim() : widget.line.name
      ..hsn = _hsn.text.trim()
      ..qty = qty
      ..rate = rate
      ..discount = disc
      ..gstRate = _gst;
    Navigator.of(context).pop(out);
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    const numKb = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: Text(_custom ? 'Custom item' : widget.line.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showCost && !_custom) ...[
              Text(
                widget.line.product!.buyPriceLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
            ],
            if (_custom) ...[
              TextField(controller: _name, decoration: _dec('Item name')),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: numKb,
                    decoration: _dec('Qty'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rate,
                    keyboardType: numKb,
                    decoration: _dec('Rate (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discount,
              keyboardType: numKb,
              decoration: _dec('Discount (₹, whole line)'),
            ),
            if (widget.showGst) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _hsn, decoration: _dec('HSN / SAC')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _gst,
                      decoration: _dec('GST rate'),
                      items: [
                        for (final r in kGstRates)
                          DropdownMenuItem(value: r, child: Text('$r%')),
                      ],
                      onChanged: (v) => setState(() => _gst = v ?? 0),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.showSerials) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serials,
                      minLines: 2,
                      maxLines: 5,
                      decoration: _dec('Serial numbers (optional)').copyWith(
                        helperText: 'Type manually or scan a barcode / QR code',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Scan serial number',
                    onPressed: _scanSerial,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ],
              ),
            ],
            if (widget.showWarranty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _customW ? -1 : _warranty,
                decoration: _dec('Warranty'),
                items: [
                  for (final m in _presets)
                    DropdownMenuItem(
                        value: m,
                        child: Text(m == 0 ? 'No warranty' : warrantyLabel(m))),
                  const DropdownMenuItem(value: -1, child: Text('Custom months')),
                ],
                onChanged: (v) => setState(() {
                  if (v == -1) {
                    _customW = true;
                  } else {
                    _customW = false;
                    _warranty = v ?? 0;
                  }
                }),
              ),
              if (_customW) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customWarranty,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Warranty in months'),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('OK')),
      ],
    );
  }
}
