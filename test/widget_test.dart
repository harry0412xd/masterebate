// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masterebate/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Provide mocked prefs
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(prefs: prefs));

    // Verify that the Home Screen tabs are present
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);

    // Ensure no exceptions during basic interaction: open menu and close
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Add Card'), findsOneWidget);
    await tester.tap(find.text('Add Card'));
    await tester.pumpAndSettle();
    // Cancel the dialog instead of interacting further
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
  });
}
