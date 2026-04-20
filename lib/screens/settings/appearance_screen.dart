import 'package:flutter/material.dart';

import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';

/// Lets the user pick System / Light / Dark. Changes apply immediately
/// because [MaterialApp] is wired to [AppSettings.themeMode].
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);

    Widget row(ThemeMode mode, String title, String desc, IconData icon) {
      final selected = settings.themeMode == mode;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => settings.setThemeMode(mode),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.primary.withOpacity(0.14),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.62),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.25),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Appearance')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _HeaderBlurb(),
            const SizedBox(height: 12),
            row(
              ThemeMode.system,
              'Match system',
              'Follow your device setting — switches automatically at night.',
              Icons.brightness_auto_rounded,
            ),
            row(
              ThemeMode.light,
              'Light',
              'Warm paper background, inked text.',
              Icons.wb_sunny_rounded,
            ),
            row(
              ThemeMode.dark,
              'Dark',
              'Charcoal surfaces, warm gold accent.',
              Icons.nightlight_round,
            ),
            const SizedBox(height: 16),
            _LivePreview(current: settings.themeMode),
          ],
        ),
      ),
    );
  }
}

class _HeaderBlurb extends StatelessWidget {
  const _HeaderBlurb();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Pinnacle ships with a warm-gold accent that reads well on both light and dark. Pick your vibe — the rest of the app updates live.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.72),
        height: 1.4,
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.primary.withOpacity(0.16),
                  ),
                  child: Icon(Icons.send_rounded,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send files',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accent, text, and surfaces update together.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: 0.62,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Send')),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Receive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
