import 'package:flutter_test/flutter_test.dart';
import 'package:pinnacle/pinnacle_app.dart';

void main() {
  testWidgets('Pinnacle home loads', (tester) async {
    await tester.pumpWidget(const PinnacleApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Pinnacle'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });
}
