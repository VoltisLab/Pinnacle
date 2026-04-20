import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';

/// Where received files land. Users can pick from a few common folder names
/// or type their own. We don't expose an arbitrary-path file picker because
/// Android scoped storage (API 29+) only lets us write into Downloads
/// subfolders via MediaStore anyway.
class SaveLocationScreen extends StatefulWidget {
  const SaveLocationScreen({super.key});

  @override
  State<SaveLocationScreen> createState() => _SaveLocationScreenState();
}

class _SaveLocationScreenState extends State<SaveLocationScreen> {
  late final TextEditingController _ctrl;
  late String _current;

  static const List<String> _presets = [
    'Pinnacle',
    'Transfers',
    'AirDrop',
    'Shared',
    'Downloads',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppSettingsScope.of(context);
    _current = settings.saveFolderName;
    if (_ctrl.text.isEmpty) {
      _ctrl.text = _current;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply(String name, AppSettings settings) async {
    await settings.setSaveFolderName(name);
    if (!mounted) return;
    setState(() => _current = settings.saveFolderName);
    _ctrl.text = settings.saveFolderName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saving to "${settings.saveFolderName}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Save location')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              _pathHint(_current),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Folder name',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[\\/:*?"<>|]'),
                        ),
                        LengthLimitingTextInputFormatter(40),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'e.g. Pinnacle',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => _apply(_ctrl.text, settings),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'QUICK PICKS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ..._presets.map(
              (name) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: RadioListTile<String>(
                  value: name,
                  groupValue: _current,
                  title: Text(name),
                  subtitle: Text(_pathHint(name)),
                  onChanged: (v) {
                    if (v != null) _apply(v, settings);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (Platform.isIOS)
              Text(
                'On iPhone, Pinnacle saves into its own app folder that appears in Files → On My iPhone → Pinnacle. iOS does not allow apps to write arbitrary paths.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.4,
                ),
              )
            else if (Platform.isAndroid)
              Text(
                'On Android, files are published via the system Downloads library, so they appear in Files, Google Files, Gallery, etc. — no permissions required.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _pathHint(String folder) {
    if (Platform.isAndroid) return 'Downloads / $folder';
    if (Platform.isIOS) {
      return 'Files → On My iPhone → Pinnacle → $folder';
    }
    return '<user Downloads> / $folder';
  }
}
