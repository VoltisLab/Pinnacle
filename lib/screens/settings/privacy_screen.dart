import 'package:flutter/material.dart';

import '../../widgets/mesh_gradient_background.dart';

/// Static Privacy Policy page. The content is deliberately plain-English
/// and reflects how the app actually works today: peer-to-peer transfers
/// over the local network, no cloud storage, nothing phoned home.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Privacy Policy')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Center(
              child: Text(
                'Privacy Policy',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Last updated · April 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Section(
              title: 'Summary',
              body:
                  'Pinnacle transfers files directly between your devices on '
                  'the same local network. Your files do not pass through '
                  'our servers, and we do not collect analytics or tracking '
                  'data about how you use the app.',
            ),
            _Section(
              title: 'What stays on your device',
              body:
                  '• The files you choose to send or the files you receive.\n'
                  '• Your preferences (theme, save location, notification '
                  'settings, window behaviour).\n'
                  '• A small rotating crash log that helps us diagnose '
                  'issues you report to us. It lives only on your device '
                  'and is never uploaded automatically.',
            ),
            _Section(
              title: 'What leaves your device',
              body:
                  'While a transfer is active, the bytes of the files you '
                  'explicitly select travel over your local Wi‑Fi directly '
                  'to the receiving device. They do not go through any '
                  'third‑party server or cloud service operated by us.',
            ),
            _Section(
              title: 'Pairing and discovery',
              body:
                  'To connect two devices, the receiver advertises itself on '
                  'the local network (mDNS / Bonjour) and shows a 6‑digit '
                  'pairing code plus an optional QR code. This advertisement '
                  'is visible only to devices on the same Wi‑Fi. It is '
                  'torn down as soon as you leave the Receive screen.',
            ),
            _Section(
              title: 'Accounts (optional)',
              body:
                  'If you choose to sign in, the email address you provide '
                  'is stored locally so the app can remember you next time. '
                  'Signing in is not required to send or receive files.',
            ),
            _Section(
              title: 'Permissions',
              body:
                  'The app may ask for access to your camera (to scan QR '
                  'codes), local network (to find the other device) and '
                  'storage (to save incoming files). Each permission is '
                  'used only for the feature it names and can be revoked '
                  'at any time from your operating system settings.',
            ),
            _Section(
              title: 'Children',
              body:
                  'Pinnacle is a general‑audience utility. It does not '
                  'knowingly collect any information from children.',
            ),
            _Section(
              title: 'Changes to this policy',
              body:
                  'If we materially change how the app handles data, the '
                  'updated policy will appear here with a new "last '
                  'updated" date. We encourage you to check back after app '
                  'updates.',
            ),
            _Section(
              title: 'Contact',
              body:
                  'Questions or concerns? Email privacy@voltislab.com and '
                  'we will get back to you.',
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '© Voltis Lab · Pinnacle',
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
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.78),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
