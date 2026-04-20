import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/local_address.dart';
import '../services/pairing_bonjour.dart';
import '../services/pinnacle_pairing_uri.dart';
import '../models/transfer_ui_state.dart';
import '../services/transfer_server.dart';
import '../state/app_settings.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/transfer_progress_cards.dart';
import 'settings/save_location_screen.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  final _server = TransferServer();
  final _bonjour = PairingBonjourAdvertiser();
  bool _busy = false;
  String? _httpUrl;
  String? _qrPayload;
  String _pairCode = '';
  String? _savePathLabel;
  AppSettings? _settings;
  late final AnimationController _waitTurn;

  @override
  void initState() {
    super.initState();
    _waitTurn = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _server.receiveUi.addListener(_onReceiveUiChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppSettingsScope.of(context);
    if (_settings != settings) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = settings;
      _settings!.addListener(_onSettingsChanged);
      _server.saveFolderName = settings.saveFolderName;
      // Refresh the label if we're already listening; folder name changed.
      if (_server.isRunning) {
        _refreshSaveLocationLabel();
      }
    }
  }

  void _onSettingsChanged() {
    final s = _settings;
    if (s == null) return;
    _server.saveFolderName = s.saveFolderName;
    if (_server.isRunning) _refreshSaveLocationLabel();
  }

  Future<void> _refreshSaveLocationLabel() async {
    final label = await _server.receiveLocationLabel();
    if (!mounted) return;
    setState(() => _savePathLabel = label);
  }

  void _onReceiveUiChanged() {
    _syncWaitRotation();
  }

  void _syncWaitRotation() {
    final v = _server.receiveUi.value;
    if (_server.isRunning && v is ReceiverWaiting) {
      if (!_waitTurn.isAnimating) {
        _waitTurn.repeat();
      }
    } else {
      _waitTurn
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _server.receiveUi.removeListener(_onReceiveUiChanged);
    _settings?.removeListener(_onSettingsChanged);
    _waitTurn.dispose();
    unawaited(_bonjour.stop());
    unawaited(_server.stop());
    super.dispose();
  }

  String _makePairCode() {
    return '${100000 + Random().nextInt(900000)}';
  }

  String _idleSaveLocationHint() {
    final folder = _settings?.saveFolderName ?? 'Pinnacle';
    if (Platform.isAndroid) {
      return 'Received files save to Downloads / $folder — open the Files or Downloads app to find them.';
    }
    if (Platform.isIOS) {
      return 'Received files save to the Files app under On My iPhone → Pinnacle → $folder.';
    }
    return 'Received files save to your Downloads / $folder folder.';
  }

  Future<void> _toggle() async {
    if (_server.isRunning) {
      setState(() => _busy = true);
      await _bonjour.stop();
      await _server.stop();
      if (mounted) {
        setState(() {
          _busy = false;
          _httpUrl = null;
          _qrPayload = null;
          _pairCode = '';
        });
        _syncWaitRotation();
      }
      return;
    }

    setState(() => _busy = true);
    try {
      _server.saveFolderName =
          _settings?.saveFolderName ?? _server.saveFolderName;
      await _server.start();
      final label = await _server.receiveLocationLabel();
      final ip = await primaryLanIPv4();
      final port = _server.port;
      final code = _makePairCode();
      final http = ip != null ? 'http://$ip:$port' : null;
      final qr = http ?? buildPinnacleReceiveUri(port: port, pairCode: code);
      await _bonjour.start(port: port, pairCode: code);
      if (!mounted) return;
      setState(() {
        _httpUrl = http;
        _qrPayload = qr;
        _pairCode = code;
        _savePathLabel = label;
        _busy = false;
      });
      _syncWaitRotation();
    } catch (e) {
      await _bonjour.stop();
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start server: $e')),
      );
    }
  }

  Future<void> _copyUrl() async {
    final text = _httpUrl ?? _qrPayload;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  Future<void> _copyCode() async {
    if (_pairCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _pairCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pairing code copied')),
    );
  }

  Future<void> _openSaveLocationEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SaveLocationScreen(),
      ),
    );
    // Settings listener will pick up any change.
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
                      ? 'Scan the QR, open the link, or enter the pairing code on the sender.'
                      : _idleSaveLocationHint(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
                if (listening && runningOnIosSimulator) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Simulator: use pairing code or paste the URL on the sender — '
                    'the camera scanner is unavailable here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: !listening
                        ? Center(
                            key: const ValueKey('idle'),
                            child: _IdleIllustration(theme: theme),
                          )
                        : _qrPayload == null
                            ? const Center(
                                key: ValueKey('busy'),
                                child: CircularProgressIndicator(),
                              )
                            : Column(
                                key: ValueKey(_qrPayload),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ValueListenableBuilder<ReceiverTransferUi>(
                                    valueListenable: _server.receiveUi,
                                    builder: (context, ui, _) {
                                      return AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 260),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        child: _statusFor(ui),
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: _ReceivePanel(
                                        theme: theme,
                                        qrPayload: _qrPayload!,
                                        httpUrl: _httpUrl,
                                        pairCode: _pairCode,
                                        onCopyUrl: _copyUrl,
                                        onCopyCode: _copyCode,
                                        qrSize: 188,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
                if (_savePathLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SaveLocationRow(
                      label: _savePathLabel!,
                      onEdit: _openSaveLocationEditor,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SaveLocationRow(
                      label: Platform.isAndroid
                          ? 'Downloads / ${_settings?.saveFolderName ?? 'Pinnacle'}'
                          : Platform.isIOS
                              ? 'Files → On My iPhone → Pinnacle → ${_settings?.saveFolderName ?? 'Pinnacle'}'
                              : _settings?.saveFolderName ?? 'Pinnacle',
                      onEdit: _openSaveLocationEditor,
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

  Widget _statusFor(ReceiverTransferUi ui) {
    if (ui is ReceiverConnected) {
      return ReceiverConnectedBanner(
        key: ValueKey('connected-${ui.fileName}'),
        fileName: ui.fileName,
      );
    }
    if (ui is ReceiverReceiving) {
      return ReceiverReceivingBanner(
        key: const ValueKey('receiving'),
        state: ui,
      );
    }
    return ReceiverWaitingBanner(
      key: const ValueKey('waiting'),
      rotation: _waitTurn,
    );
  }
}

class _SaveLocationRow extends StatelessWidget {
  const _SaveLocationRow({required this.label, required this.onEdit});

  final String label;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save location',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.82),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Change save location',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 20),
        ),
      ],
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
          'Your QR and pairing code will appear here',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _ReceivePanel extends StatelessWidget {
  const _ReceivePanel({
    required this.theme,
    required this.qrPayload,
    required this.httpUrl,
    required this.pairCode,
    required this.onCopyUrl,
    required this.onCopyCode,
    this.qrSize = 220,
  });

  final ThemeData theme;
  final String qrPayload;
  final String? httpUrl;
  final String pairCode;
  final VoidCallback onCopyUrl;
  final VoidCallback onCopyCode;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
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
                data: qrPayload,
                version: QrVersions.auto,
                gapless: true,
                size: qrSize,
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
          const SizedBox(height: 16),
          if (httpUrl != null)
            SelectableText(
              httpUrl!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(
              'Open Wi‑Fi for a direct link, or use the pairing code below.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                height: 1.35,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Pairing code',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            pairCode,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onCopyCode,
                icon: const Icon(Icons.pin_rounded, size: 20),
                label: const Text('Copy code'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyUrl,
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: Text(httpUrl != null ? 'Copy link' : 'Copy QR text'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
