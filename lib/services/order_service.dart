import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

/// Interface for order operations.
abstract class IOrderService {
  Future<OrderItem> createOrder(OrderItem order);
  Future<List<OrderItem>> fetchOrdersForPatient(String patientEmail);
  Future<List<OrderItem>> fetchOrdersForPharmacy(String pharmacyUid);
  Future<OrderItem?> fetchLatestOrderForPatient([String? patientEmail]);
  Future<void> updateOrderStatus(String orderId, String status);
}

/// Service managing orders in Supabase `orders` table.
class OrderService implements IOrderService {
  const OrderService({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory fallback orders for offline/testing
  static final List<OrderItem> _mockOrders = [];

  @override
  Future<OrderItem> createOrder(OrderItem order) async {
    final client = _client;
    if (client == null) {
      final simulated = order.copyWith(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      _mockOrders.insert(0, simulated);
      return simulated;
    }

    try {
      final res = await client
          .from('orders')
          .insert(order.toJson())
          .select()
          .single();

      final created = OrderItem.fromJson(Map<String, dynamic>.from(res as Map));
      _mockOrders.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('[OrderService] Error inserting order in Supabase: $e');
      final simulated = order.copyWith(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      _mockOrders.insert(0, simulated);
      return simulated;
    }
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPatient(String patientEmail) async {
    final client = _client;
    if (client == null) {
      return _mockOrders.where((o) => o.patientEmail.toLowerCase() == patientEmail.toLowerCase()).toList();
    }

    try {
      final res = await client
          .from('orders')
          .select('*')
          .ilike('patient_email', patientEmail)
          .order('created_at', ascending: false);

      final list = (res as List<dynamic>)
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return list;
    } catch (e) {
      debugPrint('[OrderService] Error fetching patient orders: $e');
      return [];
    }
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPharmacy(String pharmacyUid) async {
    final client = _client;
    if (client == null) {
      return _mockOrders.where((o) => o.pharmacyUid == pharmacyUid).toList();
    }

    try {
      final res = await client
          .from('orders')
          .select('*')
          .eq('pharmacy_uid', pharmacyUid)
          .order('created_at', ascending: false);

      return (res as List<dynamic>)
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[OrderService] Error fetching pharmacy orders: $e');
      return [];
    }
  }

  @override
  Future<OrderItem?> fetchLatestOrderForPatient([String? patientEmail]) async {
    final email = patientEmail ?? _client?.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      if (_mockOrders.isNotEmpty) return _mockOrders.first;
      return null;
    }
    final orders = await fetchOrdersForPatient(email);
    if (orders.isNotEmpty) return orders.first;
    return null;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final client = _client;
    final index = _mockOrders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _mockOrders[index] = _mockOrders[index].copyWith(status: status);
    }

    if (client != null) {
      try {
        await client.from('orders').update({'status': status}).eq('id', orderId);
      } catch (e) {
        debugPrint('[OrderService] Error updating order status: $e');
      }
    }
  }

  static void resetMockState() {
    _mockOrders.clear();
  }
}
