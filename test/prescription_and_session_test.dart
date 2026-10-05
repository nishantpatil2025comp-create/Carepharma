import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/main.dart';
import 'package:carepharma/auth_service.dart';
import 'package:carepharma/screens/customer/upload_prescription_screen.dart';
import 'package:carepharma/screens/customer/cart_screen.dart';
import 'package:carepharma/screens/customer/medicine_search_screen.dart';
import 'package:carepharma/services/cart_service.dart';
import 'package:carepharma/models/cart_item.dart';
import 'package:carepharma/models/order.dart';

class MockCartServiceForTest implements ICartService {
  final List<CartItem> _items = [];

  @override
  Future<List<CartItem>> fetchCartItems([String? userEmail]) async => List.unmodifiable(_items);

  @override
  Future<void> addToCart({
    required String medicineId,
    required String medicineName,
    required double price,
    int quantity = 1,
    String? userEmail,
  }) async {
    _items.add(CartItem(
      id: 'cart-1',
      userEmail: userEmail ?? 'test@example.com',
      medicineId: medicineId,
      medicineName: medicineName,
      priceInr: price,
      quantity: quantity,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {}

  @override
  Future<void> removeFromCart(String cartItemId) async {
    _items.removeWhere((i) => i.id == cartItemId);
  }

  @override
  Future<void> clearCart([String? userEmail]) async {
    _items.clear();
  }

  @override
  Future<List<OrderItem>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? userEmail,
  }) async => [];
}

void main() {
  group('UploadPrescriptionScreen Tests', () {
    testWidgets('Renders upload options and triggers prescription attachment', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: UploadPrescriptionScreen(simulateUploadInTest: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Upload Prescription'), findsWidgets);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('From Gallery'), findsOneWidget);

      // Tap Take Photo
      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check confirmation snackbar message
      expect(find.textContaining('Prescription attached successfully'), findsOneWidget);

      // Check that preview state is displayed
      expect(find.text('File Ready for Matching'), findsOneWidget);
      expect(find.text('Re-take'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Tap Remove
      await tester.tap(find.text('Remove'));
      await tester.pump();

      // Preview state is removed
      expect(find.text('File Ready for Matching'), findsNothing);
    });
  });

  group('Prescription Access in Cart and Search Screens', () {
    testWidgets('CartScreen displays prescription upload options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockCart = MockCartServiceForTest();

      await tester.pumpWidget(MaterialApp(
        home: CartScreen(cartService: mockCart),
      ));
      await tester.pumpAndSettle();

      // Empty cart should show Upload Prescription option
      expect(find.text('Upload Prescription'), findsWidgets);
    });

    testWidgets('MedicineSearchScreen displays prescription upload button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockCart = MockCartServiceForTest();

      await tester.pumpWidget(MaterialApp(
        home: MedicineSearchScreen(cartService: mockCart),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Or Upload Prescription'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    });
  });

  group('AppSessionGate Tests', () {
    testWidgets('AppSessionGate loads RoleSelectionScreen when no session is active', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: AppSessionGate(
          authService: AuthService(),
          useDualRoleRouting: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Falls back safely to RoleSelectionScreen
      expect(find.text('CarePharma'), findsOneWidget);
      expect(find.text('Login as User'), findsOneWidget);
      expect(find.text('Login as Pharmacist'), findsOneWidget);
    });
  });
}
