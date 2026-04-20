import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/app_settings.dart';
import 'theme/app_theme.dart';

class PinnacleApp extends StatelessWidget {
  const PinnacleApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'Pinnacle',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
