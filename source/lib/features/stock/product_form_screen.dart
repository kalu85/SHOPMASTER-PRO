import 'package:flutter/material.dart';

import '../../core/data/product_repository.dart';
import '../../core/models/product.dart';
import '../../core/utils/format.dart';
import '../../core/models/party.dart';
import '../invoices/pickers.dart';

const List<int> kGstRates = [0, 5, 12, 18, 28];

/// Add / edit a product or service item.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _hsn = TextEditingController();
  final _barcode = TextEditingController();
  final _purchase = TextEditingController();
  final _sale = TextEditingController();
  final _opening = TextEditingController();
  final _minStock = TextEditingController();
  int _gst = 0;
  bool _service = false;
  bool _saving = false;
  int? _supplierId;
  String _supplierName = '';

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _category.text = p.category;
      _hsn.text = p.hsn;
      _barcode.text = p.barcode ?? '';
      _purchase.text = p.purchaseRate == 0 ? '' : fmtQty(p.purchaseRate);
      _sale.text = p.saleRate == 0 ? '' : fmtQty(p.saleRate);
      _minStock.text = p.minStock == 0 ? '' : fmtQty(p.minStock);
      _gst = kGstRates.contains(p.gstRate) ? p.gstRate : 0;
      _service = p.isService;
      _supplierId = p.supplierId;
      _supplierName = p.supplierName;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _category,
      _hsn,
      _barcode,
      _purchase,
      _sale,
      _opening,
      _minStock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  String? _nonNegative(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d < 0) return 'Enter a valid number';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final barcode = _barcode.text.trim();
    final p = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      category: _category.text.trim(),
      hsn: _hsn.text.trim(),
      barcode: barcode.isEmpty ? null : barcode,
      purchaseRate: _d(_purchase),
      saleRate: _d(_sale),
      gstRate: _gst,
      openingStock: _service ? 0 : _d(_opening),
      currentStock: widget.product?.currentStock ?? (_service ? 0 : _d(_opening)),
      minStock: _service ? 0 : _d(_minStock),
      isService: _service,
      supplierId: _supplierId,
      supplierName: _supplierName,
    );
    try {
      if (_isEdit) {
        await ProductRepository.instance.update(p);
      } else {
        await ProductRepository.instance.insert(p);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DuplicateBarcodeException {
      _fail('This barcode is already used by another item.');
    } catch (e) {
      _fail('Could not save: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _gap() => const SizedBox(height: 14);

  Widget _numberField(
    TextEditingController c,
    String label, {
    String? helper,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _nonNegative,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit item' : 'Add item')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Item name is required'
                      : null,
                ),
                _gap(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Service / non-stock item'),
                  subtitle: const Text('Does not change inventory'),
                  value: _service,
                  onChanged: (v) => setState(() => _service = v),
                ),
                _gap(),
                InkWell(
                  onTap: () async {
                    final ch = await pickParty(context, PartyType.supplier);
                    if (ch == null || !mounted) return;
                    setState(() {
                      _supplierId = ch.party?.id;
                      _supplierName = ch.party?.name ?? '';
                    });
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Supplier name',
                      border: const OutlineInputBorder(),
                      suffixIcon: _supplierName.isEmpty
                          ? const Icon(Icons.arrow_drop_down)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _supplierId = null;
                                _supplierName = '';
                              }),
                            ),
                    ),
                    child: Text(
                      _supplierName.isEmpty
                          ? 'Tap to choose supplier (optional)'
                          : _supplierName,
                      style: TextStyle(
                          color: _supplierName.isEmpty ? Colors.grey : null),
                    ),
                  ),
                ),
                _gap(),
                TextFormField(
                  controller: _category,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                _gap(),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hsn,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'HSN / SAC',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _gst,
                        decoration: const InputDecoration(
                          labelText: 'GST rate',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final r in kGstRates)
                            DropdownMenuItem(value: r, child: Text('$r%')),
                        ],
                        onChanged: (v) => setState(() => _gst = v ?? 0),
                      ),
                    ),
                  ],
                ),
                _gap(),
                TextFormField(
                  controller: _barcode,
                  decoration: const InputDecoration(
                    labelText: 'Barcode',
                    border: OutlineInputBorder(),
                  ),
                ),
                _gap(),
                Row(
                  children: [
                    Expanded(child: _numberField(_purchase, 'Purchase rate (₹)')),
                    const SizedBox(width: 12),
                    Expanded(child: _numberField(_sale, 'Sale rate (₹)')),
                  ],
                ),
                if (!_service) ...[
                  _gap(),
                  if (_isEdit)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD6E6F7)),
                      ),
                      child: Text(
                        'Current stock: ${fmtQty(p!.currentStock)}. '
                        'Use "Adjust stock" in the item menu to change it.',
                      ),
                    )
                  else
                    _numberField(_opening, 'Opening stock'),
                  _gap(),
                  _numberField(
                    _minStock,
                    'Minimum stock alert',
                    helper: 'Alert when stock falls to this level',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
