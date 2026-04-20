import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';
import 'notifications_screen.dart';
import 'save_location_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionHeader(title: 'Account'),
            _SettingsTile(
              icon: Icons.person_rounded,
              title: settings.isSignedIn ? 'Signed in' : 'Sign in',
              subtitle: settings.accountEmail ??
                  'Verify your identity with Google or email.',
              onTap: () => _push(context, const AccountScreen()),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Transfer'),
            _SettingsTile(
              icon: Icons.folder_copy_rounded,
              title: 'Save location',
              subtitle: _saveLocationSubtitle(settings.saveFolderName),
              onTap: () => _push(context, const SaveLocationScreen()),
            ),
            const SizedBox(height: 2),
            _SettingsTile(
              icon: Icons.notifications_active_rounded,
              title: 'Notifications',
              subtitle: settings.notifyOnReceive
                  ? 'Notify when a new file arrives'
                  : 'Silent receives',
              onTap: () => _push(context, const NotificationsScreen()),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'Appearance'),
            _SettingsTile(
              icon: Icons.palette_rounded,
              title: 'Theme',
              subtitle: _themeLabel(settings.themeMode),
              onTap: () => _push(context, const AppearanceScreen()),
            ),
            const SizedBox(height: 18),
            const _SectionHeader(title: 'About'),
            _SettingsTile(
              icon: Icons.info_rounded,
              title: 'About Pinnacle',
              subtitle: 'Version, licenses, privacy',
              onTap: () => _push(context, const AboutScreen()),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Pinnacle — wireless transfers, warmly made.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Match system';
    }
  }

  static String _saveLocationSubtitle(String folder) {
    if (Platform.isAndroid) return 'Downloads / $folder';
    if (Platform.isIOS) return 'Files → On My iPhone → Pinnacle → $folder';
    return '<Downloads> / $folder';
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.62),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
