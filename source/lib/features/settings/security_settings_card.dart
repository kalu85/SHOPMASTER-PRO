import 'package:flutter/material.dart';

import '../../core/services/app_lock_service.dart';

class SecuritySettingsCard extends StatefulWidget {
  const SecuritySettingsCard({super.key});

  @override
  State<SecuritySettingsCard> createState() => _SecuritySettingsCardState();
}

class _SecuritySettingsCardState extends State<SecuritySettingsCard> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await AppLockService.instance.isEnabled;
    if (mounted) setState(() => _enabled = value);
  }

  Future<void> _configure() async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set app PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a 4–12 digit PIN. It is stored as a salted hash in secure device storage.'),
              const SizedBox(height: 14),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!RegExp(r'^\d{4,12}$').hasMatch(pin.text)) {
                  setDialogState(() => error = 'Enter 4 to 12 digits.');
                } else if (pin.text != confirm.text) {
                  setDialogState(() => error = 'PINs do not match.');
                } else {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await AppLockService.instance.setPin(pin.text);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App PIN enabled')),
        );
      }
    }
    pin.dispose();
    confirm.dispose();
  }

  Future<void> _disable() async {
    final pin = TextEditingController();
    final valid = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off app lock'),
        content: TextField(
          controller: pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ok = await AppLockService.instance.verifyPin(pin.text);
              if (context.mounted) Navigator.pop(context, ok);
            },
            child: const Text('Verify and turn off'),
          ),
        ],
      ),
    );
    if (valid == true) {
      await AppLockService.instance.removePin();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App lock disabled')),
        );
      }
    } else if (valid == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN was not verified; app lock remains on')),
      );
    }
    pin.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App security', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(_enabled == null
                ? 'Checking security status…'
                : _enabled!
                    ? 'PIN lock is enabled. The app locks when reopened after backgrounding.'
                    : 'Protect shop invoices and business data with a PIN.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _enabled == null ? null : _configure,
                  child: Text(_enabled == true ? 'Change PIN' : 'Set app PIN'),
                ),
                if (_enabled == true)
                  OutlinedButton(
                    onPressed: _disable,
                    child: const Text('Turn off lock'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
