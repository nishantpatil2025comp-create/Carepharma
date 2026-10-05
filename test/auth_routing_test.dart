import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/auth_service.dart';
import 'package:carepharma/models/user_profile.dart';
import 'package:carepharma/services/auth_routing_service.dart';
import 'package:carepharma/screens/inventory_screen.dart';
import 'package:carepharma/screens/pharmacy/add_pharmacy_screen.dart';
import 'package:carepharma/screens/customer/user_onboarding_screen.dart';
import 'package:carepharma/screens/customer/customer_home_screen.dart';

void main() {
  setUp(() {
    AuthService.resetMockState();
  });

  group('AuthRoutingService Unit Tests', () {
    final authService = const AuthService();
    final router = AuthRoutingService(authService: authService);

    test('Pharmacist flow: New pharmacist routes to AddPharmacyScreen', () async {
      final screen = await router.resolveDestinationScreen(
        preferredRole: 'pharmacist',
        email: 'new.pharmacist.store@gmail.com',
      );

      expect(screen, isA<AddPharmacyScreen>());
      final addPharmacyScreen = screen as AddPharmacyScreen;
      expect(addPharmacyScreen.initialEmail, equals('new.pharmacist.store@gmail.com'));
      expect(addPharmacyScreen.redirectToDashboard, isTrue);
    });

    test('Pharmacist flow: Existing pharmacist routes straight to InventoryScreen', () async {
      // pharmacist@apollomeds.com is pre-registered in mock state
      final screen = await router.resolveDestinationScreen(
        preferredRole: 'pharmacist',
        email: 'pharmacist@apollomeds.com',
      );

      expect(screen, isA<InventoryScreen>());
    });

    test('Pharmacist flow: Newly registered pharmacy flips checkPharmacyExists to true', () async {
      const email = 'dr.patel.chemist@carepharma.com';
      expect(await authService.checkPharmacyExists(email: email), isFalse);

      authService.markPharmacyRegistered(email);

      expect(await authService.checkPharmacyExists(email: email), isTrue);

      final screen = await router.resolveDestinationScreen(
        preferredRole: 'pharmacist',
        email: email,
      );
      expect(screen, isA<InventoryScreen>());
    });

    test('User/Patient flow: New user routes to UserOnboardingScreen', () async {
      final screen = await router.resolveDestinationScreen(
        preferredRole: 'user',
        email: 'new.patient.anita@gmail.com',
      );

      expect(screen, isA<UserOnboardingScreen>());
      final onboardingScreen = screen as UserOnboardingScreen;
      expect(onboardingScreen.initialEmail, equals('new.patient.anita@gmail.com'));
    });

    test('User/Patient flow: Existing user with complete profile routes to CustomerHomeScreen', () async {
      // rahul.mehta@example.com is pre-configured with a complete profile in mock state
      final screen = await router.resolveDestinationScreen(
        preferredRole: 'user',
        email: 'rahul.mehta@example.com',
      );

      expect(screen, isA<CustomerHomeScreen>());
    });

    test('User/Patient flow: Completing profile updates isUserProfileComplete and routes to CustomerHomeScreen', () async {
      const email = 'priya.sharma@example.com';
      expect(await authService.isUserProfileComplete(email: email), isFalse);

      // Save user profile
      await authService.saveUserProfile(const UserProfile(
        id: 'mock_priya_101',
        email: email,
        role: 'user',
        fullName: 'Priya Sharma',
        phone: '+91 98765 43210',
        deliveryAddress: 'Flat 402, Green Glen Layout, Bellandur, Bengaluru',
        isProfileCompleted: true,
      ));

      expect(await authService.isUserProfileComplete(email: email), isTrue);

      final screen = await router.resolveDestinationScreen(
        preferredRole: 'user',
        email: email,
      );
      expect(screen, isA<CustomerHomeScreen>());
    });

    test('Unspecified role: Prompts user with RoleSelectionPromptScreen', () async {
      final screen = await router.resolveDestinationScreen(
        preferredRole: null,
        email: 'undecided@example.com',
      );

      expect(screen, isA<RoleSelectionPromptScreen>());
    });
  });

  group('UserOnboardingScreen Widget Tests', () {
    testWidgets('Renders onboarding form and submits profile successfully', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authService = const AuthService();
      const testEmail = 'onboarding.test@example.com';

      await tester.pumpWidget(MaterialApp(
        home: UserOnboardingScreen(
          authService: authService,
          initialEmail: testEmail,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Patient Profile Setup'), findsOneWidget);

      // Fill in Name
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Aditi Sharma',
      );

      // Fill in Phone
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '9876543210',
      );

      // Fill in Address
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Flat 12, Sunrise Residency, Karvenagar',
      );

      // Fill in City & PIN
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Pune - 411052',
      );

      // Tap Complete Setup button
      final submitButton = find.text('Save Profile & Start Shopping');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify that profile is now marked complete in authService
      final isComplete = await authService.isUserProfileComplete(email: testEmail);
      expect(isComplete, isTrue);

      // Verify profile data was persisted
      final profile = await authService.getUserProfile(email: testEmail);
      expect(profile, isNotNull);
      expect(profile?.fullName, equals('Aditi Sharma'));
      expect(profile?.phone, equals('9876543210'));
    });
  });

  group('RoleSelectionPromptScreen Widget Tests', () {
    testWidgets('Displays options for User and Pharmacist', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: RoleSelectionPromptScreen(
          authService: AuthService(),
          email: 'prompt.test@example.com',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Select Account Role'), findsOneWidget);
      expect(find.text('Patient / Customer'), findsOneWidget);
      expect(find.text('Pharmacist / Store Partner'), findsOneWidget);
    });
  });
}
