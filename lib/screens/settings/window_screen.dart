import 'package:flutter/material.dart';

import '../../services/desktop_window.dart';
import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';

/// Desktop-only window preferences. Mobile builds never reach this screen
/// because the Settings hub only shows the entry when [isDesktop] is true.
class WindowScreen extends StatelessWidget {
  const WindowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Window')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Control how the Pinnacle window behaves on your desktop.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile.adaptive(
                secondary: Icon(
                  Icons.push_pin_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Always on top'),
                subtitle: const Text(
                  'Keep Pinnacle floating above other windows.',
                ),
                value: settings.alwaysOnTop,
                onChanged: (v) async {
                  await settings.setAlwaysOnTop(v);
                  await setAlwaysOnTop(v);
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.crop_square_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Window size'),
                subtitle: const Text(
                  'Fixed 720 × 880 — sized so Send and Receive pages fit '
                  'without scrolling.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
