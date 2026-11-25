import 'package:flutter/material.dart';

import '../../core/data/invoice_repository.dart';
import '../../core/models/invoice.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/serial.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/utils/format.dart';
import 'invoice_detail_screen.dart';
import 'invoice_form_screen.dart';

/// Sale Counter (green) and Purchase Counter (purple): history plus "New".
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.kind});

  final InvoiceKind kind;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _repo = InvoiceRepository.instance;
  final _search = TextEditingController();
  DocType _doc = DocType.invoice;
  List<Invoice> _items = [];
  bool _loading = true;
  String? _error;

  bool get _isSale => widget.kind == InvoiceKind.sale;
  Color get _color => _isSale ? AppColors.sales : AppColors.purchases;

  List<DocType> get _docTypes => _isSale
      ? const [DocType.invoice, DocType.quotation, DocType.returnNote]
      : const [DocType.invoice, DocType.returnNote];

  String _tabLabel(DocType t) => switch (t) {
        DocType.invoice => 'Invoices',
        DocType.quotation => 'Quotations',
        DocType.returnNote => 'Returns',
      };

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
    try {
      final items = await _repo.list(widget.kind, _doc, query: _search.text);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load: $e';
      });
    }
  }

  Future<void> _new() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceFormScreen(kind: widget.kind, docType: _doc),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _open(Invoice inv) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: inv)),
    );
    if (changed == true) _load();
  }

  /// Edit directly from the history list; the document number is preserved.
  Future<void> _edit(Invoice inv) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceFormScreen(
          kind: inv.kind,
          docType: inv.docType,
          existing: inv,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  /// Delete from history only after confirmation. Repository reverses stock,
  /// serial, party-ledger and cash/bank effects in the same database transaction.
  Future<void> _delete(Invoice inv) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${inv.number}?',
      message: 'This permanently deletes this document and reverses its '
          'stock, serial, party balance and cash/bank effects. '
          'The document number will not be reused.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    try {
      await _repo.delete(inv.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${inv.number}')),
      );
      await _load();
    } on SerialException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete ${inv.number}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _color,
        foregroundColor: AppColors.navy,
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: Text('New ${docTitle(widget.kind, _doc)}'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DocType>(
                    segments: [
                      for (final t in _docTypes)
                        ButtonSegment(value: t, label: Text(_tabLabel(t))),
                    ],
                    selected: {_doc},
                    onSelectionChanged: (s) {
                      setState(() {
                        _doc = s.first;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search number, name or phone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _search.text.isEmpty
                ? 'Nothing here yet. Tap "New ${docTitle(widget.kind, _doc)}".'
                : 'No results for your search.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final inv = _items[i];
        final party = inv.partyName.isEmpty
            ? (_isSale ? 'Walk-in customer' : 'No supplier')
            : inv.partyName;
        final hasDue = inv.docType != DocType.quotation && inv.due > 0;
        return Card(
          child: ListTile(
            onTap: () => _open(inv),
            title: Text(
              inv.number,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '$party  •  ${prettyDate(inv.invoiceDate)}'
              '  •  ${inv.isGst ? 'GST' : 'NON-GST'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      inr.format(inv.grandTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (hasDue)
                      Text(
                        'Due ${inr.format(inv.due)}',
                        style: const TextStyle(
                          color: AppColors.reports,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Invoice actions',
                  onSelected: (action) {
                    if (action == 'edit') _edit(inv);
                    if (action == 'delete') _delete(inv);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
