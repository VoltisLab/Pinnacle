import 'package:flutter/material.dart';

import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Control how Pinnacle talks to you while running in the background.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    value: settings.notifyOnReceive,
                    onChanged: settings.setNotifyOnReceive,
                    title: const Text('Notify on receive'),
                    subtitle: const Text(
                      'Show a small snackbar/toast when a file lands.',
                    ),
                  ),
                  const Divider(height: 0),
                  SwitchListTile(
                    value: settings.autoStartReceive,
                    onChanged: settings.setAutoStartReceive,
                    title: const Text('Auto-start receive'),
                    subtitle: const Text(
                      'Begin listening as soon as the Receive screen opens.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
