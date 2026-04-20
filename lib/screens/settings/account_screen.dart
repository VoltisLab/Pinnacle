import 'package:flutter/material.dart';

import '../../services/pinnacle_google_auth.dart';
import '../../state/app_settings.dart';
import '../../widgets/mesh_gradient_background.dart';
import '../auth/sign_in_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _googleSignIn(AppSettings settings) async {
    if (!pinnacleGoogleSignInConfigured()) {
      _snack(
        'Google sign-in is not configured on this build. Provide '
        'GOOGLE_WEB_CLIENT_ID (and iOS client ID) at build time.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final email = await pinnacleGoogleSignInEmail();
      if (email != null) {
        await settings.setAccountEmail(email);
        _snack('Signed in as $email');
      } else {
        _snack('Sign-in cancelled');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut(AppSettings settings) async {
    await settings.setAccountEmail(null);
    _snack('Signed out');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppSettingsScope.of(context);
    final email = settings.accountEmail;

    return MeshGradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ProfileCard(email: email),
            const SizedBox(height: 18),
            if (email == null) ...[
              Text(
                'SIGN IN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email_rounded),
                      title: const Text('Sign in with email'),
                      subtitle: const Text('Create or access your Pinnacle account'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SignInScreen(),
                                ),
                              ),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.login_rounded),
                      title: const Text('Continue with Google'),
                      subtitle: const Text('Fastest way in if you already use Google'),
                      trailing: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : () => _googleSignIn(settings),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'SESSION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.verified_user_rounded),
                      title: Text(email),
                      subtitle: const Text('Signed in — all settings sync locally'),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      onTap: _busy ? null : () => _signOut(settings),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Pinnacle never uploads your files to our servers — signing in only personalises the app.',
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
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        (email == null || email!.isEmpty) ? '?' : email![0].toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email ?? 'Guest',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email == null
                        ? 'Sign in to name this device and save preferences.'
                        : 'Syncing settings locally on this device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.62),
                      height: 1.35,
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
