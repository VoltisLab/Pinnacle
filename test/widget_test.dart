import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pinnacle/pinnacle_app.dart';
import 'package:pinnacle/state/app_settings.dart';

void main() {
  testWidgets('Pinnacle home loads', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PinnacleApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Pinnacle'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    // Silence unused-import lint if test setup grows:
    expect(MaterialApp, isNotNull);
  });
}
