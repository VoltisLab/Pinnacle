import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/transfer_ui_state.dart';
import '../services/local_address.dart';
import '../services/pairing_bonjour.dart';
import '../services/pinnacle_pairing_uri.dart';
import '../services/transfer_client.dart';
import '../state/transfer_overlay_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/connected_tick_dialog.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/pair_code_field.dart';
import '../widgets/transfer_progress_cards.dart';
import 'qr_scan_screen.dart';

/// True on Windows / macOS / Linux (outside the browser) — these are the
/// platforms where we show drag-and-drop affordances.
bool get _isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _pairCodeCtrl = TextEditingController();
  final List<PlatformFile> _files = [];

  bool _sending = false;
  bool _resolving = false;
  bool _connected = false;
  bool _dragging = false;

  String? _baseUrl;
  String? _peerLabel;
  SenderUploadProgress? _uploadProgress;

  @override
  void dispose() {
    _pairCodeCtrl.dispose();
    // Courtesy disconnect if we leave with a live session.
    if (_connected && _baseUrl != null) {
      TransferClient.disconnect(_baseUrl!);
    }
    super.dispose();
  }

  // ─── Files ────────────────────────────────────────────────────────────

  Future<void> _pickFiles({bool append = false}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      if (!append) _files.clear();
      _files.addAll(result.files);
    });
  }

  void _removeFile(PlatformFile f) {
    setState(() => _files.remove(f));
  }

  Future<void> _addDroppedFiles(List<XFile> dropped) async {
    if (dropped.isEmpty) return;
    final added = <PlatformFile>[];
    for (final f in dropped) {
      final path = f.path;
      if (path.isEmpty) continue;
      int size = 0;
      try {
        size = await File(path).length();
      } catch (_) {}
      added.add(PlatformFile(
        name: f.name.isNotEmpty ? f.name : path.split(Platform.pathSeparator).last,
        path: path,
        size: size,
      ));
    }
    if (added.isEmpty) return;
    setState(() => _files.addAll(added));
  }

  // ─── Scan / connect ───────────────────────────────────────────────────

  Future<void> _scan() async {
    if (!supportsCameraQrScan) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No camera on this device. Enter the 6-digit pairing code.',
          ),
        ),
      );
      return;
    }
    // The scanner screen does its own native permission prompt, which is
    // more reliable than pre-flighting with permission_handler (whose
    // cached status is often stale on iOS right after the user grants).
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    await _applyScanned(raw);
  }

  Future<void> _applyScanned(String raw) async {
    final trimmed = raw.trim();
    final http = httpBaseUrlFromPayload(trimmed);
    if (http != null) {
      await _connectTo(http);
      return;
    }
    final pinnacle = parsePinnacleReceiveUri(trimmed);
    if (pinnacle != null) {
      _pairCodeCtrl.text = pinnacle.code;
      await _connectFromPairingCode();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("That QR doesn't look like a Pinnacle receive code."),
      ),
    );
  }

  Future<void> _showConnectError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not connect'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectFromPairingCode() async {
    final code = _pairCodeCtrl.text.trim();
    if (code.length < 6 || RegExp(r'\D').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the full 6-digit pairing code.'),
        ),
      );
      return;
    }
    setState(() => _resolving = true);
    try {
      final url = await resolveHttpBaseUrlByPairingCode(
        code,
        timeout: const Duration(seconds: 5),
      );
      if (!mounted) return;
      if (url == null) {
        await _showConnectError(
          'No receiver matched that code within 5 seconds. '
          'Check the digits, Wi‑Fi, and that the other device is on Receive.',
        );
        return;
      }
      await _connectTo(url);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _connectTo(String baseUrl) async {
    setState(() => _resolving = true);
    try {
      final label = await TransferClient.connect(baseUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TransferException(
          'The receiver did not answer within 5 seconds.',
        ),
      );
      if (!mounted) return;
      setState(() {
        _baseUrl = baseUrl;
        _peerLabel = label;
        _connected = true;
      });
      HapticFeedback.mediumImpact();
      // Celebrate! The receiver is showing its own tick right now too.
      unawaitedShow(
        ConnectedTickDialog.show(
          context,
          title: 'Connected',
          subtitle: 'You\'re linked to $label. Pick files and send.',
        ),
      );
    } on TransferException catch (e) {
      if (!mounted) return;
      await _showConnectError(e.message);
    } catch (e) {
      if (!mounted) return;
      await _showConnectError('Could not connect: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End connection?'),
        content: const Text(
          'The receiver will go back to waiting for a new connection. You can reconnect anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final url = _baseUrl;
    if (url != null) {
      await TransferClient.disconnect(url);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _connected = false;
      _baseUrl = null;
      _peerLabel = null;
      _pairCodeCtrl.clear();
    });
  }

  // ─── Send ─────────────────────────────────────────────────────────────

  Future<void> _sendAll() async {
    final base = _baseUrl;
    if (base == null || !_connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a receiver first.'),
        ),
      );
      return;
    }
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one file.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      Future<int> lengthFor(PlatformFile f) async {
        final path = f.path;
        if (path != null) {
          try {
            final n = await File(path).length();
            if (n > 0) return n;
          } catch (_) {}
        }
        if (f.size > 0) return f.size;
        return 1;
      }

      final perFileBytes = <int>[];
      for (final f in _files) {
        perFileBytes.add(await lengthFor(f));
      }
      final sessionTotal = perFileBytes.fold<int>(0, (a, b) => a + b);
      var sessionOffset = 0;

      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        final path = f.path;
        if (path == null) {
          throw TransferException('Could not read "${f.name}" (try picking again).');
        }
        var total = perFileBytes[i];
        if (total <= 0) total = 1;
        if (mounted) {
          setState(() {
            _uploadProgress = SenderUploadProgress(
              fileName: f.name,
              bytesSent: 0,
              bytesTotal: total,
              speedBytesPerSecond: 0,
            );
          });
        }
        TransferOverlayController.instance.publish(TransferSnapshot(
          role: TransferRole.sending,
          fileName: f.name,
          bytesDone: 0,
          bytesTotal: total,
          bytesPerSecond: 0,
        ));
        await TransferClient.sendFile(
          base,
          path,
          sessionTotalBytes: sessionTotal > 0 ? sessionTotal : null,
          sessionBytesBeforeThisFile: sessionOffset,
          onProgress: (sent, tot, bps) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = SenderUploadProgress(
                fileName: f.name,
                bytesSent: sent,
                bytesTotal: tot,
                speedBytesPerSecond: bps,
              );
            });
            TransferOverlayController.instance.publish(TransferSnapshot(
              role: TransferRole.sending,
              fileName: f.name,
              bytesDone: sent,
              bytesTotal: tot,
              bytesPerSecond: bps,
            ));
          },
        );
        sessionOffset += total;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer complete')),
      );
      setState(() => _files.clear());
    } on TransferException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadProgress = null;
        });
      }
      TransferOverlayController.instance.clear();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.decimalPattern();

    final body = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  children: [
                    _FilesHeader(
                      hasFiles: _files.isNotEmpty,
                      onAddMore: () => _pickFiles(append: true),
                    ),
                    const SizedBox(height: 8),
                    _FilesSection(
                      theme: theme,
                      files: _files,
                      onPick: () => _pickFiles(),
                      onRemove: _removeFile,
                      fmt: fmt,
                      showDropHint: _isDesktop,
                      isDragging: _dragging,
                    ),
                    const SizedBox(height: 20),
                    if (_connected)
                      _ConnectedPanel(
                        peerLabel: _peerLabel,
                        baseUrl: _baseUrl,
                        onDisconnect: _sending ? null : _disconnect,
                      ),
                    const SizedBox(height: 12),
                    if (_uploadProgress != null)
                      SenderUploadBanner(progress: _uploadProgress!),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_connected) ...[
                        _PairPanel(
                          pairCtrl: _pairCodeCtrl,
                          resolving: _resolving,
                          onConnect: _connectFromPairingCode,
                          onScan: _scan,
                          onCompleted: (_) => _connectFromPairingCode(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: (_sending || !_connected || _files.isEmpty)
                            ? null
                            : _sendAll,
                        child: _sending
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(_connected ? 'Send files' : 'Connect first'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send'),
        ),
        body: _isDesktop
            ? DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (details) async {
                  setState(() => _dragging = false);
                  await _addDroppedFiles(details.files);
                },
                child: body,
              )
            : body,
      ),
    );
  }
}

/// Fire-and-forget helper: lets us await a dialog inside a synchronous
/// branch without blocking the caller. We don't care about its return.
void unawaitedShow(Future<void> future) {
  future.catchError((_) {});
}

/// Tan filled controls on the warm cream canvas (light mode only).
ButtonStyle? _sendLightTanControlStyle(BuildContext context) {
  if (Theme.of(context).brightness != Brightness.light) return null;
  return FilledButton.styleFrom(
    backgroundColor: AppTheme.lightWarmTan,
    foregroundColor: AppTheme.lightCreamCanvas,
    iconColor: AppTheme.lightCreamCanvas,
  );
}

class _FilesHeader extends StatelessWidget {
  const _FilesHeader({required this.hasFiles, required this.onAddMore});

  final bool hasFiles;
  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Files',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (hasFiles)
          TextButton.icon(
            onPressed: onAddMore,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add more'),
          ),
      ],
    );
  }
}

class _FilesSection extends StatelessWidget {
  const _FilesSection({
    required this.theme,
    required this.files,
    required this.onPick,
    required this.onRemove,
    required this.fmt,
    required this.showDropHint,
    required this.isDragging,
  });

  final ThemeData theme;
  final List<PlatformFile> files;
  final VoidCallback onPick;
  final void Function(PlatformFile) onRemove;
  final NumberFormat fmt;
  final bool showDropHint;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return _FilePickerCard(
        onTap: onPick,
        showDropHint: showDropHint,
        isDragging: isDragging,
      );
    }
    return Column(
      children: [
        if (isDragging) _DragOverlayHint(theme: theme),
        ...files.map(
          (f) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(
                f.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                f.size > 0 ? '${fmt.format(f.size)} bytes' : 'Size unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
              leading: Icon(
                Icons.insert_drive_file_outlined,
                color: theme.colorScheme.primary,
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => onRemove(f),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DragOverlayHint extends StatelessWidget {
  const _DragOverlayHint({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.file_download_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Drop files to add them to the queue',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.onTap,
    required this.showDropHint,
    required this.isDragging,
  });

  final VoidCallback onTap;
  final bool showDropHint;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDragging ? theme.colorScheme.primary : Colors.black,
          width: isDragging ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: isLight ? AppTheme.lightCreamMid : theme.cardTheme.color,
        shape: theme.cardTheme.shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pick files to send',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showDropHint
                      ? 'Photos, videos, documents — or drop files anywhere on this window.'
                      : 'Photos, videos, documents — any file type.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.62),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  style: _sendLightTanControlStyle(context),
                  onPressed: onTap,
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: const Text('Choose files'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PairPanel extends StatelessWidget {
  const _PairPanel({
    required this.pairCtrl,
    required this.resolving,
    required this.onConnect,
    required this.onScan,
    required this.onCompleted,
  });

  final TextEditingController pairCtrl;
  final bool resolving;
  final VoidCallback onConnect;
  final VoidCallback onScan;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pairing code',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code from the receiver, then Connect. Same Wi‑Fi on both devices.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.62),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        PairCodeField(
          controller: pairCtrl,
          enabled: !resolving,
          onCompleted: onCompleted,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (supportsCameraQrScan)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: resolving ? null : onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Scan QR'),
                ),
              ),
            if (supportsCameraQrScan) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                style: _sendLightTanControlStyle(context),
                onPressed: resolving ? null : onConnect,
                child: resolving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.brightness == Brightness.light
                              ? AppTheme.lightCreamCanvas
                              : theme.colorScheme.primary,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectedPanel extends StatelessWidget {
  const _ConnectedPanel({
    required this.peerLabel,
    required this.baseUrl,
    required this.onDisconnect,
  });

  final String? peerLabel;
  final String? baseUrl;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        peerLabel ?? 'receiver',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.link_off_rounded, size: 18),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
            if (baseUrl != null) ...[
              const SizedBox(height: 10),
              Text(
                baseUrl!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
