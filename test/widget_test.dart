import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/main.dart';

void main() {
  testWidgets('CarePharmaApp navigates User & Pharmacist OTP login flows to blank success screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CarePharmaApp());
    await tester.pumpAndSettle();

    // 1. Initial screen has User and Pharmacist options
    expect(find.text('CarePharma'), findsOneWidget);
    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Pharmacist'), findsOneWidget);

    // 2. Select "Login as User"
    await tester.tap(find.text('Login as User'));
    await tester.pumpAndSettle();

    expect(find.text('User Login'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);

    // 3. Back returns to role selection
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Pharmacist'), findsOneWidget);

    // 4. Select "Login as Pharmacist"
    await tester.tap(find.text('Login as Pharmacist'));
    await tester.pumpAndSettle();

    expect(find.text('Pharmacist Login'), findsOneWidget);

    // Enter email
    await tester.enterText(find.byType(TextField), 'chemist@apollomeds.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    // Verify step 2 (OTP code input) is displayed
    expect(find.text('Enter OTP Code'), findsOneWidget);
    expect(find.text('OTP Code'), findsOneWidget);
    expect(find.text('Verify OTP'), findsOneWidget);

    // Enter OTP
    await tester.enterText(find.widgetWithText(TextField, 'Enter 6-digit code'), '123456');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    // 5. Lands on Blank Success Screen
    expect(find.text('Login Successful!'), findsOneWidget);
    expect(find.text('Welcome, Pharmacist'), findsOneWidget);
    expect(find.text('chemist@apollomeds.com'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    // 6. Tapping Sign Out returns to Role Selection Screen
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Pharmacist'), findsOneWidget);
  });
}



