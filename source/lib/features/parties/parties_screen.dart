import 'package:flutter/material.dart';

import '../../core/data/party_repository.dart';
import '../../core/models/party.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'party_form_screen.dart';
import 'party_ledger_screen.dart';

/// Party Details: customers and suppliers in two tabs.
class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: AppColors.white,
            child: const TabBar(
              labelColor: AppColors.textDark,
              indicatorColor: AppColors.customers,
              tabs: [
                Tab(icon: Icon(Icons.person_rounded), text: 'Customers'),
                Tab(icon: Icon(Icons.local_shipping_rounded), text: 'Suppliers'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PartyList(type: PartyType.customer),
                PartyList(type: PartyType.supplier),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PartyList extends StatefulWidget {
  const PartyList({super.key, required this.type});

  final PartyType type;

  @override
  State<PartyList> createState() => _PartyListState();
}

class _PartyListState extends State<PartyList> {
  final _repo = PartyRepository.instance;
  final _search = TextEditingController();
  List<Party> _items = [];
  bool _loading = true;
  String? _error;

  bool get _isCustomer => widget.type == PartyType.customer;
  Color get _color => _isCustomer ? AppColors.customers : AppColors.suppliers;
  String get _noun => _isCustomer ? 'customer' : 'supplier';

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
      final items = await _repo.list(widget.type, query: _search.text);
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
        _error = 'Could not load ${_noun}s: $e';
      });
    }
  }

  Future<void> _openForm([Party? party]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PartyFormScreen(type: widget.type, party: party),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openLedger(Party p) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PartyLedgerScreen(party: p)));
    _load();
  }

  Future<void> _delete(Party p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete $_noun?',
      message: '"${p.name}" will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _repo.delete(p.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _color,
        foregroundColor: AppColors.navy,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add $_noun'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, email or GSTIN',
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
                ? 'No ${_noun}s yet. Tap "Add $_noun" to create one.'
                : 'No ${_noun}s match your search.',
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
        final p = _items[i];
        final sub = <String>[
          if (p.phone.isNotEmpty) p.phone,
          if (p.gstin.isNotEmpty) p.gstin,
        ].join('  •  ');
        final hasBalance = p.currentBalance != 0;
        return Card(
          child: ListTile(
            onTap: () => _openLedger(p),
            leading: CircleAvatar(
              backgroundColor: _color.withValues(alpha: 0.18),
              child: Text(
                p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                style: TextStyle(color: _color, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: sub.isEmpty ? null : Text(sub),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasBalance)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr.format(p.currentBalance),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _isCustomer ? 'To receive' : 'To pay',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'ledger':
                        _openLedger(p);
                      case 'edit':
                        _openForm(p);
                      case 'delete':
                        _delete(p);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'ledger', child: Text('Ledger and payments')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
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
