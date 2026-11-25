import 'package:flutter/material.dart';

import '../../core/data/product_repository.dart';
import '../../core/models/product.dart';
import '../../core/utils/format.dart';

const List<String> _reasons = [
  'Stock correction',
  'Damaged / expired',
  'Found extra',
  'Returned',
  'Other',
];

/// Returns true if stock was adjusted.
Future<bool?> showAdjustStockDialog(BuildContext context, Product product) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AdjustStockDialog(product: product),
  );
}

class _AdjustStockDialog extends StatefulWidget {
  const _AdjustStockDialog({required this.product});

  final Product product;

  @override
  State<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<_AdjustStockDialog> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _add = true;
  String _reason = _reasons.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = double.tryParse(_qty.text.trim());
    if (q == null || q <= 0) {
      setState(() => _error = 'Enter a quantity greater than zero');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProductRepository.instance.adjustStock(
        productId: widget.product.id!,
        change: _add ? q : -q,
        reason: _reason,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust stock: ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${fmtQty(widget.product.currentStock)}'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Add'),
                  icon: Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Remove'),
                  icon: Icon(Icons.remove_rounded),
                ),
              ],
              selected: {_add},
              onSelectionChanged: (s) => setState(() => _add = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in _reasons)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reasons.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
