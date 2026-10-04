import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/theme/app_theme.dart';
import 'package:carepharma/screens/customer/customer_home_screen.dart';
import 'package:carepharma/screens/customer/search_results_screen.dart';
import 'package:carepharma/screens/customer/medicine_detail_screen.dart';
import 'package:carepharma/screens/customer/cart_checkout_screen.dart';
import 'package:carepharma/screens/customer/upload_prescription_screen.dart';
import 'package:carepharma/screens/customer/map_nearby_pharmacies_screen.dart';
import 'package:carepharma/screens/customer/live_order_tracking_screen.dart';
import 'package:carepharma/screens/pharmacy/pharmacy_registration_screen.dart';
import 'package:carepharma/screens/pharmacy/pharmacy_dashboard_screen.dart';
import 'package:carepharma/screens/pharmacy/pharmacy_self_delivery_screen.dart';
import 'package:carepharma/screens/auth/interactive_login_screen.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

void main() {
  group('CarePharma 12-Screen Render Tests', () {
    testWidgets('CustomerHomeScreen renders core components', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CustomerHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('DELIVER TO'), findsOneWidget);
      expect(find.text('Baner, Pune'), findsOneWidget);
      expect(find.text('Save up to 60% with generic alternatives'), findsOneWidget);
      expect(find.text('Popular Categories'), findsOneWidget);
      expect(find.text('Pharmacies Near You'), findsOneWidget);
    });

    testWidgets('SearchResultsScreen renders branded benchmark and generic substitutes', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SearchResultsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Crocin Advanced 650mg'), findsAtLeastNWidgets(1));
      expect(find.text('Identified Generic Substitutes (4)'), findsOneWidget);
      expect(find.text('Paracetamol IP 650mg (Genext)'), findsOneWidget);
      expect(find.text('TOP VALUE CHOICE'), findsOneWidget);
    });

    testWidgets('MedicineDetailScreen renders price comparison and quantity stepper', (tester) async {
      await tester.pumpWidget(_buildTestApp(const MedicineDetailScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Paracetamol IP 650mg (Genext)'), findsOneWidget);
      expect(find.text('Composition: Paracetamol IP 650mg'), findsOneWidget);
      expect(find.text('Select Quantity'), findsOneWidget);
      expect(find.text('Apollo Diagnostics & Meds'), findsOneWidget);

      // Increment quantity
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('CartCheckoutScreen renders multi-pharmacy split orders and bill summary', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CartCheckoutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cart & Checkout'), findsOneWidget);
      expect(find.text('Split Hyperlocal Fulfillment'), findsOneWidget);
      expect(find.text('Apollo Diagnostics & Meds'), findsOneWidget);
      expect(find.text('Bill Summary'), findsOneWidget);
    });

    testWidgets('UploadPrescriptionScreen renders photo actions and checklist', (tester) async {
      await tester.pumpWidget(_buildTestApp(const UploadPrescriptionScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Upload Prescription'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('From Gallery'), findsOneWidget);
      expect(find.text('Doctor Stamp'), findsOneWidget);
    });

    testWidgets('MapNearbyPharmaciesScreen renders map and pharmacy sheet', (tester) async {
      await tester.pumpWidget(_buildTestApp(const MapNearbyPharmaciesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Pharmacies'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Search this area'), findsOneWidget);
    });

    testWidgets('LiveOrderTrackingScreen renders 5-stage stepper and runner card', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LiveOrderTrackingScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Order #GM-89421'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
      expect(find.text('Ramesh Pawar'), findsOneWidget);
    });

    testWidgets('PharmacyRegistrationScreen renders multi-step onboarding', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PharmacyRegistrationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Pharmacy Registration'), findsOneWidget);
      expect(find.text('Save & Exit'), findsOneWidget);
      expect(find.text('0% COMMISSION • 60 DAYS PROMO'), findsOneWidget);
    });

    testWidgets('PharmacyDashboardScreen renders status switch and KPI cards', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PharmacyDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Apollo Meds & Wellness'), findsOneWidget);
      expect(find.text('Today\'s Orders'), findsOneWidget);
      expect(find.text('Gross Revenue'), findsOneWidget);
    });

    testWidgets('PharmacySelfDeliveryScreen renders runner dispatch', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PharmacySelfDeliveryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Delivery › #GM-89421'), findsOneWidget);
      expect(find.text('Assigned Store Runner'), findsOneWidget);
      expect(find.text('Ramesh Pawar'), findsOneWidget);
    });

    testWidgets('InteractiveLoginScreen switches between roles', (tester) async {
      await tester.pumpWidget(_buildTestApp(const InteractiveLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Login as User'), findsOneWidget);
      expect(find.text('Login as Pharmacy Admin'), findsOneWidget);

      // Tap User Login
      await tester.tap(find.text('Login as User'));
      await tester.pumpAndSettle();
      expect(find.text('User Login'), findsOneWidget);

      // Go back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Tap Pharmacy Admin
      await tester.tap(find.text('Login as Pharmacy Admin'));
      await tester.pumpAndSettle();
      expect(find.text('Pharmacy Admin Login'), findsOneWidget);
    });
  });
}
