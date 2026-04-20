import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/transfer_ui_state.dart';
import '../services/local_address.dart';
import '../services/pairing_bonjour.dart';
import '../services/pinnacle_pairing_uri.dart';
import '../services/transfer_server.dart';
import '../state/app_settings.dart';
import '../state/transfer_overlay_controller.dart';
import '../widgets/connected_tick_dialog.dart';
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
  bool _starting = true;
  String? _httpUrl;
  String? _qrPayload;
  String _pairCode = '';
  String? _savePathLabel;
  AppSettings? _settings;
  bool _showedConnectedDialog = false;
  late final AnimationController _waitTurn;

  @override
  void initState() {
    super.initState();
    _waitTurn = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _server.receiveUi.addListener(_onReceiveUiChanged);
    // Kick off listening immediately — user 7: skip the extra "tap to
    // start" screen. Scheduled post-frame so we can read settings first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
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
    _maybeShowConnectedTick();
    _maybePublishReceivingOverlay();
  }

  void _syncWaitRotation() {
    final v = _server.receiveUi.value;
    if (_server.isRunning && v is ReceiverWaitingConnection) {
      if (!_waitTurn.isAnimating) {
        _waitTurn.repeat();
      }
    } else {
      _waitTurn
        ..stop()
        ..reset();
    }
  }

  void _maybeShowConnectedTick() {
    final v = _server.receiveUi.value;
    if (v is ReceiverConnected && !_showedConnectedDialog && mounted) {
      _showedConnectedDialog = true;
      unawaited(
        ConnectedTickDialog.show(
          context,
          title: 'Connected',
          subtitle:
              v.peerLabel != null
                  ? '${v.peerLabel} is linked. Waiting for files.'
                  : 'A sender is linked. Waiting for files.',
        ),
      );
    }
    if (v is ReceiverWaitingConnection) {
      // Reset so reconnecting a new peer shows the celebration again.
      _showedConnectedDialog = false;
    }
  }

  void _maybePublishReceivingOverlay() {
    final v = _server.receiveUi.value;
    if (v is ReceiverReceiving) {
      TransferOverlayController.instance.publish(TransferSnapshot(
        role: TransferRole.receiving,
        fileName: v.fileName,
        bytesDone: v.bytesReceived,
        bytesTotal: v.bytesTotal ?? 0,
        bytesPerSecond: v.speedBytesPerSecond,
      ));
    } else {
      TransferOverlayController.instance.clear();
    }
  }

  @override
  void dispose() {
    _server.receiveUi.removeListener(_onReceiveUiChanged);
    _settings?.removeListener(_onSettingsChanged);
    _waitTurn.dispose();
    unawaited(_bonjour.stop());
    unawaited(_server.stop());
    TransferOverlayController.instance.clear();
    super.dispose();
  }

  String _makePairCode() {
    return '${100000 + Random().nextInt(900000)}';
  }

  Future<void> _autoStart() async {
    if (_server.isRunning) {
      setState(() => _starting = false);
      return;
    }
    await _startServer();
  }

  Future<void> _startServer() async {
    setState(() {
      _busy = true;
      _starting = true;
    });
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
        _starting = false;
      });
      _syncWaitRotation();
    } catch (e) {
      await _bonjour.stop();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _starting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start server: $e')),
      );
    }
  }

  Future<void> _stopServer() async {
    setState(() => _busy = true);
    await _bonjour.stop();
    await _server.stop();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _httpUrl = null;
      _qrPayload = null;
      _pairCode = '';
      _showedConnectedDialog = false;
    });
    _syncWaitRotation();
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = _server.isRunning;

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receive'),
          actions: [
            if (listening)
              IconButton(
                tooltip: 'Stop listening',
                onPressed: _busy ? null : _stopServer,
                icon: const Icon(Icons.power_settings_new_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _starting
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Ready for files',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan the QR or enter the pairing code on the sender.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.65),
                          height: 1.4,
                        ),
                      ),
                      if (runningOnIosSimulator) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Simulator: paste the URL on the sender — the '
                          'camera scanner is unavailable here.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Expanded(
                        child: _qrPayload == null
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  ValueListenableBuilder<ReceiverTransferUi>(
                                    valueListenable: _server.receiveUi,
                                    builder: (context, ui, _) {
                                      return AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 280),
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SaveLocationRow(
                          label: _savePathLabel ?? _fallbackSaveLabel(),
                          onEdit: _openSaveLocationEditor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _fallbackSaveLabel() {
    final folder = _settings?.saveFolderName ?? 'Pinnacle';
    if (Platform.isAndroid) return 'Downloads / $folder';
    if (Platform.isIOS) return 'Files → On My iPhone → Pinnacle → $folder';
    return '<Downloads> / $folder';
  }

  Widget _statusFor(ReceiverTransferUi ui) {
    if (ui is ReceiverReceiving) {
      return ReceiverReceivingBanner(
        key: const ValueKey('receiving'),
        state: ui,
      );
    }
    if (ui is ReceiverConnected) {
      return ReceiverConnectedBanner(
        key: const ValueKey('connected'),
        peerLabel: ui.peerLabel,
      );
    }
    return ReceiverWaitingConnectionBanner(
      key: const ValueKey('waiting-connection'),
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
          const SizedBox(height: 12),
          Text(
            'Pairing code',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            pairCode,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 14),
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
