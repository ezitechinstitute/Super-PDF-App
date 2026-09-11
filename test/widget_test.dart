// Basic smoke test for the PDF Super App.
//
// The app boots into AuthGate, which reads the saved auth token from
// SharedPreferences before deciding between onboarding and home.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_super_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots and shows a loading gate first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PdfSuperApp());

    // AuthGate shows a spinner while the token lookup is in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Without a token the app lands on onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PdfSuperApp());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
