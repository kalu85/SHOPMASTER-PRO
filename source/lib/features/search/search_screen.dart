import 'package:flutter/material.dart';

import '../../core/data/invoice_repository.dart';
import '../../core/data/party_repository.dart';
import '../../core/data/search_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../invoices/invoice_detail_screen.dart';
import '../parties/party_ledger_screen.dart';
import '../serial/serial_detail_screen.dart';

/// Global search across items, parties, invoices, serials, warranty and
/// payments, with category and date filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onOpenModule});

  /// Used to jump to a module (e.g. 'stock', 'cashbank').
  final void Function(String moduleId)? onOpenModule;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  SearchType? _only;
  DateTimeRange? _range;
  List<SearchHit> _hits = [];
  bool _busy = false;
  bool _searched = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() {
        _hits = [];
        _searched = false;
      });
      return;
    }
    setState(() => _busy = true);
    final r = _range;
    final hits = await SearchRepository.instance.search(
      q,
      only: _only,
      from: r == null ? null : isoDateFmt.format(r.start),
      to: r == null ? null : isoDateFmt.format(r.end),
    );
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _busy = false;
      _searched = true;
    });
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      _run();
    }
  }

  IconData _icon(SearchType t) => switch (t) {
        SearchType.product => Icons.inventory_2_rounded,
        SearchType.customer => Icons.person_rounded,
        SearchType.supplier => Icons.local_shipping_rounded,
        SearchType.sale => Icons.receipt_long_rounded,
        SearchType.purchase => Icons.shopping_cart_rounded,
        SearchType.serial => Icons.qr_code_2_rounded,
        SearchType.warranty => Icons.verified_user_rounded,
        SearchType.payment => Icons.account_balance_wallet_rounded,
      };

  Future<void> _open(SearchHit h) async {
    final nav = Navigator.of(context);
    switch (h.type) {
      case SearchType.sale:
      case SearchType.purchase:
        final inv = await InvoiceRepository.instance.byId(h.id);
        if (inv != null) {
          await nav.push(MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoice: inv)));
        }
      case SearchType.customer:
      case SearchType.supplier:
        final p = await PartyRepository.instance.byId(h.id);
        if (p != null) {
          await nav.push(
              MaterialPageRoute(builder: (_) => PartyLedgerScreen(party: p)));
        }
      case SearchType.serial:
      case SearchType.warranty:
        await nav.push(MaterialPageRoute(
            builder: (_) => SerialDetailScreen(serialId: h.id)));
      case SearchType.product:
        widget.onOpenModule?.call('stock');
      case SearchType.payment:
        widget.onOpenModule?.call('cashbank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _q,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _run(),
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Name, phone, invoice no., serial, HSN, barcode...',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _q.clear();
                        _run();
                      },
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _only == null,
                  onSelected: (_) {
                    _only = null;
                    _run();
                  },
                ),
              ),
              for (final t in SearchType.values)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    label: Text(searchTypeLabel(t)),
                    selected: _only == t,
                    onSelected: (_) {
                      _only = t;
                      _run();
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(_range == null
                    ? 'Any date'
                    : '${dateFmt.format(_range!.start)} - ${dateFmt.format(_range!.end)}'),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _range = null;
                    _run();
                  },
                ),
            ],
          ),
        ),
        if (_range != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Items and parties have no date, so they are hidden while a date filter is on.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        Expanded(
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : !_searched
                  ? const Center(
                      child: Text('Type to search everything.',
                          style: TextStyle(color: AppColors.textMuted)))
                  : _hits.isEmpty
                      ? const Center(
                          child: Text('Nothing found.',
                              style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _hits.length,
                          itemBuilder: (_, i) {
                            final h = _hits[i];
                            return Card(
                              child: ListTile(
                                onTap: () => _open(h),
                                leading: Icon(_icon(h.type),
                                    color: AppColors.blue),
                                title: Text(h.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    '${searchTypeLabel(h.type)}  •  ${h.subtitle}'),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
