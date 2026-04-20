import 'package:flutter/material.dart';

import 'pinnacle_app.dart';
import 'services/crash_log.dart';
import 'services/desktop_window.dart';
import 'state/app_settings.dart';

/// Entry point. Initialises persisted settings, pins the desktop window to
/// a fixed square (no-op on mobile), and hands off to [PinnacleApp]. The
/// whole app runs inside [runGuardedApp] so any uncaught Dart error (sync
/// or from a stray Future) lands in a rotating crash log on disk instead
/// of silently terminating the native process.
Future<void> main() async {
  await runGuardedApp(() async {
    final settings = await AppSettings.load();
    await applyDesktopWindowPolicy(alwaysOnTop: settings.alwaysOnTop);
    runApp(PinnacleApp(settings: settings));
  });
}
