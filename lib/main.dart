import 'package:flutter/material.dart';

import 'pinnacle_app.dart';

/// Run `setup_platforms.sh` once to generate `android/` and `ios/` if missing, then `flutter pub get` and `flutter run`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PinnacleApp());
}
