import 'package:flutter/material.dart';

import 'pinnacle_app.dart';
import 'services/desktop_window.dart';
import 'state/app_settings.dart';

/// Entry point. Initialises persisted settings, pins the desktop window to
/// a fixed square (no-op on mobile), and hands off to [PinnacleApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  await applyDesktopWindowPolicy(alwaysOnTop: settings.alwaysOnTop);
  runApp(PinnacleApp(settings: settings));
}
