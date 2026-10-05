import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/models/order.dart';
import 'package:carepharma/models/pharmacy.dart';
import 'package:carepharma/services/order_service.dart';
import 'package:carepharma/services/pharmacy_service.dart';
import 'package:carepharma/screens/pharmacy/pharmacy_dashboard_screen.dart';
import 'package:carepharma/screens/customer/live_order_tracking_screen.dart';
import 'package:carepharma/screens/customer/nearby_pharmacies_screen.dart';

class FakePharmacyService implements IPharmacyService {
  FakePharmacyService([this.pharmacies = const []]);

  final List<Pharmacy> pharmacies;

  @override
  Future<List<Pharmacy>> fetchPharmacies({double? userLat, double? userLng}) async {
    return pharmacies;
  }

  @override
  Future<void> registerPharmacy(Pharmacy pharmacy) async {}

  @override
  Future<void> updatePharmacy(Pharmacy pharmacy) async {}

  @override
  Future<Pharmacy?> fetchPharmacyForOwner(String? ownerId, {String? email}) async {
    if (pharmacies.isNotEmpty) return pharmacies.first;
    return const Pharmacy(
      uid: 'PH-TEST-001',
      name: 'Apollo Meds & Wellness',
      location: 'Baner, Pune',
      phone: '+91 98234 56789',
      latitude: 18.5590,
      longitude: 73.7868,
    );
  }

  @override
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return 1.2;
  }
}

class FakeOrderService implements IOrderService {
  FakeOrderService([List<OrderItem>? initial]) : orders = List.of(initial ?? []);

  final List<OrderItem> orders;

  @override
  Future<OrderItem> createOrder(OrderItem order) async {
    orders.add(order);
    return order;
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPatient(String patientEmail) async {
    return orders.where((o) => o.patientEmail == patientEmail).toList();
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPharmacy(String pharmacyUid) async {
    return orders.where((o) => o.pharmacyUid == pharmacyUid).toList();
  }

  @override
  Future<OrderItem?> fetchLatestOrderForPatient([String? patientEmail]) async {
    return orders.isNotEmpty ? orders.first : null;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx] = orders[idx].copyWith(status: status);
    }
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  group('PharmacyDashboardScreen Tests', () {
    testWidgets('Shows empty state when pharmacy has 0 orders', (tester) async {
      final fakeOrders = FakeOrderService([]);
      final fakePharmacy = FakePharmacyService();

      await tester.pumpWidget(
        _wrap(
          PharmacyDashboardScreen(
            orderService: fakeOrders,
            pharmacyService: fakePharmacy,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today\'s Orders'), findsOneWidget);
      expect(find.text('Gross Revenue'), findsOneWidget);
      expect(find.text('0'), findsAtLeastNWidgets(1)); // 0 orders
      expect(find.text('₹0'), findsOneWidget); // 0 revenue
      expect(find.text('No orders found'), findsOneWidget);
    });

    testWidgets('Calculates dynamic KPIs and shows orders with phase progression', (tester) async {
      final order1 = OrderItem(
        id: 'ord-12345678',
        medicineName: 'Paracetamol 650mg',
        quantity: 2,
        totalPrice: 40.0,
        patientEmail: 'patient1@carepharma.com',
        pharmacyUid: 'PH-TEST-001',
        status: 'Pending',
      );
      final order2 = OrderItem(
        id: 'ord-87654321',
        medicineName: 'Metformin 500mg',
        quantity: 3,
        totalPrice: 60.0,
        patientEmail: 'patient2@carepharma.com',
        pharmacyUid: 'PH-TEST-001',
        status: 'Packing',
      );

      final fakeOrders = FakeOrderService([order1, order2]);
      final fakePharmacy = FakePharmacyService();

      await tester.pumpWidget(
        _wrap(
          PharmacyDashboardScreen(
            orderService: fakeOrders,
            pharmacyService: fakePharmacy,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today\'s Orders'), findsOneWidget);
      expect(find.text('Gross Revenue'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // 2 orders total, 2 pending packing
      expect(find.text('₹100'), findsOneWidget); // 40 + 60 = 100
      expect(find.text('Paracetamol 650mg x2'), findsOneWidget);
      expect(find.text('Metformin 500mg x3'), findsOneWidget);

      // Verify changing status from Pending to Dispatched
      final dropdown = find.byType(DropdownButton<String>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Select 'Dispatched'
      await tester.tap(find.text('Dispatched').last);
      await tester.pumpAndSettle();

      expect(fakeOrders.orders[0].status, 'Dispatched');
      expect(find.text('DISPATCHED'), findsOneWidget);
    });
  });

  group('LiveOrderTrackingScreen Delivery Verification Tests', () {
    testWidgets('Prompts user for delivery confirmation when order is Delivered', (tester) async {
      final deliveredOrder = OrderItem(
        id: 'ord-99999999',
        medicineName: 'Amoxicillin 500mg',
        quantity: 1,
        totalPrice: 120.0,
        patientEmail: 'patient@carepharma.com',
        status: 'Delivered',
        deliveryAddress: 'Baner Road, Pune',
      );

      final fakeOrders = FakeOrderService([deliveredOrder]);

      await tester.pumpWidget(
        _wrap(
          LiveOrderTrackingScreen(
            initialOrder: deliveredOrder,
            orderService: fakeOrders,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery Confirmation Required'), findsOneWidget);
      expect(find.text('Confirm Delivery Received'), findsOneWidget);

      // Tap Confirm Delivery Received
      await tester.tap(find.text('Confirm Delivery Received'));
      await tester.pumpAndSettle();

      expect(fakeOrders.orders.first.status, 'Delivered & Confirmed');
      expect(find.text('Delivery Verified & Confirmed'), findsOneWidget);
    });
  });

  group('NearbyPharmaciesScreen Directions Tests', () {
    testWidgets('Renders Directions button for pharmacy with coordinates', (tester) async {
      final pharmacy = const Pharmacy(
        uid: 'PH-1',
        name: 'HealthPlus Baner',
        location: 'Baner, Pune',
        phone: '+91 99999 11111',
        latitude: 18.5590,
        longitude: 73.7868,
      );

      final fakePharmacy = FakePharmacyService([pharmacy]);

      await tester.pumpWidget(
        _wrap(
          NearbyPharmaciesScreen(pharmacyService: fakePharmacy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HealthPlus Baner'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
    });
  });
}
