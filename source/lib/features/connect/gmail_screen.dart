import 'package:flutter/material.dart';

import '../../core/data/party_repository.dart';
import '../../core/data/settings_repository.dart';
import '../../core/models/party.dart';
import '../../core/services/contact_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';

/// Gmail Integration. Honest status: Google sign-in (OAuth) sending is not
/// set up. Emails open in the phone's mail app with the text typed in.
class GmailScreen extends StatefulWidget {
  const GmailScreen({super.key});

  @override
  State<GmailScreen> createState() => _GmailScreenState();
}

class _GmailScreenState extends State<GmailScreen> {
  List<Party> _dues = [];
  ShopSettings _shop = const ShopSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await PartyRepository.instance.withDues(PartyType.customer);
    final s = await SettingsRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _dues = all.where((p) => p.email.isNotEmpty).toList();
      _shop = s;
      _loading = false;
    });
  }

  Future<void> _mail(Party p) async {
    final ok = await ContactService.email(
      p.email,
      'Payment reminder from ${_shop.shopName}',
      'Hello ${p.name},\n\nThis is a friendly reminder that your pending balance with ${_shop.shopName} is ${inr.format(p.currentBalance)}.\n\nThank you.',
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No email app found')));
    }
  }

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
              color: const Color(0xFFFFF4E5),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gmail sign-in is not connected',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'Sending email straight from your Gmail account needs a Google sign-in (OAuth) set up with your own Google Cloud project. That is not done in this version.\n\n'
                      'What works now: open any invoice, tap PDF, then "Share PDF" and pick Gmail (or any mail app). The PDF is attached and you tap send. '
                      'The reminders below open your mail app with the message typed in.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payment reminders by email',
                style: Theme.of(context).textTheme.titleMedium),
            if (_dues.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No customer with a pending balance has an email address saved.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            for (final p in _dues)
              Card(
                child: ListTile(
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${p.email}  •  owes ${inr.format(p.currentBalance)}'),
                  trailing: FilledButton.icon(
                    onPressed: () => _mail(p),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
