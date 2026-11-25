import 'package:flutter/material.dart';

import 'app_lock_service.dart';

/// Covers the app until the locally configured PIN is entered.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _enabled = false;
  bool _locked = false;
  final _pin = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppLockService.instance.isEnabled;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _locked = enabled;
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _lockIfEnabled();
  }

  Future<void> _lockIfEnabled() async {
    final enabled = await AppLockService.instance.isEnabled;
    if (!mounted || !enabled) return;
    setState(() {
      _enabled = true;
      _locked = true;
      _pin.clear();
      _error = null;
    });
  }

  Future<void> _unlock() async {
    if (_checking || _pin.text.length < 4) return;
    setState(() => _checking = true);
    final valid = await AppLockService.instance.verifyPin(_pin.text);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (valid) {
        _locked = false;
        _error = null;
        _pin.clear();
      } else {
        _error = 'Incorrect PIN. Try again.';
        _pin.clear();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF0B1A33),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: Color(0xFF42D6E8), size: 54),
                          const SizedBox(height: 18),
                          const Text('SHOPMASTER PRO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Enter your app PIN to continue',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _pin,
                            autofocus: true,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            onSubmitted: (_) => _unlock(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'PIN',
                              hintStyle: const TextStyle(color: Colors.white54),
                              errorText: _error,
                              filled: true,
                              fillColor: const Color(0xFF172B49),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _checking ? null : _unlock,
                              child: Text(_checking ? 'Checking…' : 'Unlock'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
