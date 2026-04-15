import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/local_address.dart';
import '../services/transfer_server.dart';
import '../widgets/mesh_gradient_background.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _server = TransferServer();
  bool _busy = false;
  String? _ip;
  String? _url;
  String? _savePathLabel;

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_server.isRunning) {
      setState(() => _busy = true);
      await _server.stop();
      if (mounted) {
        setState(() {
          _busy = false;
          _url = null;
          _ip = null;
        });
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await _server.start();
      final dir = await _server.receiveDirectory();
      final ip = await localWifiIPv4();
      if (!mounted) return;
      setState(() {
        _ip = ip;
        _url = ip != null ? 'http://$ip:${_server.port}' : null;
        _savePathLabel = dir.path;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start server: $e')),
      );
    }
  }

  Future<void> _copyUrl() async {
    final url = _url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = _server.isRunning;

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receive'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  listening
                      ? 'Ready for files'
                      : 'Start listening to accept transfers.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  listening
                      ? 'Senders can scan the code or enter the address manually.'
                      : 'Files are saved privately in Documents/Pinnacle/Received.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: !listening
                          ? _IdleIllustration(theme: theme)
                          : _ip == null || _url == null ? _NoWifi(theme: theme, port: _server.port)
                              : _QrPanel(
                                  url: _url!,
                                  onCopy: _copyUrl,
                                ),
                    ),
                  ),
                ),
                if (_savePathLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Save location\n${_savePathLabel!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                        height: 1.35,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _toggle,
                  child: Text(listening ? 'Stop receiving' : 'Start receiving'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleIllustration extends StatelessWidget {
  const _IdleIllustration({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 72,
          color: theme.colorScheme.onSurface.withOpacity(0.22),
        ),
        const SizedBox(height: 16),
        Text(
          'Your QR will appear here',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _NoWifi extends StatelessWidget {
  const _NoWifi({required this.theme, required this.port});

  final ThemeData theme;
  final int port;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 56,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not read this device’s Wi‑Fi address. '
            'Connect to Wi‑Fi, or share manually: port $port',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.url, required this.onCopy});

  final String url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                gapless: true,
                size: 220,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0B0B0D),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0B0B0D),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SelectableText(
            url,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 20),
            label: const Text('Copy address'),
          ),
        ],
      ),
    );
  }
}
