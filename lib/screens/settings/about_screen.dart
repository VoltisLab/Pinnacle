import 'package:flutter/material.dart';

import '../../widgets/mesh_gradient_background.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                margin: const EdgeInsets.only(top: 8, bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Center(
              child: Text(
                'Pinnacle',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Version 1.0.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_rounded),
                    title: const Text('Privacy'),
                    subtitle: const Text(
                      'Files move directly between your devices on the local network.',
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: const Text('Licenses'),
                    subtitle: const Text('Open source components used by Pinnacle'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Pinnacle',
                      applicationVersion: '1.0.0',
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
