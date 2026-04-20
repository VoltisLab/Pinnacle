import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/camera_permission.dart';

import '../services/local_address.dart';
import '../services/pairing_bonjour.dart';
import '../services/pinnacle_pairing_uri.dart';
import '../models/transfer_ui_state.dart';
import '../services/transfer_client.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/transfer_progress_cards.dart';
import 'qr_scan_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _addressCtrl = TextEditingController();
  final _pairCodeCtrl = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _sending = false;
  bool _resolving = false;
  SenderUploadProgress? _uploadProgress;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _pairCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _files
        ..clear()
        ..addAll(result.files);
    });
  }

  Future<void> _addMoreFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _files.addAll(result.files));
  }

  void _removeFile(PlatformFile f) {
    setState(() => _files.remove(f));
  }

  Future<void> _scan() async {
    if (!supportsCameraQrScan) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No camera on this device. Paste the receive link, or enter the pairing code.',
          ),
        ),
      );
      return;
    }

    final result = await ensureCameraPermission();
    if (!mounted) return;
    switch (result) {
      case CameraPermissionResult.granted:
        break;
      case CameraPermissionResult.unsupported:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera scanning isn\'t available on this device.'),
          ),
        );
        return;
      case CameraPermissionResult.permanentlyDenied:
        await openCameraSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enable Camera for Pinnacle in Settings, then try again.',
            ),
          ),
        );
        return;
      case CameraPermissionResult.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera access is needed to scan QR codes.'),
          ),
        );
        return;
    }

    if (!mounted) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    try {
      await _applyPayload(raw);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use scan: $e')),
      );
    }
  }

  Future<void> _applyPayload(String raw) async {
    final trimmed = raw.trim();
    final httpUrl = httpBaseUrlFromPayload(trimmed);
    if (httpUrl != null) {
      setState(() => _addressCtrl.text = httpUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receiver address filled — tap Send when ready.'),
          ),
        );
      }
      return;
    }
    final pinnacle = parsePinnacleReceiveUri(trimmed);
    if (pinnacle != null) {
      setState(() => _pairCodeCtrl.text = pinnacle.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Looking for receiver on your Wi‑Fi…'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      await _resolveFromPairingCode();
      return;
    }
    setState(() => _addressCtrl.text = _normalizeScanned(trimmed));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Address from QR filled — confirm it looks correct, then Send.'),
        ),
      );
    }
  }

  String _normalizeScanned(String raw) {
    final t = raw.trim();
    if (t.contains('://')) return t;
    return 'http://$t';
  }

  Future<void> _resolveFromPairingCode() async {
    final code = _pairCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit pairing code from the receiver.'),
        ),
      );
      return;
    }
    setState(() => _resolving = true);
    try {
      final url = await resolveHttpBaseUrlByPairingCode(code);
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No receiver found for that code. Same Wi‑Fi, receiver still listening?',
            ),
          ),
        );
      } else {
        setState(() => _addressCtrl.text = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiver found on your network')),
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  String? _baseUrl() {
    var s = _addressCtrl.text.trim();
    if (s.isEmpty) return null;
    final pinnacle = parsePinnacleReceiveUri(s);
    if (pinnacle != null) return null;
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.parse(s);
    if (!u.hasAuthority) return null;
    return u
        .replace(path: '', query: '', fragment: '')
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _showInfoSheet() async {
    final ip = await primaryLanIPv4();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SendInfoSheet(
        myIp: ip,
        receiverAddress: _addressCtrl.text.trim(),
        pairCode: _pairCodeCtrl.text.trim(),
      ),
    );
  }

  Future<void> _sendAll() async {
    final addr = _addressCtrl.text.trim();
    final pin = parsePinnacleReceiveUri(addr);
    if (pin != null && httpBaseUrlFromPayload(addr) == null) {
      _pairCodeCtrl.text = pin.code;
      await _resolveFromPairingCode();
      if (!mounted) return;
    }
    var base = _baseUrl();
    if (base == null && _pairCodeCtrl.text.trim().isNotEmpty) {
      await _resolveFromPairingCode();
      if (!mounted) return;
      base = _baseUrl();
    }
    if (base == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a receive address, scan a QR, or find the receiver with a pairing code.',
          ),
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
      for (final f in _files) {
        final path = f.path;
        if (path == null) {
          throw TransferException('Could not read "${f.name}" (try picking again).');
        }
        var total = f.size;
        if (total <= 0) {
          try {
            total = await File(path).length();
          } catch (_) {
            total = 1;
          }
        }
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
        await TransferClient.sendFile(
          base,
          path,
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
          },
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer complete')),
      );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.decimalPattern();

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send'),
          actions: [
            IconButton(
              tooltip: 'Network info',
              onPressed: _showInfoSheet,
              icon: const Icon(Icons.info_outline_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              // 1 — Files first: pick what you want to send before worrying
              // about where it's going. Lowers the friction from tap-to-send.
              Row(
                children: [
                  Text(
                    'Files',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_files.isNotEmpty)
                    TextButton.icon(
                      onPressed: _addMoreFiles,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add more'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_files.isEmpty)
                _FilePickerCard(onTap: _pickFiles)
              else
                ..._files.map(
                  (f) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        f.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        f.size > 0
                            ? '${fmt.format(f.size)} bytes'
                            : 'Size unknown',
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
                        onPressed: () => _removeFile(f),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // 2 — Receiver address comes after files; by this point the
              // user is ready to scan/paste and send.
              Text(
                'Receiver',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste the link from the receiver, scan its QR, or use a pairing code on the same Wi‑Fi.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.12:54321',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (supportsCameraQrScan)
                OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text('Scan QR'),
                )
              else
                Text(
                  'No camera here — paste the URL above or use a pairing code below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 22),
              Text(
                'Pairing code',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Same Wi‑Fi: enter the 6-digit code from the receiver, then Find.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pairCodeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 482910',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: _resolving ? null : _resolveFromPairingCode,
                    child: _resolving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Find'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_uploadProgress != null)
                SenderUploadBanner(progress: _uploadProgress!),
              FilledButton(
                onPressed: _sending ? null : _sendAll,
                child: _sending
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Send files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
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
                  color: theme.colorScheme.primary.withOpacity(0.14),
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
                'Photos, videos, documents — any file type.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.62),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text('Choose files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendInfoSheet extends StatelessWidget {
  const _SendInfoSheet({
    required this.myIp,
    required this.receiverAddress,
    required this.pairCode,
  });

  final String? myIp;
  final String receiverAddress;
  final String pairCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Network info',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How the two devices find each other on your Wi‑Fi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'This device (sender)',
            value: myIp ?? 'Not on Wi‑Fi',
            canCopy: myIp != null,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Receiver address',
            value: receiverAddress.isEmpty ? 'Not set' : receiverAddress,
            canCopy: receiverAddress.isNotEmpty,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Pairing code',
            value: pairCode.isEmpty ? '—' : pairCode,
            canCopy: pairCode.isNotEmpty,
          ),
          const SizedBox(height: 16),
          Text(
            'If devices can\'t see each other, check both are on the same Wi‑Fi and that the router isn\'t isolating clients (often called "AP isolation" or "guest network").',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.canCopy = false,
  });

  final String label;
  final String value;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (canCopy)
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
