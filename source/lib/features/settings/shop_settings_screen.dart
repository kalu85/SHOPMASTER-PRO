import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/data/settings_repository.dart';
import '../../core/models/invoice.dart' show kPayModes;

/// Shop profile used on every invoice, plus a few defaults.
class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _bank = TextEditingController();
  final _accNo = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  final _footer = TextEditingController();
  final _prefix = TextEditingController();
  ShopSettings _s = const ShopSettings();
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _address, _phone, _gstin, _bank, _accNo, _ifsc, _upi, _footer, //
      _prefix,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await SettingsRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _name.text = s.shopName;
      _address.text = s.address;
      _phone.text = s.phone;
      _gstin.text = s.gstin;
      _bank.text = s.bankName;
      _accNo.text = s.accountNo;
      _ifsc.text = s.ifsc;
      _upi.text = s.upiId;
      _footer.text = s.footer;
      _prefix.text = s.invoicePrefix;
      _loaded = true;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: false);
      final path = res?.files.single.path;
      if (path == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(path).isEmpty ? '.png' : p.extension(path);
      final dest = File(p.join(
          dir.path, 'shop_logo_${DateTime.now().millisecondsSinceEpoch}$ext'));
      await File(path).copy(dest.path);
      if (!mounted) return;
      setState(() => _s = _s.copyWith(logoPath: dest.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not pick logo: $e')));
    }
  }

  Future<void> _save() async {
    final gstin = _gstin.text.trim().toUpperCase();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Shop name is required');
      return;
    }
    if (gstin.isNotEmpty &&
        !RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
            .hasMatch(gstin)) {
      setState(() => _error = 'GSTIN looks wrong. It has 15 letters/digits.');
      return;
    }
    final prefix = _prefix.text.trim().toUpperCase();
    if (prefix.isEmpty || !RegExp(r'^[A-Z0-9]{1,8}$').hasMatch(prefix)) {
      setState(() => _error = 'Invoice prefix: 1 to 8 letters or digits');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    await SettingsRepository.instance.save(_s.copyWith(
      shopName: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      gstin: gstin,
      bankName: _bank.text.trim(),
      accountNo: _accNo.text.trim(),
      ifsc: _ifsc.text.trim().toUpperCase(),
      upiId: _upi.text.trim(),
      footer: _footer.text.trim(),
      invoicePrefix: prefix,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Shop settings saved')));
  }

  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final logo = _s.logoPath.isNotEmpty && File(_s.logoPath).existsSync()
        ? Image.file(File(_s.logoPath), width: 72, height: 72, fit: BoxFit.contain)
        : Image.asset('assets/logo.png', width: 72, height: 72);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: logo),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Choose logo'),
                      ),
                      if (_s.logoPath.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              setState(() => _s = _s.copyWith(logoPath: '')),
                          child: const Text('Use default'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Shop name')),
            const SizedBox(height: 12),
            TextField(
                controller: _address, maxLines: 2, decoration: _dec('Address')),
            const SizedBox(height: 12),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _dec('Phone')),
            const SizedBox(height: 12),
            TextField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('GSTIN (shown on GST invoices only)'),
            ),
            const SizedBox(height: 20),
            Text('Bank and UPI (printed on sales invoices)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(controller: _bank, decoration: _dec('Bank name')),
            const SizedBox(height: 12),
            TextField(
                controller: _accNo,
                keyboardType: TextInputType.number,
                decoration: _dec('Account number')),
            const SizedBox(height: 12),
            TextField(
                controller: _ifsc,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec('IFSC')),
            const SizedBox(height: 12),
            TextField(
                controller: _upi,
                decoration: _dec('UPI ID (a QR code is printed from this)')),
            const SizedBox(height: 20),
            Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _prefix,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Sales invoice number prefix (e.g. INV)'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _footer, decoration: _dec('Footer message')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kPayModes.contains(_s.defaultPayMode)
                  ? _s.defaultPayMode
                  : 'Cash',
              decoration: _dec('Default payment mode'),
              items: [
                for (final m in kPayModes)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) =>
                  setState(() => _s = _s.copyWith(defaultPayMode: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('New invoices start as GST'),
              subtitle: const Text('Turn off to start as NON-GST'),
              value: _s.defaultGst,
              onChanged: (v) => setState(() => _s = _s.copyWith(defaultGst: v)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save shop settings'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
