// This is a basic Flutter widget test for Ahwal App.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('Ahwal App basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AhwalApp());

    // Wait for splash screen
    await tester.pump();
    
    // Verify that the app loads with basic elements
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Wait for splash screen to finish and navigate to main screen
    await tester.pumpAndSettle(const Duration(seconds: 4));
    
    // Now check if the main navigation is loaded
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
