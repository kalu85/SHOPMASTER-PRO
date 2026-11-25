import 'package:flutter/material.dart';

import '../../core/data/party_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/party.dart';
import '../../core/services/contact_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// WhatsApp Connect. Opens a chat with the message already typed; the
/// person taps send. No automatic sending (that needs the official
/// WhatsApp Business API, which is not set up).
class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  List<Party> _dues = [];
  ShopSettings _shop = const ShopSettings();
  bool _loading = true;
  final _phone = TextEditingController();
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await PartyRepository.instance.withDues(PartyType.customer);
    final s = await SettingsRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _dues = d;
      _shop = s;
      _loading = false;
    });
  }

  Future<void> _open(String phone, String msg) async {
    final ok = await ContactService.whatsApp(phone, msg);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  String _reminder(Party p) =>
      'Hello ${p.name}, this is a friendly reminder from ${_shop.shopName}. '
      'Your pending balance is ${inr.format(p.currentBalance)}. '
      'Please pay at your convenience. Thank you!';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.lightBlue,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tap Send and WhatsApp opens with the message already typed. You press send yourself. '
                  'To send an invoice PDF, open the invoice, tap PDF, then "Share PDF" and choose WhatsApp. '
                  'Automatic sending needs the official WhatsApp Business API, which is not set up in this version.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payment reminders',
                style: Theme.of(context).textTheme.titleMedium),
            if (_dues.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No customer has a pending balance.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            for (final p in _dues)
              Card(
                child: ListTile(
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${p.phone.isEmpty ? 'No phone number' : p.phone}  •  owes ${inr.format(p.currentBalance)}'),
                  trailing: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sales),
                    onPressed: () => _open(p.phone, _reminder(p)),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Write a message',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone number (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                if (_text.text.trim().isEmpty) return;
                _open(_phone.text, _text.text.trim());
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Open in WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}
