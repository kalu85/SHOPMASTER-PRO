import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/account_repository.dart';
import '../../core/models/account.dart';
import '../../core/models/invoice.dart' show kPayModes;
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/confirm_dialog.dart';

/// Expenses: record shop costs. Each one also reduces the chosen
/// cash/bank account.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _rows = [];
  List<Account> _accounts = [];
  DateTimeRange? _range;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
        start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day));
    _load();
  }

  Future<void> _load() async {
    final r = _range!;
    final rows = await AccountRepository.instance
        .expenses(from: isoDateFmt.format(r.start), to: isoDateFmt.format(r.end));
    final accs = await AccountRepository.instance.accounts();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _accounts = accs;
      _loading = false;
    });
  }

  double get _total => _rows.fold<double>(0, (s, e) => s + e.amount);

  String _csvCell(Object? value) {
    var text = value?.toString() ?? '';
    // Prevent spreadsheet formula execution from user-entered notes/categories.
    if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no expenses to export in this date range.')),
      );
      return;
    }
    try {
      final accountNames = {
        for (final account in _accounts)
          if (account.id != null) account.id!: account.name,
      };
      final lines = <String>[
        ['Date', 'Category', 'Amount (INR)', 'Payment mode', 'Account', 'Notes']
            .map(_csvCell)
            .join(','),
        for (final expense in _rows)
          [
            expense.date,
            expense.category,
            expense.amount.toStringAsFixed(2),
            expense.payMode,
            accountNames[expense.accountId] ?? 'Account unavailable',
            expense.notes,
          ].map(_csvCell).join(','),
      ];
      lines.add('');
      lines.add(['Total expenses', _total.toStringAsFixed(2)].map(_csvCell).join(','));
      final directory = await getTemporaryDirectory();
      final filename =
          'expenses_${isoDateFmt.format(_range!.start)}_to_${isoDateFmt.format(_range!.end)}.csv';
      final file = File(p.join(directory.path, filename));
      await file.writeAsString('${lines.join('\r\n')}\r\n', flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Shop expenses',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export expenses: $error')),
      );
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      _load();
    }
  }

  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, border: const OutlineInputBorder());

  Future<void> _add() async {
    String category = kExpenseCategories.first;
    String mode = 'Cash';
    int? acc = _accounts.isEmpty ? null : _accounts.first.id;
    DateTime date = DateTime.now();
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: _dec('Category'),
                  items: [
                    for (final c in kExpenseCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setS(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount (₹)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: _dec('Paid by'),
                  items: [
                    for (final m in kPayModes.where((m) => m != 'Credit'))
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setS(() {
                    mode = v ?? 'Cash';
                    final cash = _accounts.where((a) => a.isCash).toList();
                    final banks = _accounts.where((a) => !a.isCash).toList();
                    if (mode == 'Cash' && cash.isNotEmpty) acc = cash.first.id;
                    if (mode != 'Cash' && banks.isNotEmpty) acc = banks.first.id;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey('acc$acc'),
                  initialValue: acc,
                  decoration: _dec('Money goes out of'),
                  items: [
                    for (final a in _accounts)
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an amount greater than zero')));
      return;
    }
    await AccountRepository.instance.addExpense(
      category: category,
      date: isoDateFmt.format(date),
      amount: amt,
      accountId: acc!,
      payMode: mode,
      notes: n,
    );
    await _load();
  }

  Future<void> _edit(Expense expense) async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a cash or bank account before editing this expense.')),
      );
      return;
    }
    String category = kExpenseCategories.contains(expense.category)
        ? expense.category
        : kExpenseCategories.last;
    String mode = kPayModes.contains(expense.payMode) &&
            expense.payMode != 'Credit'
        ? expense.payMode
        : 'Cash';
    int? acc = _accounts.any((a) => a.id == expense.accountId)
        ? expense.accountId
        : _accounts.first.id;
    DateTime date = DateTime.tryParse(expense.date) ?? DateTime.now();
    final amount = TextEditingController(text: expense.amount.toString());
    final note = TextEditingController(text: expense.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: _dec('Category'),
                  items: [
                    for (final c in kExpenseCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setS(() => category = v ?? category),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Amount (₹)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: _dec('Paid by'),
                  items: [
                    for (final m in kPayModes.where((m) => m != 'Credit'))
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setS(() {
                    mode = v ?? mode;
                    final cash = _accounts.where((a) => a.isCash).toList();
                    final banks = _accounts.where((a) => !a.isCash).toList();
                    if (mode == 'Cash' && cash.isNotEmpty) acc = cash.first.id;
                    if (mode != 'Cash' && banks.isNotEmpty) acc = banks.first.id;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey('edit-expense-acc-$acc'),
                  initialValue: acc,
                  decoration: _dec('Money goes out of'),
                  items: [
                    for (final a in _accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setS(() => acc = v),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setS(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(dateFmt.format(date)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: _dec('Note (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    final amt = double.tryParse(amount.text.trim());
    final n = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok != true) return;
    if (amt == null || !amt.isFinite || amt <= 0 || acc == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }
    try {
      await AccountRepository.instance.updateExpense(
        id: expense.id,
        category: category,
        date: isoDateFmt.format(date),
        amount: amt,
        accountId: acc!,
        payMode: mode,
        notes: n,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update expense: $error')),
      );
    }
  }

  Future<void> _delete(Expense e) async {
    final sure = await confirmDialog(context,
        title: 'Delete this expense?',
        message:
            '${e.category} ${inr.format(e.amount)} will be removed and the money goes back to the account.',
        confirmLabel: 'Delete');
    if (!sure) return;
    await AccountRepository.instance.deleteExpense(e.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _range!;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.expenses,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                              '${dateFmt.format(r.start)} - ${dateFmt.format(r.end)}'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Export expenses as CSV',
                        onPressed: _rows.isEmpty ? null : _exportCsv,
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                      const SizedBox(width: 8),
                      Text(inr.format(_total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(
                          child: Text('No expenses in this period.',
                              style: TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: _rows.length,
                          itemBuilder: (_, i) {
                            final e = _rows[i];
                            return Card(
                              child: ListTile(
                                title: Text(e.category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    '${prettyDate(e.date)}  •  ${e.payMode}${e.notes.isEmpty ? '' : '\n${e.notes}'}'),
                                isThreeLine: e.notes.isNotEmpty,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(inr.format(e.amount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    IconButton(
                                      tooltip: 'Edit expense',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _edit(e),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      onPressed: () => _delete(e),
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
    );
  }
}
