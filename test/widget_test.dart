import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/main.dart';
import 'package:carepharma/screens/inventory_screen.dart';
import 'package:carepharma/models/medicine.dart';
import 'package:carepharma/services/medicine_service.dart';

/// Test implementation of IMedicineService for deterministic widget testing.
class TestMedicineService implements IMedicineService {
  TestMedicineService({List<Medicine>? initialMedicines})
      : _medicines = initialMedicines ??
            [
              const Medicine(
                uid: 'MED-ID-8001',
                name: 'Amoxyclav 625 Generic IP',
                priceInr: 73.50,
                type: 'Tablet',
                stock: 142,
                manufacturer: 'Cipla Ltd',
                expiryDate: '2026-10-31',
                pharmacyUid: 'mock_pharmacy_uid',
              ),
              const Medicine(
                uid: 'MED-ID-8002',
                name: 'Metformin 500mg SR',
                priceInr: 18.00,
                type: 'Tablet',
                stock: 8,
                manufacturer: 'Sun Pharma',
                expiryDate: '2025-12-31',
                pharmacyUid: 'mock_pharmacy_uid',
              ),
              const Medicine(
                uid: 'MED-ID-8003',
                name: 'Cough Syrup DX',
                priceInr: 85.00,
                type: 'Syrup',
                stock: 0,
                manufacturer: 'Pfizer',
                expiryDate: '2027-05-15',
                pharmacyUid: 'mock_pharmacy_uid',
              ),
            ];

  final List<Medicine> _medicines;

  @override
  Future<String?> getPharmacyUid() async => 'mock_pharmacy_uid';

  @override
  Future<List<Medicine>> fetchMedicines({String? pharmacyUid}) async {
    return List.from(_medicines);
  }

  @override
  Future<Medicine> createMedicine(Medicine medicine) async {
    final created = medicine.copyWith(
      uid: 'MED-ID-${_medicines.length + 8001}',
      pharmacyUid: 'mock_pharmacy_uid',
    );
    _medicines.insert(0, created);
    return created;
  }

  @override
  Future<Medicine> updateMedicine(Medicine medicine) async {
    final idx = _medicines.indexWhere((m) => m.uid == medicine.uid);
    if (idx != -1) {
      _medicines[idx] = medicine;
    }
    return medicine;
  }

  @override
  Future<void> deleteMedicine(String uid) async {
    _medicines.removeWhere((m) => m.uid == uid);
  }

  @override
  Future<List<Medicine>> fetchCustomerMedicines({String? query, String? genericSalt}) async {
    var list = List<Medicine>.from(_medicines);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((m) =>
        m.name.toLowerCase().contains(q) ||
        (m.genericSalt?.toLowerCase().contains(q) ?? false) ||
        m.type.toLowerCase().contains(q)
      ).toList();
    }
    if (genericSalt != null && genericSalt.trim().isNotEmpty) {
      final s = genericSalt.trim().toLowerCase();
      list = list.where((m) => m.genericSalt?.toLowerCase().contains(s) ?? false).toList();
    }
    return list;
  }
}

void main() {
  testWidgets('User login navigates to BlankSuccessScreen, Pharmacist login navigates to InventoryScreen with full CRUD',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testMedicineService = TestMedicineService();

    await tester.pumpWidget(CarePharmaApp(
      medicineService: testMedicineService,
      useDualRoleRouting: false,
    ));
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

    // Enter user email and OTP
    await tester.enterText(find.byType(TextField), 'patient@carepharma.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter OTP Code'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Enter 6-digit code'), '123456');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    // User lands on BlankSuccessScreen
    expect(find.text('Login Successful!'), findsOneWidget);
    expect(find.text('Welcome, User'), findsOneWidget);
    expect(find.text('patient@carepharma.com'), findsOneWidget);

    // Sign out to return to Role Selection
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Pharmacist'), findsOneWidget);

    // 3. Select "Login as Pharmacist"
    await tester.tap(find.text('Login as Pharmacist'));
    await tester.pumpAndSettle();

    expect(find.text('Pharmacist Login'), findsOneWidget);

    // Enter pharmacist email and OTP
    await tester.enterText(find.byType(TextField), 'pharmacist@apollomeds.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter OTP Code'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Enter 6-digit code'), '123456');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    // 4. Lands directly on InventoryScreen!
    expect(find.byType(InventoryScreen), findsOneWidget);
    expect(find.text('Apollo Meds & Wellness'), findsOneWidget);
    expect(find.text('Generic Inventory & Stock Control'), findsOneWidget);
    expect(find.text('Total SKUs'), findsOneWidget);
    expect(find.text('Low Stock'), findsWidgets);

    // Verify medicines are loaded from service
    expect(find.text('Amoxyclav 625 Generic IP'), findsOneWidget);
    expect(find.text('Metformin 500mg SR'), findsOneWidget);
    expect(find.text('Cough Syrup DX'), findsOneWidget);

    // 5. Test Search Filtering
    await tester.enterText(
      find.widgetWithText(TextField, 'Search by brand name, salt, manufacturer...'),
      'Amoxyclav',
    );
    await tester.pumpAndSettle();

    expect(find.text('Amoxyclav 625 Generic IP'), findsOneWidget);
    expect(find.text('Metformin 500mg SR'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Metformin 500mg SR'), findsOneWidget);

    // 6. Test Quick Restock (+10 units)
    expect(find.text('142 units'), findsOneWidget);
    await tester.tap(find.text('+10').first);
    await tester.pumpAndSettle();
    expect(find.text('152 units'), findsOneWidget);

    // 7. Test Add Medicine Modal Dialog
    await tester.tap(find.text('Add Medicine'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Medicine'), findsOneWidget);
    expect(find.text('Medicine Name *'), findsOneWidget);

    // Fill form
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Amoxyclav 625 Generic IP'),
      'Paracetamol 650mg Generic',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '0.00'),
      '15.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. 100'),
      '250',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'YYYY-MM-DD or MM/YYYY'),
      '2026-12-31',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Cipla Ltd, Sun Pharma, Mankind'),
      'Mankind Pharma',
    );

    // Submit dialog
    await tester.tap(find.text('Save Medicine'));
    await tester.pumpAndSettle();

    // Verify newly added medicine appears in inventory
    expect(find.text('Paracetamol 650mg Generic'), findsOneWidget);
    expect(find.text('₹15.50'), findsOneWidget);

    // 8. Test Delete Medicine with Confirmation Dialog
    // Find delete icon for Cough Syrup DX
    final deleteIcons = find.byIcon(Icons.delete_outline);
    await tester.tap(deleteIcons.last);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete Medicine'), findsOneWidget);
    expect(find.text('Are you sure you want to delete "Cough Syrup DX" from the inventory?\n\nThis will permanently remove the record from Supabase.'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify Cough Syrup DX is removed
    expect(find.text('Cough Syrup DX'), findsNothing);

    // 9. Sign out from InventoryScreen
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Login as User'), findsOneWidget);
    expect(find.text('Login as Pharmacist'), findsOneWidget);
  });

  testWidgets('InventoryScreen renders without layout overflow on narrow mobile screens (360x640)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testService = TestMedicineService();
    await tester.pumpWidget(MaterialApp(
      home: InventoryScreen(medicineService: testService),
    ));
    await tester.pumpAndSettle();

    // Verify AppBar and Header rendered
    expect(find.text('Apollo Meds & Wellness'), findsOneWidget);
    expect(find.text('Generic Inventory & Stock Control'), findsOneWidget);
    expect(find.text('Total SKUs'), findsOneWidget);
    expect(find.text('Low Stock'), findsNWidgets(2));
    expect(find.text('Active Generics'), findsOneWidget);

    // Verify cards rendered
    expect(find.text('Amoxyclav 625 Generic IP'), findsOneWidget);
    expect(find.text('Metformin 500mg SR'), findsOneWidget);

    // Open Add Medicine dialog on narrow screen
    await tester.tap(find.text('Add Medicine'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Medicine'), findsOneWidget);
    expect(find.text('Save Medicine'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Generic Inventory & Stock Control'), findsOneWidget);
  });
}

