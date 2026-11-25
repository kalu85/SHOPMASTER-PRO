import 'package:flutter/material.dart';

import '../../core/data/party_repository.dart';
import '../../core/models/party.dart';
import '../../core/utils/format.dart';
import '../../core/utils/validators.dart';

/// Add / edit a customer or supplier.
class PartyFormScreen extends StatefulWidget {
  const PartyFormScreen({super.key, required this.type, this.party});

  final PartyType type;
  final Party? party;

  @override
  State<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends State<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _opening = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.party != null;
  bool get _isCustomer => widget.type == PartyType.customer;
  String get _noun => _isCustomer ? 'customer' : 'supplier';

  @override
  void initState() {
    super.initState();
    final p = widget.party;
    if (p != null) {
      _name.text = p.name;
      _phone.text = p.phone;
      _address.text = p.address;
      _email.text = p.email;
      _gstin.text = p.gstin;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _email, _gstin, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final party = Party(
      id: widget.party?.id,
      type: widget.type,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      email: _email.text.trim(),
      gstin: _gstin.text.trim().toUpperCase(),
      openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
    );
    try {
      if (_isEdit) {
        await PartyRepository.instance.update(party);
      } else {
        await PartyRepository.instance.insert(party);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit $_noun' : 'Add $_noun'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: '${_isCustomer ? 'Customer' : 'Supplier'} name *',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                _gap(),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.isValidPhone(v)
                        ? null
                        : 'Enter a valid phone number';
                  },
                ),
                _gap(),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.isValidEmail(v)
                        ? null
                        : 'Enter a valid email address';
                  },
                ),
                _gap(),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                _gap(),
                TextFormField(
                  controller: _gstin,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN',
                    helperText: '15 characters, e.g. 27AAPFU0939F1ZV',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.isValidGstin(v)
                        ? null
                        : 'Enter a valid 15-character GSTIN';
                  },
                ),
                _gap(),
                if (_isEdit)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD6E6F7)),
                    ),
                    child: Text(
                      'Current balance: ${inr.format(widget.party!.currentBalance)}'
                      '. Balances change through invoices and payments.',
                    ),
                  )
                else
                  TextFormField(
                    controller: _opening,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening balance (₹)',
                      helperText: _isCustomer
                          ? 'Amount this customer already owes you'
                          : 'Amount you already owe this supplier',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final d = double.tryParse(v.trim());
                      return (d == null || d < 0) ? 'Enter a valid amount' : null;
                    },
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save $_noun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
