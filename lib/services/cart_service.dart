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
    String? pharmacyUid,
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
    String? patientName,
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
    String? pharmacyUid,
  }) async {
    final client = _client;
    final email = _resolveUserEmail(userEmail) ?? 'patient@carepharma.com';

    // Maintain local in-memory cart buffer
    final localIndex = _mockCart.indexWhere(
      (i) => i.userEmail == email && i.medicineId == medicineId,
    );
    if (localIndex != -1) {
      _mockCart[localIndex] = _mockCart[localIndex].copyWith(
        quantity: _mockCart[localIndex].quantity + quantity,
        pharmacyUid: pharmacyUid ?? _mockCart[localIndex].pharmacyUid,
      );
    } else {
      _mockCart.add(
        CartItem(
          id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
          userEmail: email,
          medicineId: medicineId,
          medicineName: medicineName,
          priceInr: price,
          quantity: quantity,
          pharmacyUid: pharmacyUid,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (client == null) {
      return;
    }

    try {
      // Check if item already exists in cart for this user in Supabase
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
        try {
          await client.from('cart').insert({
            'user_email': email,
            'medicine_id': medicineId,
            'medicine_name': medicineName,
            'price_inr': price,
            'quantity': quantity,
            if (pharmacyUid != null && pharmacyUid.isNotEmpty) 'pharmacy_uid': pharmacyUid,
          });
        } catch (_) {
          // If pharmacy_uid column is not yet created in Supabase schema cache, retry without it
          await client.from('cart').insert({
            'user_email': email,
            'medicine_id': medicineId,
            'medicine_name': medicineName,
            'price_inr': price,
            'quantity': quantity,
          });
        }
      }
    } catch (e) {
      // Table missing (404 schema cache error) or offline - gracefully keep local cart state
      debugPrint('[CartService] Supabase cart sync notice (using local buffer): $e');
    }
  }

  @override
  Future<List<CartItem>> fetchCartItems([String? userEmail]) async {
    final client = _client;
    final email = _resolveUserEmail(userEmail) ?? 'patient@carepharma.com';

    if (client == null) {
      return _mockCart.where((i) => i.userEmail == email).toList();
    }

    try {
      final response = await client
          .from('cart')
          .select()
          .eq('user_email', email)
          .order('created_at', ascending: false);

      final items = (response as List<dynamic>)
          .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      // Merge any local items that may not have synced yet
      final localItems = _mockCart.where((i) => i.userEmail == email).toList();
      for (final loc in localItems) {
        if (!items.any((db) => db.medicineId == loc.medicineId)) {
          items.add(loc);
        }
      }
      return items;
    } catch (e) {
      debugPrint('[CartService] Supabase fetch cart notice (using local items): $e');
      return _mockCart.where((i) => i.userEmail == email).toList();
    }
  }

  @override
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    final index = _mockCart.indexWhere((i) => i.id == cartItemId);
    if (newQuantity <= 0) {
      if (index != -1) _mockCart.removeAt(index);
    } else {
      if (index != -1) {
        _mockCart[index] = _mockCart[index].copyWith(quantity: newQuantity);
      }
    }

    final client = _client;
    if (client == null) return;

    try {
      if (newQuantity <= 0) {
        await client.from('cart').delete().eq('id', cartItemId);
      } else {
        await client
            .from('cart')
            .update({'quantity': newQuantity})
            .eq('id', cartItemId);
      }
    } catch (e) {
      debugPrint('[CartService] Supabase updateQuantity notice: $e');
    }
  }

  @override
  Future<void> removeFromCart(String cartItemId) async {
    _mockCart.removeWhere((i) => i.id == cartItemId);
    final client = _client;
    if (client == null) return;

    try {
      await client.from('cart').delete().eq('id', cartItemId);
    } catch (e) {
      debugPrint('[CartService] Supabase removeFromCart notice: $e');
    }
  }

  @override
  Future<void> clearCart([String? userEmail]) async {
    final email = _resolveUserEmail(userEmail);
    if (email != null && email.isNotEmpty) {
      _mockCart.removeWhere((i) => i.userEmail == email);
    } else {
      _mockCart.clear();
    }

    final client = _client;
    if (client == null || email == null || email.isEmpty) return;

    try {
      await client.from('cart').delete().eq('user_email', email);
    } catch (e) {
      debugPrint('[CartService] Supabase clearCart notice: $e');
    }
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
    final email = _resolveUserEmail(userEmail) ?? 'patient@carepharma.com';
    final List<OrderItem> createdOrders = [];

    for (final item in items) {
      final order = OrderItem(
        id: '',
        medicineName: item.medicineName,
        quantity: item.quantity,
        totalPrice: item.totalPrice,
        patientEmail: email,
        patientName: patientName,
        deliveryAddress: deliveryAddress,
        deliveryLatitude: deliveryLat,
        deliveryLongitude: deliveryLng,
        pharmacyUid: item.pharmacyUid,
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
