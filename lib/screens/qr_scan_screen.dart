import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/local_address.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

String? _payloadFromBarcode(Barcode code) {
  final r = code.rawValue?.trim();
  if (r != null && r.isNotEmpty) return r;
  final d = code.displayValue?.trim();
  if (d != null && d.isNotEmpty) return d;
  final u = code.url?.url.trim();
  if (u != null && u.isNotEmpty) return u;
  return null;
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _controller;
  bool _handled = false;
  String? _error;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (Platform.isIOS && runningOnIosSimulator) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error =
            'The iOS Simulator does not provide a camera. Paste the receive link, '
            'or enter the pairing code on the Send screen.';
      });
      return;
    }

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = status.isPermanentlyDenied
            ? 'Camera access is off for Pinnacle. Enable it in Settings → Pinnacle → Camera.'
            : 'Camera access is required to scan QR codes.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      _opening = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan receiver QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_error != null && Platform.isIOS && runningOnIosSimulator)
            const SizedBox.shrink()
          else if (_error != null)
            TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Settings'),
            ),
        ],
      ),
      body: _opening
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_handled) return;
                    for (final code in capture.barcodes) {
                      // ML Kit often leaves [rawValue] null for URL-style payloads;
                      // use fallbacks so scanning a receive QR still works.
                      final raw = _payloadFromBarcode(code);
                      if (raw == null || raw.isEmpty) continue;
                      _handled = true;
                      Navigator.of(context).pop<String>(raw);
                      return;
                    }
                  },
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Text(
                      'Point the camera at the QR on the receiving device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
