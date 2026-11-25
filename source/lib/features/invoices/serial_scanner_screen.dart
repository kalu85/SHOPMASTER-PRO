import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a product serial number or barcode and returns its decoded value.
class SerialScannerScreen extends StatefulWidget {
  const SerialScannerScreen({super.key});

  @override
  State<SerialScannerScreen> createState() => _SerialScannerScreenState();
}

class _SerialScannerScreenState extends State<SerialScannerScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  Future<void> _retryCamera() async {
    if (_retrying || !mounted) return;
    setState(() => _retrying = true);
    try {
      await _controller.stop();
      await _controller.start();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera retry failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
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
            final details = [
              'Error code: ${error.errorCode.name}',
              if (error.errorDetails?.message case final message?)
                'Details: $message',
            ].join('\\n');
            return Center(
              child: SingleChildScrollView(
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
                    SelectableText(details, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retryCamera,
                      icon: const Icon(Icons.refresh),
                      label: Text(_retrying ? 'Retrying…' : 'Try camera again'),
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
