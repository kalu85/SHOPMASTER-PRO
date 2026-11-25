import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../core/data/invoice_attachment_repository.dart';

import '../../core/data/account_repository.dart';
import '../../core/data/invoice_repository.dart';
import '../../core/data/party_repository.dart';
import '../../core/data/product_repository.dart';
import '../../core/data/serial_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/account.dart';
import '../../core/models/serial.dart';
import '../../core/utils/serials.dart';
import '../../core/models/invoice.dart';
import '../../core/models/product.dart';
import '../../core/models/party.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/gst_calculator.dart';
import 'line_dialog.dart';
import 'pickers.dart';
import 'invoice_pdf_screen.dart';
import 'send_whatsapp_dialog.dart';
import 'serial_scanner_screen.dart';

/// Create a sales/purchase invoice, quotation or return.
class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({
    super.key,
    required this.kind,
    required this.docType,
    this.existing,
  });

  final InvoiceKind kind;
  final DocType docType;

  /// When set, the screen edits this saved document instead of creating one.
  final Invoice? existing;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final List<DraftLine> _lines = [];
  final _paid = TextEditingController();
  final _notes = TextEditingController();
  Party? _party;
  bool _isGst = true;
  bool _interstate = false;
  DateTime _date = DateTime.now();
  String _mode = 'Cash';
  bool _saving = false;
  List<Account> _accounts = [];
  int? _accountId;
  final List<PlatformFile> _purchaseBillFiles = [];

  bool get _isSale => widget.kind == InvoiceKind.sale;
  bool get _isQuotation => widget.docType == DocType.quotation;
  bool get _isReturn => widget.docType == DocType.returnNote;
  bool get _isPurchaseInvoice =>
      !_isSale && widget.docType == DocType.invoice;

  /// Serial numbers are not tracked on quotations.
  bool get _serialsAllowed => !_isQuotation;
  Color get _color => _isSale ? AppColors.sales : AppColors.purchases;
  PartyType get _partyType =>
      _isSale ? PartyType.customer : PartyType.supplier;
  String get _partyNoun => _isSale ? 'customer' : 'supplier';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _loadExisting(widget.existing!);
    } else {
      _loadDefaults();
    }
  }

  bool get _editing => widget.existing != null;

  Future<void> _loadExisting(Invoice inv) async {
    try {
      final accs = await AccountRepository.instance.accounts();
      final items = await InvoiceRepository.instance.items(inv.id!);
      Party? party;
      if (inv.partyId != null) {
        party = await PartyRepository.instance.byId(inv.partyId!);
      }
      final lines = <DraftLine>[];
      for (final it in items) {
        final prod = it.productId == null
            ? null
            : await ProductRepository.instance.byId(it.productId!);
        lines.add(DraftLine(
          product: prod,
          name: it.name,
          hsn: it.hsn,
          qty: it.qty,
          rate: it.rate,
          discount: it.discount,
          gstRate: it.gstRate,
          serials: it.serials,
          warrantyMonths: it.warrantyMonths,
          batchNumber: it.batchNumber,
          expiryDate: it.expiryDate == null ? null : DateTime.tryParse(it.expiryDate!),
        ));
      }
      if (!mounted) return;
      setState(() {
        _accounts = accs;
        _party = party;
        _isGst = inv.isGst;
        _interstate = inv.isInterstate;
        _date = DateTime.tryParse(inv.invoiceDate) ?? DateTime.now();
        _mode = inv.payMode == 'Credit' ? 'Cash' : inv.payMode;
        _accountId = inv.accountId ?? _defaultAccountFor(_mode);
        _paid.text = inv.paid == 0 ? '' : fmtQty(inv.paid);
        _notes.text = inv.notes;
        _lines
          ..clear()
          ..addAll(lines);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open for editing: $e')));
    }
  }

  Future<void> _loadDefaults() async {
    try {
      final shop = await SettingsRepository.instance.load();
      final accs = await AccountRepository.instance.accounts();
      if (!mounted) return;
      setState(() {
        _isGst = shop.defaultGst;
        _mode = kPayModes.contains(shop.defaultPayMode) &&
                shop.defaultPayMode != 'Credit'
            ? shop.defaultPayMode
            : 'Cash';
        _accounts = accs;
        _accountId = _defaultAccountFor(_mode);
      });
    } catch (_) {
      // Defaults are a convenience only.
    }
  }

  /// Cash goes to the cash drawer; UPI/Bank/Card go to the first bank
  /// account if there is one.
  int? _defaultAccountFor(String mode) {
    if (_accounts.isEmpty) return null;
    final cash = _accounts.where((a) => a.isCash).toList();
    final banks = _accounts.where((a) => !a.isCash).toList();
    if (mode == 'Cash' || banks.isEmpty) {
      return (cash.isNotEmpty ? cash.first : _accounts.first).id;
    }
    return banks.first.id;
  }

  @override
  void dispose() {
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  InvoiceTotals get _totals => GstCalculator.totals(
        [
          for (final l in _lines)
            LineInput(
              qty: l.qty,
              rate: l.rate,
              discount: l.discount,
              gstRate: l.gstRate,
            ),
        ],
        isGst: _isGst,
        isInterstate: _isGst && _interstate,
      );

  double get _paidValue => double.tryParse(_paid.text.trim()) ?? 0;

  Future<void> _pickParty() async {
    final choice = await pickParty(context, _partyType);
    if (choice == null || !mounted) return;
    setState(() => _party = choice.party);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _date = d);
  }

  Future<void> _addItem() async {
    final choice = await pickProduct(context, forPurchase: !_isSale);
    if (choice == null || !mounted) return;
    final p = choice.product;
    if (p == null) {
      final line = await showLineDialog(
        context,
        DraftLine(name: '', rate: 0),
        showGst: _isGst,
        showSerials: _serialsAllowed,
        showWarranty: _isSale && _serialsAllowed,
        showExpiry: _isPurchaseInvoice,
      );
      if (line != null && mounted) setState(() => _lines.add(line));
      return;
    }
    final existing = _lines.indexWhere((l) => l.product?.id == p.id);
    if (existing >= 0) {
      setState(() => _lines[existing].qty += 1);
      return;
    }
    setState(() {
      _lines.add(DraftLine(
        product: p,
        name: p.name,
        hsn: p.hsn,
        rate: _isSale ? p.saleRate : p.purchaseRate,
        gstRate: p.gstRate,
      ));
    });
  }

  Future<void> _scanSaleItem() async {
    if (!_isSale || widget.docType != DocType.invoice) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SerialScannerScreen()),
    );
    if (code == null || !mounted || code.trim().isEmpty) return;
    final value = code.trim();
    try {
      final serialRows = await SerialRepository.instance.list(query: value);
      SerialRecord? serial;
      for (final row in serialRows) {
        if (row.serial.toLowerCase() == value.toLowerCase()) { serial = row; break; }
      }
      Product? product;
      if (serial != null) {
        if (serial.status == 'sold') throw SerialException('This serial is already sold: ' + serial.saleNumber);
        if (serial.status == 'returned') throw SerialException('This serial was returned to the supplier');
        if (_lines.any((line) => parseSerials(line.serials).any((s) => s.toLowerCase() == value.toLowerCase()))) {
          throw SerialException('This serial is already in this invoice');
        }
        if (serial.productId != null) product = await ProductRepository.instance.byId(serial.productId!);
        if (product == null && serial.productName.isNotEmpty) {
          final matches = await ProductRepository.instance.list(query: serial.productName);
          for (final item in matches) {
            if (item.name.toLowerCase() == serial.productName.toLowerCase()) { product = item; break; }
          }
        }
        if (product == null) throw SerialException('No product is linked to this serial');
        final selected = product;
        final index = _lines.indexWhere((line) => line.product?.id == selected.id);
        setState(() {
          if (index >= 0) {
            _lines[index].qty += 1;
            _lines[index].serials = [_lines[index].serials, value].where((s) => s.trim().isNotEmpty).join(', ');
          } else {
            _lines.add(DraftLine(product: selected, name: selected.name, hsn: selected.hsn, qty: 1, rate: selected.saleRate, gstRate: selected.gstRate, serials: value));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ' + selected.name + ' with serial ' + value)));
        return;
      }
      final products = await ProductRepository.instance.list(query: value);
      for (final item in products) {
        if (item.barcode?.toLowerCase() == value.toLowerCase()) { product = item; break; }
      }
      if (product == null) throw SerialException('No product barcode or registered serial matches: ' + value);
      final selected = product;
      final index = _lines.indexWhere((line) => line.product?.id == selected.id);
      setState(() {
        if (index >= 0) {
          _lines[index].qty += 1;
        } else {
          _lines.add(DraftLine(product: selected, name: selected.name, hsn: selected.hsn, qty: 1, rate: selected.saleRate, gstRate: selected.gstRate));
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ' + selected.name)));
    } on SerialException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add scanned item: ' + error.toString())));
    }
  }

  Future<void> _editLine(int i) async {
    final edited = await showLineDialog(
      context,
      _lines[i],
      showGst: _isGst,
      showSerials: _serialsAllowed,
      showWarranty: _isSale && _serialsAllowed,
      showCost: _isSale,
      showExpiry: _isPurchaseInvoice,
    );
    if (edited != null && mounted) setState(() => _lines[i] = edited);
  }

  String? _validate(InvoiceTotals t) {
    if (_lines.isEmpty) return 'Add at least one item';
    if (t.grandTotal <= 0) return 'The total must be greater than zero';
    final seenSerials = <String>{};
    for (final l in _lines) {
      final serials = parseSerials(l.serials);
      for (final serial in serials) {
        final key = serial.toLowerCase();
        if (!seenSerials.add(key)) {
          return 'Serial "$serial" appears more than once in this invoice';
        }
      }
      final n = serials.length;
      if (n > 0 && n != l.qty.round()) {
        return '${l.name}: ${l.qty.round()} item(s) but $n serial number(s)';
      }
    }
    if (!_isQuotation) {
      final paid = _paidValue;
      if (paid < 0) return 'Amount cannot be negative';
      if (paid > t.grandTotal) return 'Amount cannot be more than the total';
      final due = round2(t.grandTotal - paid);
      if (due > 0 && _party == null) {
        return 'Select a $_partyNoun to keep a due amount, or enter the full amount';
      }
    }
    return null;
  }

  Future<void> _takePurchaseBillPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera, imageQuality: 88, maxWidth: 2200,
    );
    if (photo == null || !mounted) return;
    final file = PlatformFile(
      name: path.basename(photo.path), size: await photo.length(), path: photo.path,
    );
    if (mounted) setState(() => _purchaseBillFiles.add(file));
  }

  Future<void> _pickPurchaseBills() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true, type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: false,
    );
    if (result != null && mounted) {
      setState(() => _purchaseBillFiles.addAll(result.files));
    }
  }

  Future<bool> _confirmStockShortages() async {
    if (!_isSale || widget.docType != DocType.invoice || _editing) return true;
    final requiredByProduct = <int, double>{};
    final productById = <int, Product>{};
    for (final line in _lines) {
      final product = line.product;
      if (product == null || product.isService || product.id == null) continue;
      final id = product.id!;
      requiredByProduct[id] = (requiredByProduct[id] ?? 0) + line.qty;
      productById[id] = product;
    }
    final shortages = <String>[];
    for (final entry in requiredByProduct.entries) {
      final product = productById[entry.key]!;
      if (entry.value > product.currentStock) {
        shortages.add('${product.name}: need ${fmtQty(entry.value)}, available ${fmtQty(product.currentStock)}');
      }
    }
    if (shortages.isEmpty) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insufficient stock'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This sale will make the following stock quantities negative:'),
              const SizedBox(height: 10),
              for (final shortage in shortages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $shortage'),
                ),
              const SizedBox(height: 4),
              const Text('Do you want to save this sale anyway?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Review items')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save anyway')),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _save() async {
    final t = _totals;
    final error = _validate(t);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!await _confirmStockShortages() || !mounted) return;
    setState(() => _saving = true);
    final paid = _isQuotation ? 0.0 : _paidValue;
    final party = _party;
    final invoice = Invoice(
      kind: widget.kind,
      docType: widget.docType,
      partyId: party?.id,
      partyName: party?.name ?? '',
      partyPhone: party?.phone ?? '',
      partyAddress: party?.address ?? '',
      partyGstin: party?.gstin ?? '',
      isGst: _isGst,
      isInterstate: _isGst && _interstate,
      invoiceDate: isoDateFmt.format(_date),
      subtotal: t.subtotal,
      discountTotal: t.discountTotal,
      taxableTotal: t.taxable,
      cgst: t.cgst,
      sgst: t.sgst,
      igst: t.igst,
      grandTotal: t.grandTotal,
      paid: paid,
      payMode: paid == 0 ? 'Credit' : _mode,
      accountId: paid == 0 ? null : _accountId,
      notes: _notes.text.trim(),
    );
    // A purchased item that is not in Items & Stock yet is added there, so the
    // purchase always raises stock.
    final newIds = <int, int>{};
    if (_isPurchaseInvoice) {
      try {
        for (var i = 0; i < _lines.length; i++) {
          final l = _lines[i];
          if (l.product != null) continue;
          final found = await ProductRepository.instance.list(query: l.name);
          final same = found
              .where((p) => p.name.toLowerCase() == l.name.toLowerCase())
              .toList();
          if (same.isNotEmpty) {
            newIds[i] = same.first.id!;
          } else {
            newIds[i] = await ProductRepository.instance.insert(Product(
              name: l.name,
              hsn: l.hsn,
              purchaseRate: l.rate,
              gstRate: l.gstRate,
              supplierId: _party?.id,
              supplierName: _party?.name ?? '',
            ));
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add the new item to stock: $e')));
        return;
      }
    }
    final items = <InvoiceItem>[
      for (var i = 0; i < _lines.length; i++)
        InvoiceItem(
          productId: _lines[i].product?.id ?? newIds[i],
          name: _lines[i].name,
          hsn: _lines[i].hsn,
          qty: _lines[i].qty,
          rate: _lines[i].rate,
          discount: t.lines[i].discount,
          gstRate: _isGst ? _lines[i].gstRate : 0,
          taxable: t.lines[i].taxable,
          cgst: t.lines[i].cgst,
          sgst: t.lines[i].sgst,
          igst: t.lines[i].igst,
          amount: t.lines[i].amount,
          serials: _lines[i].serials,
          warrantyMonths: _isSale ? _lines[i].warrantyMonths : 0,
          purchaseRateSnapshot: _lines[i].product?.purchaseRate ??
              (_isPurchaseInvoice ? _lines[i].rate : 0),
          batchNumber: _isPurchaseInvoice ? _lines[i].batchNumber : '',
          expiryDate: _isPurchaseInvoice && _lines[i].expiryDate != null
              ? isoDateFmt.format(_lines[i].expiryDate!)
              : null,
        ),
    ];
    try {
      final String number;
      if (_editing) {
        await InvoiceRepository.instance
            .update(widget.existing!.id!, invoice, items);
        number = widget.existing!.number;
      } else {
        number = await InvoiceRepository.instance.create(invoice, items);
      }
      final savedInvoice = _editing
          ? widget.existing!
          : await InvoiceRepository.instance.byNumber(widget.kind, widget.docType, number);
      if (savedInvoice?.id != null && _purchaseBillFiles.isNotEmpty) {
        await InvoiceAttachmentRepository.instance.addFiles(savedInvoice!.id!, _purchaseBillFiles);
        _purchaseBillFiles.clear();
      }
      if (!mounted) return;
      var msg = _editing ? 'Updated $number' : 'Saved $number';
      if (_isQuotation) {
        msg += ' (quotation: stock not changed)';
      } else {
        final parts = <String>[];
        for (final it in items) {
          if (it.productId == null) continue;
          final pr = await ProductRepository.instance.byId(it.productId!);
          if (pr != null && !pr.isService && parts.length < 3) {
            parts.add('${pr.name} stock ${fmtQty(pr.currentStock)}');
          }
        }
        if (parts.isNotEmpty) msg += '. ${parts.join(', ')}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
      final nav = Navigator.of(context);
      Invoice? openPdf;
      if (!_editing && _isSale) {
        final saved = await InvoiceRepository.instance
            .byNumber(widget.kind, widget.docType, number);
        if (saved != null && mounted) {
          openPdf = await offerWhatsApp(context, saved);
        }
      }
      if (!mounted) return;
      nav.pop(true);
      if (openPdf != null) {
        final inv = openPdf;
        nav.push(MaterialPageRoute(builder: (_) => InvoicePdfScreen(invoice: inv, autoShareOnOpen: true)));
      }
    } on SerialException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Serial number problem: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(inr.format(value), style: style),
        ],
      ),
    );
  }

  Widget _lineTile(int i, LineResult r) {
    final l = _lines[i];
    final p = l.product;
    final goesNegative = _isSale &&
        widget.docType == DocType.invoice &&
        p != null &&
        !p.isService &&
        l.qty > p.currentStock;
    final sub = StringBuffer('${fmtQty(l.qty)} × ${inr.format(l.rate)}');
    if (r.discount > 0) sub.write('  •  Disc ${inr.format(r.discount)}');
    if (_isGst) sub.write('  •  GST ${l.gstRate}%');
    if (!_isQuotation && !_editing) {
      if (p == null && _isPurchaseInvoice) {
        sub.write('\nNew item: will be added to stock');
      } else if (p != null && p.isService) {
        sub.write('\nService: stock not tracked');
      } else if (p != null) {
        final dir = InvoiceRepository.stockDirection(widget.kind, widget.docType);
        sub.write(
            '\nStock ${fmtQty(p.currentStock)} → ${fmtQty(p.currentStock + dir * l.qty)}');
      }
    }
    final sn = parseSerials(l.serials);
    if (sn.isNotEmpty) sub.write('\nSerial: ${sn.join(', ')}');
    if (_isSale && l.warrantyMonths > 0) {
      sub.write('\nWarranty: ${warrantyLabel(l.warrantyMonths)}');
    }
    return Card(
      child: ListTile(
        onTap: () => _editLine(i),
        title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sub.toString()),
            if (goesNegative)
              Text(
                'Stock will go negative: ${fmtQty(p!.currentStock - l.qty)}',
                style: const TextStyle(
                  color: AppColors.reports,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              inr.format(r.amount),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _lines.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final due = round2(t.grandTotal - _paidValue);
    final title = docTitle(widget.kind, widget.docType);
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing ? 'Edit ${widget.existing!.number}' : 'New $title')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Party
              Card(
                child: ListTile(
                  onTap: _pickParty,
                  leading: Icon(Icons.person_rounded, color: _color),
                  title: Text(
                    _party?.name ??
                        (_isSale ? 'Walk-in customer' : 'No supplier selected'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _party == null
                        ? 'Tap to choose a $_partyNoun'
                        : [
                            if (_party!.phone.isNotEmpty) _party!.phone,
                            if (_party!.gstin.isNotEmpty) _party!.gstin,
                          ].join('  •  '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const SizedBox(height: 12),
              // GST mode, supply type and date
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('GST')),
                      ButtonSegment(value: false, label: Text('NON-GST')),
                    ],
                    selected: {_isGst},
                    onSelectionChanged: (s) =>
                        setState(() => _isGst = s.first),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(dateFmt.format(_date)),
                  ),
                ],
              ),
              if (_isGst)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Interstate supply (IGST)'),
                  subtitle: Text(
                    _interstate
                        ? 'Tax is charged as IGST'
                        : 'Tax is split into CGST + SGST',
                  ),
                  value: _interstate,
                  onChanged: (v) => setState(() => _interstate = v),
                ),
              const SizedBox(height: 8),
              if (_isPurchaseInvoice) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.attach_file_rounded),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Supplier bill attachments', style: TextStyle(fontWeight: FontWeight.w700))),
                        OutlinedButton.icon(onPressed: _takePurchaseBillPhoto, icon: const Icon(Icons.camera_alt_rounded), label: const Text('Camera')),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(onPressed: _pickPurchaseBills, icon: const Icon(Icons.attach_file_rounded), label: const Text('Files')),
                      ]),
                      if (_purchaseBillFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (var i = 0; i < _purchaseBillFiles.length; i++)
                          ListTile(dense: true, contentPadding: EdgeInsets.zero,
                            leading: Icon(_purchaseBillFiles[i].extension?.toLowerCase() == 'pdf' ? Icons.picture_as_pdf : Icons.image),
                            title: Text(_purchaseBillFiles[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _purchaseBillFiles.removeAt(i))),
                          ),
                      ],
                      const Text('Photos and PDFs are copied into the app and linked to this purchase invoice.', style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Items
              Row(
                children: [
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (_isSale && widget.docType == DocType.invoice) ...[
                    OutlinedButton.icon(
                      onPressed: _scanSaleItem,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _color),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No items yet. Tap "Add item".',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                for (var i = 0; i < _lines.length; i++) _lineTile(i, t.lines[i]),
              const SizedBox(height: 12),
              // Totals
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _totalRow('Subtotal', t.subtotal),
                      if (t.discountTotal > 0)
                        _totalRow('Discount', -t.discountTotal),
                      if (_isGst) ...[
                        _totalRow('Taxable amount', t.taxable),
                        if (_interstate)
                          _totalRow('IGST', t.igst)
                        else ...[
                          _totalRow('CGST', t.cgst),
                          _totalRow('SGST', t.sgst),
                        ],
                      ],
                      const Divider(),
                      _totalRow('Grand total', t.grandTotal, bold: true),
                    ],
                  ),
                ),
              ),
              if (!_isQuotation) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isReturn
                              ? 'Refund'
                              : (_isSale ? 'Payment received' : 'Payment made'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _paid,
                                onChanged: (_) => setState(() {}),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Amount (₹)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => setState(
                                  () => _paid.text = fmtQty(t.grandTotal)),
                              child: const Text('Full'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _mode,
                          decoration: const InputDecoration(
                            labelText: 'Payment mode',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final m in kPayModes)
                              DropdownMenuItem(value: m, child: Text(m)),
                          ],
                          onChanged: (v) => setState(() {
                            _mode = v ?? 'Cash';
                            _accountId = _defaultAccountFor(_mode);
                          }),
                        ),
                        if (_accounts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey('acc$_accountId'),
                            initialValue: _accountId,
                            decoration: InputDecoration(
                              labelText: _isSale
                                  ? 'Money goes into'
                                  : 'Money comes from',
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              for (final a in _accounts)
                                DropdownMenuItem(
                                    value: a.id, child: Text(a.name)),
                            ],
                            onChanged: (v) => setState(() => _accountId = v),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _totalRow('Due amount', due < 0 ? 0 : due, bold: true),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _color),
                onPressed: _saving ? null : _save,
                child: Text(_saving
                    ? 'Saving...'
                    : (_editing ? 'Save changes' : 'Save $title')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
