import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/local_address.dart';
import '../services/pairing_bonjour.dart';
import '../services/pinnacle_google_auth.dart';
import '../services/pinnacle_pairing_uri.dart';
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
  final _pairCodeCtrl = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _sending = false;
  bool _resolving = false;
  String? _googleEmail;

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

  Future<void> _scan() async {
    if (runningOnIosSimulator) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Simulator has no camera. Paste the receive link or use Find by pairing code.',
          ),
        ),
      );
      return;
    }

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? 'Enable Camera for Pinnacle in Settings, then try again.'
                : 'Camera access is needed to scan QR codes.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    await _applyPayload(raw);
  }

  Future<void> _applyPayload(String raw) async {
    final trimmed = raw.trim();
    final httpUrl = httpBaseUrlFromPayload(trimmed);
    if (httpUrl != null) {
      setState(() => _addressCtrl.text = httpUrl);
      return;
    }
    final pinnacle = parsePinnacleReceiveUri(trimmed);
    if (pinnacle != null) {
      setState(() => _pairCodeCtrl.text = pinnacle.code);
      await _resolveFromPairingCode();
      return;
    }
    setState(() => _addressCtrl.text = _normalizeScanned(trimmed));
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
        const SnackBar(content: Text('Enter the 6-digit pairing code from the receiver.')),
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

  Future<void> _optionalGoogle() async {
    if (!pinnacleGoogleSignInConfigured()) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Google sign-in'),
          content: const Text(
            'Optional Google verification is enabled when you build with:\n\n'
            '--dart-define=GOOGLE_WEB_CLIENT_ID=…\n'
            '--dart-define=GOOGLE_IOS_CLIENT_ID=…\n\n'
            'Use OAuth client IDs from Google Cloud Console and add the iOS URL scheme to Xcode '
            '(see google_sign_in setup). Until then, use QR or pairing code.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final email = await pinnacleGoogleSignInEmail();
    if (!mounted) return;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in was cancelled or failed.')),
      );
    } else {
      setState(() => _googleEmail = email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as $email')),
      );
    }
  }

  String? _baseUrl() {
    var s = _addressCtrl.text.trim();
    if (s.isEmpty) return null;
    final pinnacle = parsePinnacleReceiveUri(s);
    if (pinnacle != null) {
      return null;
    }
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.parse(s);
    if (!u.hasAuthority) return null;
    return u.replace(path: '', query: '', fragment: '').toString().replaceAll(RegExp(r'/$'), '');
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
          content: Text('Enter a receive address, scan a QR, or find the receiver with a pairing code.'),
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
                'Paste the link from the receiver, scan its QR, or use a pairing code on the same Wi‑Fi.',
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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 24),
              Text(
                'Pairing code',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 20),
              Text(
                'Optional',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _optionalGoogle,
                icon: const Icon(Icons.account_circle_outlined, size: 22),
                label: const Text('Sign in with Google'),
              ),
              if (_googleEmail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Verified: $_googleEmail',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
