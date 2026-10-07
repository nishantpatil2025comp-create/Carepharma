import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/models/cart_item.dart';
import 'package:carepharma/models/order.dart';
import 'package:carepharma/models/user_profile.dart';
import 'package:carepharma/services/cart_service.dart';
import 'package:carepharma/screens/customer/cart_screen.dart';
import 'package:carepharma/theme/app_theme.dart';
import 'package:carepharma/auth_service.dart';

/// Test mock implementation of [ICartService]
class MockCartService implements ICartService {
  final List<CartItem> items = [];
  bool checkoutCalled = false;
  String? lastDeliveryAddress;
  double? lastDeliveryLat;
  double? lastDeliveryLng;

  MockCartService([List<CartItem>? initialItems]) {
    if (initialItems != null) {
      items.addAll(initialItems);
    }
  }

  @override
  Future<void> addToCart({
    required String medicineId,
    required String medicineName,
    required double price,
    int quantity = 1,
    String? userEmail,
    String? pharmacyUid,
  }) async {
    final idx = items.indexWhere((i) => i.medicineId == medicineId);
    if (idx != -1) {
      final existing = items[idx];
      items[idx] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      items.add(
        CartItem(
          id: 'mock-cart-${items.length + 1}',
          userEmail: userEmail ?? 'patient@carepharma.com',
          medicineId: medicineId,
          medicineName: medicineName,
          priceInr: price,
          quantity: quantity,
          pharmacyUid: pharmacyUid,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<List<CartItem>> fetchCartItems([String? userEmail]) async {
    return List<CartItem>.from(items);
  }

  @override
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }
    final idx = items.indexWhere((i) => i.id == cartItemId);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(quantity: newQuantity);
    }
  }

  @override
  Future<void> removeFromCart(String cartItemId) async {
    items.removeWhere((i) => i.id == cartItemId);
  }

  @override
  Future<void> clearCart([String? userEmail]) async {
    items.clear();
  }

  @override
  Future<List<OrderItem>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? userEmail,
    String? patientName,
  }) async {
    checkoutCalled = true;
    lastDeliveryAddress = deliveryAddress;
    lastDeliveryLat = deliveryLat;
    lastDeliveryLng = deliveryLng;
    final createdOrders = <OrderItem>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      createdOrders.add(
        OrderItem(
          id: 'ORD-TEST-$i',
          medicineName: item.medicineName,
          quantity: item.quantity,
          totalPrice: item.totalPrice,
          patientEmail: userEmail ?? 'patient@carepharma.com',
          patientName: patientName,
          status: 'Pending',
          createdAt: DateTime.now(),
          deliveryAddress: deliveryAddress,
          deliveryLatitude: deliveryLat,
          deliveryLongitude: deliveryLng,
        ),
      );
    }
    this.items.clear();
    return createdOrders;
  }
}

/// Fake AuthService providing a default user profile with address and city_pincode
class MockUserAuthService extends AuthService {
  const MockUserAuthService() : super();

  @override
  Future<UserProfile?> getUserProfile({String? email, String? userId}) async {
    return const UserProfile(
      id: 'USR-99',
      fullName: 'Rahul Sharma',
      email: 'rahul.patient@gmail.com',
      role: 'user',
      deliveryAddress: 'Flat 402, Green Glen Layout, Bellandur',
      cityPincode: 'Bangalore - 560103',
      latitude: 12.9279,
      longitude: 77.6750,
    );
  }
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

void main() {
  group('CartItem Model Tests', () {
    test('Correctly deserializes from Supabase JSON', () {
      final json = {
        'id': 'b1c74148-1234-4567-89ab-cdef01234567',
        'user_email': 'patient@carepharma.com',
        'medicine_id': 'MED-001',
        'medicine_name': 'Paracetamol 650mg (Dolo)',
        'price_inr': 32.50,
        'quantity': 2,
        'created_at': '2026-10-05T12:00:00Z',
      };

      final item = CartItem.fromJson(json);

      expect(item.id, 'b1c74148-1234-4567-89ab-cdef01234567');
      expect(item.userEmail, 'patient@carepharma.com');
      expect(item.medicineId, 'MED-001');
      expect(item.medicineName, 'Paracetamol 650mg (Dolo)');
      expect(item.priceInr, 32.50);
      expect(item.quantity, 2);
      expect(item.totalPrice, 65.0);
    });

    test('Correctly serializes to Supabase insert payload', () {
      final item = CartItem(
        id: 'c-101',
        userEmail: 'patient@carepharma.com',
        medicineId: 'MED-002',
        medicineName: 'Azithromycin 500mg',
        priceInr: 110.0,
        quantity: 3,
      );

      final json = item.toJson();

      expect(json['id'], 'c-101');
      expect(json['user_email'], 'patient@carepharma.com');
      expect(json['medicine_id'], 'MED-002');
      expect(json['medicine_name'], 'Azithromycin 500mg');
      expect(json['price_inr'], 110.0);
      expect(json['quantity'], 3);
      expect(item.totalPrice, 330.0);
    });

    test('copyWith updates properties properly', () {
      final item = CartItem(
        id: 'c-101',
        userEmail: 'patient@carepharma.com',
        medicineId: 'MED-002',
        medicineName: 'Azithromycin 500mg',
        priceInr: 110.0,
        quantity: 1,
      );

      final updated = item.copyWith(quantity: 4, priceInr: 105.0);
      expect(updated.quantity, 4);
      expect(updated.priceInr, 105.0);
      expect(updated.totalPrice, 420.0);
    });
  });

  group('CartService Unit Tests', () {
    late CartService service;

    setUp(() async {
      service = const CartService();
      await service.clearCart('test@user.com');
    });

    test('Adding new medicine creates a cart item', () async {
      await service.addToCart(
        medicineId: 'MED-TEST-1',
        medicineName: 'Paracetamol IP 500mg',
        price: 15.50,
        quantity: 2,
        userEmail: 'test@user.com',
      );

      final items = await service.fetchCartItems('test@user.com');
      expect(items.length, 1);
      expect(items.first.medicineName, 'Paracetamol IP 500mg');
      expect(items.first.quantity, 2);
      expect(items.first.totalPrice, 31.0);
    });

    test('Adding same medicine increments existing quantity', () async {
      await service.addToCart(
        medicineId: 'MED-TEST-2',
        medicineName: 'Amoxicillin 500mg',
        price: 65.0,
        quantity: 1,
        userEmail: 'test@user.com',
      );

      await service.addToCart(
        medicineId: 'MED-TEST-2',
        medicineName: 'Amoxicillin 500mg',
        price: 65.0,
        quantity: 2,
        userEmail: 'test@user.com',
      );

      final items = await service.fetchCartItems('test@user.com');
      expect(items.length, 1);
      expect(items.first.quantity, 3);
      expect(items.first.totalPrice, 195.0);
    });

    test('Updating quantity modifies item and removing when quantity is 0', () async {
      await service.addToCart(
        medicineId: 'MED-TEST-3',
        medicineName: 'Cetirizine 10mg',
        price: 18.0,
        quantity: 2,
        userEmail: 'test@user.com',
      );

      final items = await service.fetchCartItems('test@user.com');
      final itemId = items.first.id;

      await service.updateQuantity(itemId, 5);
      final updated = await service.fetchCartItems('test@user.com');
      expect(updated.first.quantity, 5);

      await service.updateQuantity(itemId, 0);
      final afterRemove = await service.fetchCartItems('test@user.com');
      expect(afterRemove.isEmpty, isTrue);
    });

    test('Checkout creates pending orders and clears cart', () async {
      await service.addToCart(
        medicineId: 'MED-TEST-4',
        medicineName: 'Pantoprazole 40mg',
        price: 45.0,
        quantity: 2,
        userEmail: 'test@user.com',
      );

      final items = await service.fetchCartItems('test@user.com');
      final orders = await service.checkout(
        items: items,
        deliveryAddress: 'Baner, Pune, 411045',
        deliveryLat: 18.5590,
        deliveryLng: 73.7868,
        userEmail: 'test@user.com',
      );

      expect(orders.length, 1);
      expect(orders.first.status, 'Pending');
      expect(orders.first.medicineName, 'Pantoprazole 40mg');
      expect(orders.first.deliveryAddress, 'Baner, Pune, 411045');

      final remaining = await service.fetchCartItems('test@user.com');
      expect(remaining.isEmpty, isTrue);
    });
  });

  group('CartScreen Widget Tests', () {
    testWidgets('Renders empty state when cart has no items', (tester) async {
      final mockCart = MockCartService();
      await tester.pumpWidget(
        _buildTestApp(
          CartScreen(
            cartService: mockCart,
            authService: const MockUserAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Cart & Checkout'), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse Catalog'), findsOneWidget);
    });

    testWidgets('Renders cart items, saved address from profile, and computes dynamic total amount', (tester) async {
      final mockCart = MockCartService([
        CartItem(
          id: 'item-1',
          userEmail: 'rahul.patient@gmail.com',
          medicineId: 'MED-1',
          medicineName: 'Paracetamol IP 650mg',
          priceInr: 18.50,
          quantity: 2,
        ),
        CartItem(
          id: 'item-2',
          userEmail: 'rahul.patient@gmail.com',
          medicineId: 'MED-2',
          medicineName: 'Metformin 500mg',
          priceInr: 25.00,
          quantity: 1,
        ),
      ]);

      await tester.pumpWidget(
        _buildTestApp(
          CartScreen(
            cartService: mockCart,
            authService: const MockUserAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check titles & items
      expect(find.text('Your Cart & Checkout'), findsOneWidget);
      expect(find.text('Paracetamol IP 650mg'), findsOneWidget);
      expect(find.text('Metformin 500mg'), findsOneWidget);

      // Check prices: 18.50 * 2 = 37.00, 25.00 * 1 = 25.00, total = 62.00
      expect(find.text('₹62.00'), findsAtLeastNWidgets(1));

      // Check default address from profile
      expect(find.textContaining('Flat 402, Green Glen Layout'), findsOneWidget);
      expect(find.textContaining('Bangalore - 560103'), findsOneWidget);

      // Check "Use Current Location (GPS)" button exists
      expect(find.text('Use Current Location (GPS)'), findsOneWidget);

      // Check delivery address TextField exists
      expect(find.byType(TextField), findsOneWidget);

      // Check Place Order Now button exists
      expect(find.text('Place Order Now'), findsOneWidget);
    });

    testWidgets('Quantity stepper increments quantity and updates total price', (tester) async {
      final mockCart = MockCartService([
        CartItem(
          id: 'item-1',
          userEmail: 'rahul.patient@gmail.com',
          medicineId: 'MED-1',
          medicineName: 'Paracetamol IP 650mg',
          priceInr: 20.00,
          quantity: 1,
        ),
      ]);

      await tester.pumpWidget(
        _buildTestApp(
          CartScreen(
            cartService: mockCart,
            authService: const MockUserAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹20.00'), findsAtLeastNWidgets(1));

      // Tap + button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Quantity is now 2, total is ₹40.00
      expect(find.text('2'), findsOneWidget);
      expect(find.text('₹40.00'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping Place Order Now places orders and shows confirmation dialog', (tester) async {
      final mockCart = MockCartService([
        CartItem(
          id: 'item-1',
          userEmail: 'rahul.patient@gmail.com',
          medicineId: 'MED-1',
          medicineName: 'Amoxicillin 500mg',
          priceInr: 50.00,
          quantity: 1,
        ),
      ]);

      await tester.pumpWidget(
        _buildTestApp(
          CartScreen(
            cartService: mockCart,
            authService: const MockUserAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Place Order Now
      await tester.tap(find.text('Place Order Now'));
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(find.textContaining('status "Pending"'), findsOneWidget);
      expect(find.text('Delivery Destination:'), findsOneWidget);
      expect(find.textContaining('Flat 402, Green Glen Layout'), findsOneWidget);
      expect(find.text('Track Order'), findsOneWidget);

      // Confirm checkout service was invoked
      expect(mockCart.checkoutCalled, isTrue);
    });

    testWidgets('Editing delivery address TextField updates address passed to checkout', (tester) async {
      final mockCart = MockCartService([
        CartItem(
          id: 'item-1',
          userEmail: 'rahul.patient@gmail.com',
          medicineId: 'MED-1',
          medicineName: 'Amoxicillin 500mg',
          priceInr: 50.00,
          quantity: 1,
        ),
      ]);

      await tester.pumpWidget(
        _buildTestApp(
          CartScreen(
            cartService: mockCart,
            authService: const MockUserAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a new manual address
      final addressField = find.byType(TextField);
      expect(addressField, findsOneWidget);
      await tester.enterText(addressField, '123 Baker Street, London (Custom Delivery)');
      await tester.pumpAndSettle();

      // Tap Place Order Now
      await tester.tap(find.text('Place Order Now'));
      await tester.pumpAndSettle();

      // Expect confirmation dialog displaying the manual address
      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(find.textContaining('123 Baker Street, London (Custom Delivery)'), findsOneWidget);

      // Confirm checkout service received the manually entered address
      expect(mockCart.checkoutCalled, isTrue);
      expect(mockCart.lastDeliveryAddress, '123 Baker Street, London (Custom Delivery)');
    });
  });
}
