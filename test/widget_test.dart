// Basic Flutter widget test for Adhan App

import 'package:flutter_test/flutter_test.dart';

import 'package:adhan_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AdhanApp());

    // Verify that the app loads (basic smoke test)
    // We just check that it doesn't crash
    expect(find.byType(AdhanApp), findsOneWidget);
  });
}
