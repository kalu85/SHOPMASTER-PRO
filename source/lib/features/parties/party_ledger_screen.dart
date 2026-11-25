import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/data/account_repository.dart';
import '../../core/data/party_repository.dart';
import '../../core/data/report_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/account.dart';
import '../../core/models/invoice.dart' show kPayModes;
import '../../core/models/party.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Ledger of one customer or supplier: invoices, returns, payments and the
/// running balance. Money received/paid is recorded here.
class PartyLedgerScreen extends StatefulWidget {
  const PartyLedgerScreen({super.key, required this.party});

  final Party party;

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  late Party _party = widget.party;
  List<LedgerEntry> _entries = [];
  bool _loading = true;

  bool get _isCustomer => _party.type == PartyType.customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fresh = await PartyRepository.instance.byId(widget.party.id!);
    final p = fresh ?? _party;
    final e = await PartyRepository.instance.ledger(p);
    if (!mounted) return;
    setState(() {
      _party = p;
      _entries = e;
      _loading = false;
    });
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _recordPayment() async {
    final accounts = await AccountRepository.instance.accounts();
    if (!mounted) return;
    String mode = 'Cash';
    int? acc = accounts.isEmpty ? null : accounts.first.id;
    DateTime date = DateTime.now();
    final amount = TextEditingController(
        text: _party.currentBalance > 0 ? fmtQty(_party.currentBalance) : '');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(_isCustomer ? 'Receive payment' : 'Make payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                      labelText: 'Payment mode', border: OutlineInputBorder()),
                  items: [
                    for (final m in kPayModes.where((m) => m != 'Credit'))
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setS(() {
                    mode = v ?? 'Cash';
                    final cash = accounts.where((a) => a.isCash).toList();
                    final banks = accounts.where((a) => !a.isCash).toList();
                    if (mode == 'Cash' && cash.isNotEmpty) acc = cash.first.id;
                    if (mode != 'Cash' && banks.isNotEmpty) acc = banks.first.id;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey('acc$acc'),
                  initialValue: acc,
                  decoration: InputDecoration(
                      labelText: _isCustomer ? 'Money goes into' : 'Money comes from',
                      border: const OutlineInputBorder()),
                  items: [
                    for (final Account a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setS(() => acc = v),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setS(() => date = d);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(dateFmt.format(date)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                      labelText: 'Note (optional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final amt = double.tryParse(amount.text.trim());
    final n = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok != true) return;
    if (amt == null || amt <= 0 || acc == null) {
      _msg('Enter an amount greater than zero');
      return;
    }
    await PartyRepository.instance.recordPayment(
      partyId: _party.id!,
      amount: amt,
      accountId: acc!,
      payMode: mode,
      date: isoDateFmt.format(date),
      note: n,
    );
    await _load();
  }

  Future<void> _reminder() async {
    if (_party.phone.trim().isEmpty) {
      _msg('Add a mobile number to this customer before preparing a reminder.');
      return;
    }
    final shop = await SettingsRepository.instance.load();
    final invoices =
        await PartyRepository.instance.outstandingInvoices(_party.id!);
    final details = invoices.map((row) {
      final number = row['number'] as String? ?? '';
      final date = prettyDate(row['invoice_date'] as String? ?? '');
      final due = (row['due'] as num?)?.toDouble() ?? 0;
      return '- $number ($date): ${inr.format(due)}';
    }).join('\\n');
    final msg = StringBuffer()
      ..write('Hello ${_party.name}, this is a friendly payment reminder from ${shop.shopName}.\\n')
      ..write('Your current account balance is ${inr.format(_party.currentBalance)}.');
    if (details.isNotEmpty) {
      msg
        ..write('\\n\\nUnpaid invoices:')
        ..write('\\n$details');
    }
    msg
      ..write('\\n\\nPlease contact us if you have already paid or need a statement. Thank you!');
    final ok = await ContactService.whatsApp(_party.phone, msg.toString());
    if (!ok && mounted) _msg('Could not open WhatsApp');
  }

  ReportData _statement() {
    var running = _party.openingBalance;
    final rows = <List<String>>[
      ['', 'Opening balance', '', money(running)],
    ];
    for (final e in _entries) {
      running += e.change;
      rows.add([
        prettyDate(e.date),
        e.description,
        '${e.change >= 0 ? '+' : '-'}${money(e.change.abs())}',
        money(running),
      ]);
    }
    return ReportData(
      title:
          '${_isCustomer ? 'Customer' : 'Supplier'} statement: ${_party.name}',
      columns: const ['Date', 'Details', 'Change', 'Balance'],
      rows: rows,
      summary: [
        _isCustomer
            ? 'Amount to receive: ${money(_party.currentBalance)}'
            : 'Amount to pay: ${money(_party.currentBalance)}',
      ],
    );
  }

  Future<void> _statementPdf() async {
    try {
      final shop = await SettingsRepository.instance.load();
      final bytes = await PdfService.report(_statement(), shop);
      await Printing.sharePdf(
          bytes: bytes,
          filename: 'statement_${_party.name.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      _msg('Could not create statement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _party;
    final color = _isCustomer ? AppColors.customers : AppColors.suppliers;
    // Running balances are worked out up front: list rows are built lazily.
    final balances = <double>[];
    var running = p.openingBalance;
    for (final e in _entries) {
      running += e.change;
      balances.add(running);
    }
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isCustomer ? 'To receive' : 'To pay',
                                style: const TextStyle(
                                    color: AppColors.textMuted)),
                            Text(inr.format(p.currentBalance),
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: color)),
                            if (p.phone.isNotEmpty) Text(p.phone),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _recordPayment,
                          icon: const Icon(Icons.payments_rounded),
                          label:
                              Text(_isCustomer ? 'Receive payment' : 'Make payment'),
                        ),
                        if (_isCustomer)
                          OutlinedButton.icon(
                            onPressed: p.currentBalance > 0 ? _reminder : null,
                            icon: const Icon(Icons.chat_rounded),
                            label: const Text('WhatsApp reminder'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _statementPdf,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Statement PDF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Ledger', style: Theme.of(context).textTheme.titleMedium),
                    Card(
                      child: ListTile(
                        title: const Text('Opening balance'),
                        trailing: Text(inr.format(p.openingBalance),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    for (var i = 0; i < _entries.length; i++)
                      Builder(builder: (_) {
                        final e = _entries[i];
                        final up = e.change >= 0;
                        return Card(
                          child: ListTile(
                            title: Text(e.description,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                                '${prettyDate(e.date)}  •  Balance ${inr.format(balances[i])}'),
                            trailing: Text(
                              '${up ? '+' : '-'}${inr.format(e.change.abs())}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: up ? AppColors.reports : AppColors.sales,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
