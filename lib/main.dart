import 'package:flutter/material.dart';

import 'pinnacle_app.dart';
import 'state/app_settings.dart';

/// Run `setup_platforms.sh` once to generate `android/` and `ios/` if missing,
/// then `flutter pub get` and `flutter run`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PinnacleApp(settings: settings));
}
