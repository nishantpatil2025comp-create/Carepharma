import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/theme/app_theme.dart';
import 'package:carepharma/screens/pharmacy/pharmacist_inventory_screen.dart';
import 'package:carepharma/screens/pharmacy/add_pharmacy_screen.dart';
import 'package:carepharma/screens/customer/nearby_pharmacies_screen.dart';
import 'package:carepharma/screens/customer/generic_alternatives_screen.dart';
import 'package:carepharma/screens/inventory_screen.dart';
import 'package:carepharma/screens/customer/medicine_search_screen.dart';
import 'package:carepharma/screens/customer/real_nearby_pharmacies_screen.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

void main() {
  group('CarePharma Responsive Layout & New Feature Screens Tests', () {
    testWidgets('PharmacistInventoryScreen renders without overflow on narrow 360x640 viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const PharmacistInventoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('My Pharmacy Inventory'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PharmacistInventoryScreen filters locally in real-time matching brand name & generic salt', (tester) async {
      await tester.pumpWidget(_buildTestApp(const PharmacistInventoryScreen()));
      await tester.pumpAndSettle();

      // Initially shows medicines
      expect(find.textContaining('Amoxyclav 625 Generic IP'), findsOneWidget);
      expect(find.textContaining('Metformin 500mg SR'), findsOneWidget);

      // Search by brand name
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Metformin');
      await tester.pumpAndSettle();

      expect(find.textContaining('Metformin 500mg SR'), findsOneWidget);
      expect(find.textContaining('Amoxyclav 625 Generic IP'), findsNothing);

      // Search by generic salt composition
      await tester.enterText(searchField, 'Amoxicillin');
      await tester.pumpAndSettle();

      expect(find.textContaining('Amoxyclav 625 Generic IP'), findsOneWidget);
      expect(find.textContaining('Metformin 500mg SR'), findsNothing);

      // Search non-existing
      await tester.enterText(searchField, 'NonExistentMedicineXyz');
      await tester.pumpAndSettle();
      expect(find.text('No medicines match "NonExistentMedicineXyz".'), findsOneWidget);
    });

    testWidgets('AddPharmacyScreen renders without overflow on narrow 360x640 viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const AddPharmacyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Register New Pharmacy'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddPharmacyScreen validates required inputs on submit', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const AddPharmacyScreen()));
      await tester.pumpAndSettle();

      // Clear default suggested UID
      final uidField = find.byType(TextFormField).first;
      await tester.enterText(uidField, '');
      await tester.pumpAndSettle();

      // Tap submit with empty form -> triggers validators
      final submitButton = find.text('Save & Register Pharmacy');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Form validation triggers
      expect(find.text('Please enter a unique UID'), findsOneWidget);
      expect(find.text('Please enter the pharmacy name'), findsOneWidget);
      expect(find.text('Please enter the location'), findsOneWidget);
    });

    testWidgets('NearbyPharmaciesScreen renders without overflow and displays proximity list', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const NearbyPharmaciesScreen()));
      // Allow location check timeout to resolve
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Pharmacies'), findsOneWidget);
      expect(find.textContaining('Register Store'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GenericAlternativesScreen renders without overflow and groups by active salt molecule', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const GenericAlternativesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Generic Salt & Alternatives'), findsOneWidget);
      expect(find.textContaining('Paracetamol'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Filter by salt name
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Metformin');
      await tester.pumpAndSettle();

      expect(find.textContaining('Metformin'), findsWidgets);
      expect(find.textContaining('Paracetamol / Acetaminophen 650mg'), findsNothing);
    });

    testWidgets('InventoryScreen real-time search filters by generic salt', (tester) async {
      await tester.pumpWidget(_buildTestApp(const InventoryScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter generic salt 'Amoxicillin'
      await tester.enterText(searchField, 'Amoxicillin');
      await tester.pumpAndSettle();

      expect(find.textContaining('Amoxyclav 625 Generic IP'), findsOneWidget);
    });

    testWidgets('MedicineSearchScreen renders query-only UI without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const MedicineSearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Search Medicines & Salts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RealNearbyPharmaciesScreen renders GPS proximity list without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildTestApp(const RealNearbyPharmaciesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Pharmacies'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
