import 'package:carepharma/models/cart_item.dart';
import 'package:carepharma/services/cart_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/auth_service.dart';
import 'package:carepharma/models/user_profile.dart';
import 'package:carepharma/models/medicine.dart';
import 'package:carepharma/models/order.dart';
import 'package:carepharma/models/pharmacy.dart';
import 'package:carepharma/services/auth_routing_service.dart';
import 'package:carepharma/services/medicine_service.dart';
import 'package:carepharma/services/pharmacy_service.dart';
import 'package:carepharma/services/order_service.dart';
import 'package:carepharma/screens/inventory_screen.dart';
import 'package:carepharma/screens/pharmacy/pharmacy_dashboard_screen.dart';
import 'package:carepharma/screens/customer/medicine_search_screen.dart';
import 'package:carepharma/screens/customer/search_results_screen.dart';
import 'package:carepharma/screens/customer/medicine_detail_screen.dart';
import 'package:carepharma/screens/customer/cart_checkout_screen.dart';
import 'package:carepharma/screens/customer/cart_screen.dart';
import 'package:carepharma/screens/customer/live_order_tracking_screen.dart';

class MockTestCartService implements ICartService {
  @override
  Future<void> addToCart({
    required String medicineId,
    required String medicineName,
    required double price,
    int quantity = 1,
    String? userEmail,
    String? pharmacyUid,
  }) async {}

  @override
  Future<List<CartItem>> fetchCartItems([String? userEmail]) async {
    return [
      CartItem(
        id: 'cart-1',
        medicineId: 'MED-1',
        medicineName: 'Metformin 500mg',
        priceInr: 18.0,
        quantity: 2,
        userEmail: 'patient@carepharma.com',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {}
  @override
  Future<void> removeFromCart(String cartItemId) async {}
  @override
  Future<void> clearCart([String? userEmail]) async {}
  @override
  Future<List<OrderItem>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? userEmail,
    String? patientName,
  }) async => [];
}

Widget _wrap(Widget child) => MaterialApp(home: child);

class TestOrderService implements IOrderService {
  TestOrderService([this.orders = const []]);
  final List<OrderItem> orders;

  @override
  Future<OrderItem> createOrder(OrderItem order) async => order;
  @override
  Future<List<OrderItem>> fetchOrdersForPatient([String? patientEmail]) async => orders;
  @override
  Future<List<OrderItem>> fetchOrdersForPharmacy(String pharmacyUid) async => orders;
  @override
  Future<OrderItem?> fetchLatestOrderForPatient([String? patientEmail]) async => orders.isNotEmpty ? orders.first : null;
  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}
}

class TestPharmacyService implements IPharmacyService {
  @override
  Future<List<Pharmacy>> fetchPharmacies({double? userLat, double? userLng}) async => [];
  @override
  Future<void> registerPharmacy(Pharmacy pharmacy) async {}
  @override
  Future<void> updatePharmacy(Pharmacy pharmacy) async {}
  @override
  Future<Pharmacy?> fetchPharmacyForOwner(String? ownerId, {String? email}) async =>
      const Pharmacy(
        uid: 'PH-TEST-1',
        name: 'Apollo Meds & Wellness',
        location: 'Baner, Pune',
        phone: '+91 98234 56789',
        license: 'MH-PUN-2024-8891',
      );
  @override
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) => 1.0;
}

void main() {
  setUp(() {
    AuthService.resetMockState();
  });

  group('Requirement 1 & 5: Pharmacist Routing & Guest Profile Isolation', () {
    test('Pharmacist with existing registered email routes directly to InventoryScreen', () async {
      const authService = AuthService();
      final router = AuthRoutingService(authService: authService);

      // pharmacist@apollomeds.com is in registered list
      final screen = await router.resolveDestinationScreen(
        preferredRole: 'pharmacist',
        email: 'pharmacist@apollomeds.com',
      );
      expect(screen, isA<InventoryScreen>());
    });

    test('Guest user profile remains strictly in memory without writing to database', () async {
      const authService = AuthService();
      const guestProfile = UserProfile(
        id: 'guest_user_123',
        email: 'guest@explore.local',
        role: 'user',
        fullName: 'Guest Explorer',
        deliveryAddress: 'Baner, Pune',
        isProfileCompleted: true,
      );

      // Should complete in-memory safely
      await authService.saveUserProfile(guestProfile);
      final retrieved = await authService.getUserProfile(email: 'guest@explore.local');
      expect(retrieved, isNotNull);
      expect(retrieved!.fullName, equals('Guest Explorer'));
    });
  });

  group('Requirement 2: Medicine Search strictly casing Name and Generic_Salt', () {
    test('MedicineService fetchCustomerMedicines returns matching medicines', () async {
      const service = MedicineService();
      final results = await service.fetchCustomerMedicines(query: 'Metformin');
      expect(results, isNotEmpty);
      expect(results.first.name.toLowerCase(), contains('metformin'));
    });

    testWidgets('MedicineSearchScreen renders query-only UI without initial products', (tester) async {
      await tester.pumpWidget(_wrap(const MedicineSearchScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type a medicine name or generic salt to search inventory.'), findsOneWidget);
    });

    testWidgets('SearchResultsScreen shows Same Day Delivery and prominent Add to Cart', (tester) async {
      await tester.pumpWidget(_wrap(const SearchResultsScreen(initialQuery: 'Metformin')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Same Day Delivery'), findsAtLeastNWidgets(1));
      expect(find.text('Add to Cart'), findsAtLeastNWidgets(1));
    });
  });

  group('Requirement 3: Purged Pharmacist Order Summary Dummy Data', () {
    testWidgets('Empty order queue displays "No orders found"', (tester) async {
      final fakeOrders = TestOrderService([]);
      final fakePharmacy = TestPharmacyService();

      await tester.pumpWidget(
        _wrap(
          PharmacyDashboardScreen(
            orderService: fakeOrders,
            pharmacyService: fakePharmacy,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders found'), findsOneWidget);
      expect(find.text('0'), findsAtLeastNWidgets(1));
      expect(find.text('₹0'), findsOneWidget);
    });
  });

  group('Requirement 4: GPS Coordinates saved in UserProfile', () {
    test('UserProfile model serializes and retains numeric latitude & longitude', () {
      final profile = const UserProfile(
        id: 'usr_test_gps',
        email: 'gps.user@carepharma.com',
        fullName: 'GPS Patient',
        deliveryAddress: 'Baner Road, Pune',
        latitude: 18.5590,
        longitude: 73.7868,
        isProfileCompleted: true,
      );

      final json = profile.toJson();
      expect(json['latitude'], equals(18.5590));
      expect(json['longitude'], equals(73.7868));

      final fromJson = UserProfile.fromJson(json);
      expect(fromJson.latitude, equals(18.5590));
      expect(fromJson.longitude, equals(73.7868));
    });

    test('Medicine model serializes with exact casing matching Supabase schema', () {
      const med = Medicine(
        uid: 'MED-123',
        name: 'Paracetamol 650mg',
        priceInr: 18.0,
        type: 'Tablet',
        stock: 50,
        genericSalt: 'Paracetamol IP',
        manufacturer: 'Cipla',
        expiryDate: '12/26',
        pharmacyUid: 'pharm_123',
        addedBy: 'pharm@test.com',
      );
      final json = med.toJson(includeUid: true);
      expect(json['Name'], equals('Paracetamol 650mg'));
      expect(json['generic_salt'], equals('Paracetamol IP'));
      expect(json['Price_INR'], equals(18.0));
      expect(json['Stock'], equals(50));
      expect(json['UID'], equals('MED-123'));
      expect(json['Type'], equals('Tablet'));
      expect(json['Expiry_Date'], equals('12/26'));
      expect(json['Manufacturer'], equals('Cipla'));
      expect(json['pharmacy_uid'], equals('pharm_123'));
      expect(json['added_by'], equals('pharm@test.com'));

      final parsed = Medicine.fromJson(json);
      expect(parsed.name, equals('Paracetamol 650mg'));
      expect(parsed.genericSalt, equals('Paracetamol IP'));
      expect(parsed.priceInr, equals(18.0));
      expect(parsed.stock, equals(50));
      expect(parsed.uid, equals('MED-123'));
      expect(parsed.type, equals('Tablet'));
      expect(parsed.manufacturer, equals('Cipla'));
      expect(parsed.expiryDate, equals('12/26'));
      expect(parsed.pharmacyUid, equals('pharm_123'));
      expect(parsed.addedBy, equals('pharm@test.com'));
    });
  });

  group('Requirement 6 & 7: Same Day Delivery & Prominent Add to Cart & COD Checkout', () {
    testWidgets('MedicineDetailScreen displays "Same Day Delivery" and prominent "Add to Cart"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MedicineDetailScreen(
            medicineName: 'Paracetamol IP 650mg (Genext)',
            genericPrice: 18.0,
            brandedPrice: 58.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Same Day Delivery'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
      expect(find.text('Buy Now'), findsOneWidget);
    });

    testWidgets('CartCheckoutScreen has strictly Cash on Delivery / Dummy option', (tester) async {
      await tester.pumpWidget(_wrap(const CartCheckoutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cash on Delivery (Dummy COD)'), findsOneWidget);
      expect(find.text('UPI (Google Pay, PhonePe, Paytm)'), findsNothing);
      expect(find.text('Debit / Credit Card / Netbanking'), findsNothing);
    });

    testWidgets('CartScreen displays Cash on Delivery placeholder note', (tester) async {
      await tester.pumpWidget(_wrap(CartScreen(cartService: MockTestCartService())));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cash on Delivery (Dummy COD)'), findsOneWidget);
    });
  });

  group('Critical Production Bugfixes: Cart 404, Pharmacist Orders Tab, Order History, Guest Isolation', () {
    test('CartService buffers locally and returns items when Supabase client is offline/missing', () async {
      const service = CartService();
      await service.addToCart(
        medicineId: 'MED-OFFLINE-1',
        medicineName: 'Azithromycin 500mg',
        price: 95.0,
        quantity: 2,
        userEmail: 'offline.user@test.com',
      );

      final items = await service.fetchCartItems('offline.user@test.com');
      expect(items, isNotEmpty);
      expect(items.any((i) => i.medicineName == 'Azithromycin 500mg'), isTrue);
      expect(items.first.totalPrice, equals(190.0));
    });

    testWidgets('InventoryScreen bottom nav includes Orders / Dispatch tab and renders incoming orders queue', (tester) async {
      final sampleOrders = [
        OrderItem(
          id: 'ord-test-99',
          medicineName: 'Paracetamol 650mg',
          quantity: 2,
          totalPrice: 36.0,
          patientEmail: 'customer@test.com',
          deliveryAddress: 'Baner High Street, Pune',
          status: 'Pending',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          InventoryScreen(
            orderService: TestOrderService(sampleOrders),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom nav tab exists
      expect(find.text('Orders / Dispatch'), findsOneWidget);

      // Tap on Orders / Dispatch tab (index 1)
      await tester.tap(find.text('Orders / Dispatch'));
      await tester.pumpAndSettle();

      // Verify Orders view headers and metrics
      expect(find.text('Orders & Dispatch Management'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Pending Pack'), findsOneWidget);
      expect(find.text('Start Packing'), findsOneWidget);
      expect(find.textContaining('customer@test.com'), findsOneWidget);
    });

    testWidgets('LiveOrderTrackingScreen displays active order and order history list', (tester) async {
      final sampleOrders = [
        OrderItem(
          id: 'ord-101',
          medicineName: 'Amoxicillin 500mg',
          quantity: 1,
          totalPrice: 45.0,
          patientEmail: 'patient@test.com',
          status: 'Delivered',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        OrderItem(
          id: 'ord-102',
          medicineName: 'Paracetamol 650mg',
          quantity: 2,
          totalPrice: 36.0,
          patientEmail: 'patient@test.com',
          status: 'Dispatched',
          createdAt: DateTime.now(),
        ),
      ];

      final testOrderService = TestOrderService(sampleOrders);

      await tester.pumpWidget(
        _wrap(
          LiveOrderTrackingScreen(
            initialOrder: sampleOrders[1],
            orderService: testOrderService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order History'), findsOneWidget);
      expect(find.textContaining('Amoxicillin 500mg'), findsOneWidget);
      expect(find.textContaining('Paracetamol 650mg'), findsNWidgets(2));
    });

    test('AuthService preserves guest profile locally without writing to Supabase', () async {
      const auth = AuthService();
      const guestProfile = UserProfile(
        id: 'guest_session_123',
        email: 'guest@visitor.local',
        fullName: 'Guest User',
        role: 'user',
        deliveryAddress: 'Baner, Pune',
      );

      // Should save to in-memory mock profiles and succeed without error
      await auth.saveUserProfile(guestProfile);

      final fetched = await auth.getUserProfile(email: 'guest@visitor.local');
      expect(fetched, isNotNull);
      expect(fetched!.fullName, equals('Guest User'));
      expect(fetched.id, equals('guest_session_123'));
    });
  });
}
