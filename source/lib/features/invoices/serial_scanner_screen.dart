import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a product serial number or barcode and returns its decoded value.
class SerialScannerScreen extends StatefulWidget {
  const SerialScannerScreen({super.key});

  @override
  State<SerialScannerScreen> createState() => _SerialScannerScreenState();
}

class _SerialScannerScreenState extends State<SerialScannerScreen> {
  bool _handled = false;

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan serial number')),
        body: MobileScanner(onDetect: _onDetect),
      );
}
