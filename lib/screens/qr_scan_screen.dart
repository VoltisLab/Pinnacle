import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../services/camera_permission.dart';
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

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _handled = false;
  String? _error;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_handled) return;
      if (Platform.isIOS && runningOnIosSimulator) return;
      _controller?.dispose();
      _controller = null;
      unawaited(_prepare());
    }
  }

  Future<void> _prepare() async {
    if (!mounted) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    _controller?.dispose();
    _controller = null;

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

    final cam = await ensureCameraPermission();
    if (cam == CameraPermissionResult.unsupported) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error =
            'Camera-based scanning is not available on this platform. Paste the receive link '
            'or enter the pairing code on the Send screen.';
      });
      return;
    }
    if (cam != CameraPermissionResult.granted) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _error = cam == CameraPermissionResult.permanentlyDenied
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
    WidgetsBinding.instance.removeObserver(this);
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
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
