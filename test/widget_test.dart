import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

void main() {
  testWidgets('Login screen smoke test and elements verification',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify header title "Yalt" exists
    expect(find.text('Yalt'), findsOneWidget);

    // Verify input placeholders
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify eye icon toggle exists and toggles
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Test Admin Login
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'faiz@yalt.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'ayamgoreng');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // Verify text "Kamu adalah Admin"
    expect(find.text('Kamu adalah Admin'), findsOneWidget);
  });

  testWidgets('User login test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Test User Login
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'faiz@gmail.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'ayamgoreng');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    // Verify text "Kamu adalah User"
    expect(find.text('Kamu adalah User'), findsOneWidget);
  });
}
