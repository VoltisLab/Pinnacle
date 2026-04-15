import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Build with:
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com`
/// `--dart-define=GOOGLE_IOS_CLIENT_ID=yyy.apps.googleusercontent.com`
/// (iOS client from Google Cloud Console; add URL scheme / GIDClientID in Xcode per Google Sign-In docs.)
const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const String _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

bool pinnacleGoogleSignInConfigured() {
  if (kIsWeb) return false;
  if (Platform.isIOS) {
    return _webClientId.isNotEmpty && _iosClientId.isNotEmpty;
  }
  return _webClientId.isNotEmpty;
}

/// Returns signed-in email, or `null` if cancelled / not configured / failure.
Future<String?> pinnacleGoogleSignInEmail() async {
  if (!pinnacleGoogleSignInConfigured()) return null;
  try {
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? _iosClientId : null,
      serverClientId: _webClientId,
    );
    if (!GoogleSignIn.instance.supportsAuthenticate()) return null;
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    return account.email;
  } on Object {
    return null;
  }
}
