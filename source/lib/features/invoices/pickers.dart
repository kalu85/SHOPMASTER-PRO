import 'package:flutter/material.dart';

import '../../core/data/party_repository.dart';
import '../../core/data/product_repository.dart';
import '../../core/models/party.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Result of the party picker. [party] null means walk-in (no party).
class PartyChoice {
  const PartyChoice(this.party);
  final Party? party;
}

/// Result of the item picker. [product] null means a custom item.
class ProductChoice {
  const ProductChoice(this.product);
  final Product? product;
}

Future<PartyChoice?> pickParty(BuildContext context, PartyType type) {
  return showModalBottomSheet<PartyChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PartySheet(type: type),
  );
}

Future<ProductChoice?> pickProduct(BuildContext context,
    {bool forPurchase = false}) {
  return showModalBottomSheet<ProductChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductSheet(forPurchase: forPurchase),
  );
}

class _PartySheet extends StatefulWidget {
  const _PartySheet({required this.type});

  final PartyType type;

  @override
  State<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends State<_PartySheet> {
  final _search = TextEditingController();
  List<Party> _items = [];
  bool _loading = true;

  bool get _isCustomer => widget.type == PartyType.customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items =
        await PartyRepository.instance.list(widget.type, query: _search.text);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final noun = _isCustomer ? 'customer' : 'supplier';
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search $noun',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_off_rounded),
              title: Text(_isCustomer ? 'Walk-in customer' : 'No supplier'),
              subtitle: const Text('No party, no due amount'),
              onTap: () => Navigator.of(context).pop(const PartyChoice(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            'No ${noun}s found. Add one in Party Details.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final p = _items[i];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                [
                                  if (p.phone.isNotEmpty) p.phone,
                                  if (p.gstin.isNotEmpty) p.gstin,
                                ].join('  •  '),
                              ),
                              onTap: () =>
                                  Navigator.of(context).pop(PartyChoice(p)),
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

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({this.forPurchase = false});

  /// Show the purchase rate instead of the sale rate.
  final bool forPurchase;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  final _search = TextEditingController();
  List<Product> _items = [];
  Map<int, String> _suppliers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await ProductRepository.instance.list(query: _search.text);
    final sup = await ProductRepository.instance.lastSuppliers();
    if (!mounted) return;
    setState(() {
      _suppliers = sup;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: const InputDecoration(
                  hintText: 'Search name, HSN or barcode',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Custom item'),
              subtitle: Text(widget.forPurchase
                  ? 'New item: added to Items & Stock with this purchase'
                  : 'Type a name and price (no stock change)'),
              onTap: () => Navigator.of(context).pop(const ProductChoice(null)),
            ),
            const Divider(height: 1),
            // Match the desktop-style product picker: show both rates and stock
            // together so the operator can compare them before selecting.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: const [
                  Expanded(
                    flex: 5,
                    child: Text('ITEM',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('SALE PRICE',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text('PURCHASE PRICE',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text('STOCK',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text(
                            'No items found. Add items in Items & Stock.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 12, endIndent: 12),
                          itemBuilder: (context, i) {
                            final p = _items[i];
                            final supplier =
                                _suppliers[p.id] ?? p.supplierName;
                            return InkWell(
                              onTap: () => Navigator.of(context)
                                  .pop(ProductChoice(p)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              p.isService
                                                  ? 'Service'
                                                  : 'GST ${p.gstRate}%',
                                              if (supplier.isNotEmpty)
                                                supplier,
                                            ].join('  •  '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        inr.format(p.saleRate),
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        inr.format(p.purchaseRate),
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.purchases,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 42,
                                      child: Text(
                                        p.isService
                                            ? '—'
                                            : fmtQty(p.currentStock),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: p.currentStock <= 0
                                              ? Colors.red
                                              : (p.currentStock <= p.minStock
                                                  ? Colors.orange.shade800
                                                  : Colors.green.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
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
