import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a product serial number or barcode and returns its decoded value.
class SerialScannerScreen extends StatefulWidget {
  const SerialScannerScreen({super.key});

  @override
  State<SerialScannerScreen> createState() => _SerialScannerScreenState();
}

class _SerialScannerScreenState extends State<SerialScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _starting = false;
  String? _startError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restart();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _restart() async {
    if (_starting || !mounted) return;
    _starting = true;
    try {
      await _controller.start();
      if (mounted) setState(() => _startError = null);
    } catch (e) {
      if (mounted) setState(() => _startError = e.toString());
    } finally {
      _starting = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan serial number')),
        body: MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            final details = _startError ??
                '${error.errorCode.name}: ${error.errorDetails?.message ?? 'No additional details'}';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera could not start',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(details, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try camera again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close scanner'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
