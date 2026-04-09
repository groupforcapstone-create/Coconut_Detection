// This is a Flutter widget test for Coconut App.
//
// It verifies that the main tabs (Home, Camera, Settings) display correctly
// and that the app title is present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_app/main.dart';

void main() {
  testWidgets('Coconut App loads with Home, Camera, Settings tabs', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Verify the app title is shown in AppBar
    expect(find.text('Coconut Detection App'), findsOneWidget);

    // Verify that Home tab is displayed by default
    expect(find.text('Home Page'), findsOneWidget);
    expect(find.text('Camera Page'), findsNothing);
    expect(find.text('Settings Page'), findsNothing);

    // Tap on Camera tab
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();

    // Verify Camera page is displayed
    expect(find.text('Camera Page'), findsOneWidget);
    expect(find.text('Home Page'), findsNothing);
    expect(find.text('Settings Page'), findsNothing);

    // Tap on Settings tab
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify Settings page is displayed
    expect(find.text('Settings Page'), findsOneWidget);
    expect(find.text('Home Page'), findsNothing);
    expect(find.text('Camera Page'), findsNothing);
  });
}
