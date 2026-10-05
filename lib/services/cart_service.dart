import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import 'order_service.dart';

/// Interface defining operations for user shopping cart management.
abstract class ICartService {
  Future<void> addToCart({
    required String medicineId,
    required String medicineName,
    required double price,
    int quantity = 1,
    String? userEmail,
  });

  Future<List<CartItem>> fetchCartItems([String? userEmail]);

  Future<void> updateQuantity(String cartItemId, int newQuantity);

  Future<void> removeFromCart(String cartItemId);

  Future<void> clearCart([String? userEmail]);

  Future<List<OrderItem>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? userEmail,
  });
}

/// Production implementation of [ICartService] using Supabase `cart` and `orders` tables.
class CartService implements ICartService {
  const CartService({
    SupabaseClient? client,
    IOrderService? orderService,
  })  : _customClient = client,
        _customOrderService = orderService;

  final SupabaseClient? _customClient;
  final IOrderService? _customOrderService;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  IOrderService get _orderService => _customOrderService ?? const OrderService();

  // In-memory fallback cart items for offline/testing scenarios
  static final List<CartItem> _mockCart = [];

  String? _resolveUserEmail([String? providedEmail]) {
    if (providedEmail != null && providedEmail.trim().isNotEmpty) {
      return providedEmail.trim();
    }
    return _client?.auth.currentUser?.email;
  }

  @override
  Future<void> addToCart({
    required String medicineId,
    required String medicineName,
    required double price,
    int quantity = 1,
    String? userEmail,
  }) async {
    final client = _client;
    final email = _resolveUserEmail(userEmail) ?? 'patient@carepharma.com';

    if (client == null) {
      final index = _mockCart.indexWhere(
        (i) => i.userEmail == email && i.medicineId == medicineId,
      );
      if (index != -1) {
        _mockCart[index] = _mockCart[index].copyWith(
          quantity: _mockCart[index].quantity + quantity,
        );
      } else {
        _mockCart.add(
          CartItem(
            id: 'mock_cart_${DateTime.now().millisecondsSinceEpoch}',
            userEmail: email,
            medicineId: medicineId,
            medicineName: medicineName,
            priceInr: price,
            quantity: quantity,
            createdAt: DateTime.now(),
          ),
        );
      }
      return;
    }

    try {
      // Check if item already exists in cart for this user
      final existing = await client
          .from('cart')
          .select()
          .eq('user_email', email)
          .eq('medicine_id', medicineId)
          .maybeSingle();

      if (existing != null) {
        final currentQty = (existing['quantity'] as num?)?.toInt() ?? 1;
        final newQty = currentQty + quantity;
        await client
            .from('cart')
            .update({'quantity': newQty})
            .eq('id', existing['id']);
      } else {
        await client.from('cart').insert({
          'user_email': email,
          'medicine_id': medicineId,
          'medicine_name': medicineName,
          'price_inr': price,
          'quantity': quantity,
        });
      }
    } catch (e) {
      debugPrint('[CartService] Error adding to cart: $e');
      rethrow;
    }
  }

  @override
  Future<List<CartItem>> fetchCartItems([String? userEmail]) async {
    final client = _client;
    final email = _resolveUserEmail(userEmail);

    if (client == null) {
      if (email != null && email.isNotEmpty) {
        return _mockCart.where((i) => i.userEmail == email).toList();
      }
      return List<CartItem>.from(_mockCart);
    }

    if (email == null || email.isEmpty) {
      return [];
    }

    try {
      final response = await client
          .from('cart')
          .select()
          .eq('user_email', email)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[CartService] Error fetching cart items: $e');
      if (email.isNotEmpty) {
        return _mockCart.where((i) => i.userEmail == email).toList();
      }
      return List<CartItem>.from(_mockCart);
    }
  }

  @override
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    final client = _client;
    if (client == null) {
      final index = _mockCart.indexWhere((i) => i.id == cartItemId);
      if (index != -1) {
        _mockCart[index] = _mockCart[index].copyWith(quantity: newQuantity);
      }
      return;
    }

    try {
      await client
          .from('cart')
          .update({'quantity': newQuantity})
          .eq('id', cartItemId);
    } catch (e) {
      debugPrint('[CartService] Error updating quantity: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFromCart(String cartItemId) async {
    final client = _client;
    if (client == null) {
      _mockCart.removeWhere((i) => i.id == cartItemId);
      return;
    }

    try {
      await client.from('cart').delete().eq('id', cartItemId);
    } catch (e) {
      debugPrint('[CartService] Error removing from cart: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearCart([String? userEmail]) async {
    final client = _client;
    final email = _resolveUserEmail(userEmail);

    if (client == null) {
      if (email != null && email.isNotEmpty) {
        _mockCart.removeWhere((i) => i.userEmail == email);
      } else {
        _mockCart.clear();
      }
      return;
    }

    if (email == null || email.isEmpty) return;

    try {
      await client.from('cart').delete().eq('user_email', email);
    } catch (e) {
      debugPrint('[CartService] Error clearing cart: $e');
      rethrow;
    }
  }

  @override
  Future<List<OrderItem>> checkout({
    required List<CartItem> items,
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? userEmail,
  }) async {
    final email = _resolveUserEmail(userEmail) ?? 'patient@carepharma.com';
    final List<OrderItem> createdOrders = [];

    for (final item in items) {
      final order = OrderItem(
        id: '',
        medicineName: item.medicineName,
        quantity: item.quantity,
        totalPrice: item.totalPrice,
        patientEmail: email,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLat,
        deliveryLongitude: deliveryLng,
        status: 'Pending',
      );

      final placed = await _orderService.createOrder(order);
      createdOrders.add(placed);
    }

    // Clear cart after checkout
    await clearCart(email);

    return createdOrders;
  }
}
