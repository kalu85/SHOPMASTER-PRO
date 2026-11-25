import 'package:flutter/material.dart';

import '../../core/data/account_repository.dart';
import '../../core/models/account.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/confirm_dialog.dart';

/// Cash & Bank: balances, bank accounts, transfers and money history.
class CashBankScreen extends StatefulWidget {
  const CashBankScreen({super.key});

  @override
  State<CashBankScreen> createState() => _CashBankScreenState();
}

class _CashBankScreenState extends State<CashBankScreen> {
  List<Account> _accounts = [];
  List<AccountTxn> _txns = [];
  int? _filterId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AccountRepository.instance.accounts();
    final t = await AccountRepository.instance.txns(accountId: _filterId);
    if (!mounted) return;
    setState(() {
      _accounts = a;
      _txns = t;
      _loading = false;
    });
  }

  double _sum(bool cash) => _accounts
      .where((a) => a.isCash == cash)
      .fold<double>(0, (s, a) => s + a.balance);

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, border: const OutlineInputBorder());

  Future<void> _addBank() async {
    final name = TextEditingController();
    final bank = TextEditingController();
    final no = TextEditingController();
    final ifsc = TextEditingController();
    final upi = TextEditingController();
    final open = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add bank account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: _dec('Name (e.g. SBI Current)')),
              const SizedBox(height: 10),
              TextField(controller: bank, decoration: _dec('Bank name')),
              const SizedBox(height: 10),
              TextField(
                  controller: no,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Account number')),
              const SizedBox(height: 10),
              TextField(controller: ifsc, decoration: _dec('IFSC')),
              const SizedBox(height: 10),
              TextField(controller: upi, decoration: _dec('UPI ID')),
              const SizedBox(height: 10),
              TextField(
                  controller: open,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Opening balance (₹)')),
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
    );
    final a = Account(
      kind: 'bank',
      name: name.text.trim(),
      bankName: bank.text.trim(),
      accountNo: no.text.trim(),
      ifsc: ifsc.text.trim().toUpperCase(),
      upiId: upi.text.trim(),
      openingBalance: double.tryParse(open.text.trim()) ?? 0,
    );
    for (final c in [name, bank, no, ifsc, upi, open]) {
      c.dispose();
    }
    if (ok != true) return;
    if (a.name.isEmpty) {
      _msg('Enter a name for the account');
      return;
    }
    await AccountRepository.instance.addBank(a);
    await _load();
  }

  /// [mode]: 'transfer', 'deposit' (cash to bank), 'withdraw' (bank to cash)
  Future<void> _move(String mode) async {
    final cash = _accounts.where((a) => a.isCash).toList();
    final banks = _accounts.where((a) => !a.isCash).toList();
    if (mode != 'transfer' && (cash.isEmpty || banks.isEmpty)) {
      _msg('Add a bank account first');
      return;
    }
    if (mode == 'transfer' && _accounts.length < 2) {
      _msg('You need two accounts to transfer');
      return;
    }
    int? from = mode == 'deposit'
        ? cash.first.id
        : mode == 'withdraw'
            ? banks.first.id
            : _accounts.first.id;
    int? to = mode == 'deposit'
        ? banks.first.id
        : mode == 'withdraw'
            ? cash.first.id
            : _accounts[1].id;
    final amount = TextEditingController();
    final note = TextEditingController();
    final title = switch (mode) {
      'deposit' => 'Deposit cash in bank',
      'withdraw' => 'Withdraw cash from bank',
      _ => 'Transfer between accounts',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          List<Account> choices(bool fromSide) {
            if (mode == 'deposit') return fromSide ? cash : banks;
            if (mode == 'withdraw') return fromSide ? banks : cash;
            return _accounts;
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: from,
                    decoration: _dec('From'),
                    items: [
                      for (final a in choices(true))
                        DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${inr.format(a.balance)})')),
                    ],
                    onChanged: (v) => setS(() => from = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: to,
                    decoration: _dec('To'),
                    items: [
                      for (final a in choices(false))
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (v) => setS(() => to = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('Amount (₹)')),
                  const SizedBox(height: 10),
                  TextField(controller: note, decoration: _dec('Note (optional)')),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Move money')),
            ],
          );
        },
      ),
    );
    final amt = double.tryParse(amount.text.trim());
    final n = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok != true) return;
    if (amt == null || amt <= 0) {
      _msg('Enter an amount greater than zero');
      return;
    }
    if (from == null || to == null || from == to) {
      _msg('Choose two different accounts');
      return;
    }
    await AccountRepository.instance.transfer(
      fromId: from!,
      toId: to!,
      amount: amt,
      kind: mode == 'transfer' ? 'transfer' : mode,
      date: isoDateFmt.format(DateTime.now()),
      note: n,
    );
    await _load();
  }

  Future<void> _manual() async {
    int? acc = _accounts.isEmpty ? null : _accounts.first.id;
    bool isIn = true;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add money in / out'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Money in')),
                    ButtonSegment(value: false, label: Text('Money out')),
                  ],
                  selected: {isIn},
                  onSelectionChanged: (s) => setS(() => isIn = s.first),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: acc,
                  decoration: _dec('Account'),
                  items: [
                    for (final a in _accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setS(() => acc = v),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount (₹)')),
                const SizedBox(height: 10),
                TextField(controller: note, decoration: _dec('Note')),
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
    await AccountRepository.instance.addManualTxn(
      accountId: acc!,
      isIn: isIn,
      amount: amt,
      date: isoDateFmt.format(DateTime.now()),
      note: n,
    );
    await _load();
  }

  Future<void> _deleteBank(Account a) async {
    final sure = await confirmDialog(context,
        title: 'Delete ${a.name}?',
        message: 'Only accounts with no transactions can be deleted.',
        confirmLabel: 'Delete');
    if (!sure) return;
    final done = await AccountRepository.instance.deleteBank(a.id!);
    if (!done) _msg('This account has transactions, so it cannot be deleted');
    if (_filterId == a.id) _filterId = null;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _balanceCard('Cash in hand', _sum(true), AppColors.stock)),
                  const SizedBox(width: 12),
                  Expanded(child: _balanceCard('In banks', _sum(false), AppColors.bankUpi)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                      onPressed: _addBank,
                      icon: const Icon(Icons.account_balance_rounded),
                      label: const Text('Add bank')),
                  OutlinedButton.icon(
                      onPressed: () => _move('deposit'),
                      icon: const Icon(Icons.south_west_rounded),
                      label: const Text('Deposit cash')),
                  OutlinedButton.icon(
                      onPressed: () => _move('withdraw'),
                      icon: const Icon(Icons.north_east_rounded),
                      label: const Text('Withdraw cash')),
                  OutlinedButton.icon(
                      onPressed: () => _move('transfer'),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Transfer')),
                  OutlinedButton.icon(
                      onPressed: _manual,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Money in / out')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
              for (final a in _accounts)
                Card(
                  color: _filterId == a.id ? AppColors.lightBlue : null,
                  child: ListTile(
                    onTap: () {
                      _filterId = _filterId == a.id ? null : a.id;
                      _load();
                    },
                    leading: Icon(
                      a.isCash
                          ? Icons.payments_rounded
                          : Icons.account_balance_rounded,
                      color: a.isCash ? AppColors.stock : AppColors.bankUpi,
                    ),
                    title: Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (a.bankName.isNotEmpty) a.bankName,
                      if (a.accountNo.isNotEmpty) 'A/c ${a.accountNo}',
                      if (a.upiId.isNotEmpty) a.upiId,
                    ].join('  •  ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(inr.format(a.balance),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: a.balance < 0 ? AppColors.reports : null)),
                        if (!a.isCash)
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _deleteBank(a),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _filterId == null ? 'All money history' : 'History (tap the account again to see all)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_txns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No transactions yet.',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              for (final t in _txns)
                Card(
                  child: ListTile(
                    leading: Icon(
                      t.isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: t.isIn ? AppColors.sales : AppColors.reports,
                    ),
                    title: Text(
                      '${t.kind[0].toUpperCase()}${t.kind.substring(1)}'
                      '${t.ref.isEmpty ? '' : '  •  ${t.ref}'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                        '${t.accountName}  •  ${prettyDate(t.date)}${t.note.isEmpty ? '' : '\n${t.note}'}'),
                    isThreeLine: t.note.isNotEmpty,
                    trailing: Text(
                      '${t.isIn ? '+' : '-'}${inr.format(t.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.isIn ? AppColors.sales : AppColors.reports,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceCard(String label, double v, Color c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text(inr.format(v),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: c)),
            ],
          ),
        ),
      );
}
