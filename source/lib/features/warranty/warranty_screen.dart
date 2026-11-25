import 'package:flutter/material.dart';

import '../../core/data/serial_repository.dart';
import '../../core/models/serial.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/serials.dart';
import '../serial/serial_detail_screen.dart';

/// Warranty: sold items with a warranty, grouped Active / Expiring / Expired.
class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key});

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen> {
  final _q = TextEditingController();
  WarrantyFilter _filter = WarrantyFilter.active;
  List<SerialRecord> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await SerialRepository.instance
        .warrantyList(filter: _filter, query: _q.text);
    if (!mounted) return;
    setState(() {
      _rows = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      WarrantyFilter.active: 'Active',
      WarrantyFilter.expiring: 'Expiring (30 days)',
      WarrantyFilter.expired: 'Expired',
      WarrantyFilter.all: 'All',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _q,
            onChanged: (_) => _load(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Serial, item, customer or phone...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final e in labels.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) {
                      _filter = e.key;
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nothing here. Sell an item with a serial number and a warranty period and it will be listed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final st = r.warranty;
                        return Card(
                          child: ListTile(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      SerialDetailScreen(serialId: r.id)));
                              _load();
                            },
                            title: Text(
                              '${r.productName}  •  ${r.serial}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${r.customerName.isEmpty ? 'Walk-in' : r.customerName}'
                              '${r.customerPhone.isEmpty ? '' : '  •  ${r.customerPhone}'}\n'
                              '${warrantyLabel(r.warrantyMonths)}  •  expires ${prettyDate(r.warrantyExpiry!)}',
                            ),
                            isThreeLine: true,
                            trailing: Chip(
                              label: Text(warrantyStateLabel(st)),
                              backgroundColor:
                                  warrantyColor(st).withValues(alpha: 0.18),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
