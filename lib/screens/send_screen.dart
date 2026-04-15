import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/transfer_client.dart';
import '../widgets/mesh_gradient_background.dart';
import 'qr_scan_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _addressCtrl = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _sending = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
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

  Future<void> _scan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera access is needed to scan QR codes.')),
      );
      return;
    }
    if (!mounted) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    setState(() => _addressCtrl.text = _normalizeScanned(raw));
  }

  String _normalizeScanned(String raw) {
    final t = raw.trim();
    if (t.contains('://')) return t;
    return 'http://$t';
  }

  String? _baseUrl() {
    var s = _addressCtrl.text.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.parse(s);
    if (!u.hasAuthority) return null;
    return u.replace(path: '', query: '', fragment: '').toString().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _sendAll() async {
    final base = _baseUrl();
    if (base == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid receive address.')),
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
        await TransferClient.sendFile(base, path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer complete')),
      );
    } on TransferException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
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
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                'Receiver address',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste the URL from the other phone or scan its QR code.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.12:54321',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Scan QR'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'Files',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _pickFiles,
                    child: const Text('Choose files'),
                  ),
                ],
              ),
              if (_files.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No files selected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ),
                )
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
                        f.size > 0 ? '${fmt.format(f.size)} bytes' : 'Size unknown',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                      leading: Icon(
                        Icons.insert_drive_file_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
