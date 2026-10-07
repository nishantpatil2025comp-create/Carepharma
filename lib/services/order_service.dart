import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

/// Interface for order operations.
abstract class IOrderService {
  Future<OrderItem> createOrder(OrderItem order);
  Future<List<OrderItem>> fetchOrdersForPatient([String? patientEmail]);
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
    final resolvedEmail = order.patientEmail.isNotEmpty
        ? order.patientEmail
        : (_client?.auth.currentUser?.email ?? 'patient@carepharma.com');

    final orderToInsert = order.patientEmail.isEmpty
        ? order.copyWith(patientEmail: resolvedEmail)
        : order;

    final resolvedAddress = (orderToInsert.deliveryAddress != null && orderToInsert.deliveryAddress!.trim().isNotEmpty)
        ? orderToInsert.deliveryAddress!.trim()
        : 'Standard Delivery Destination';
    final resolvedLat = orderToInsert.deliveryLatitude ?? 18.5204;
    final resolvedLng = orderToInsert.deliveryLongitude ?? 73.8567;

    if (client == null) {
      final simulated = orderToInsert.copyWith(
        id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
        deliveryAddress: resolvedAddress,
        deliveryLatitude: resolvedLat,
        deliveryLongitude: resolvedLng,
      );
      _mockOrders.insert(0, simulated);
      return simulated;
    }

    // Tier 1: Complete Payload including delivery address, GPS coordinates, patient name, pharmacy UID
    final tier1Payload = <String, dynamic>{
      'medicine_name': orderToInsert.medicineName,
      'quantity': orderToInsert.quantity,
      'total_price': orderToInsert.totalPrice,
      'patient_email': orderToInsert.patientEmail,
      'status': orderToInsert.status,
      'delivery_address': resolvedAddress,
      'delivery_latitude': resolvedLat,
      'delivery_longitude': resolvedLng,
      if (orderToInsert.patientName != null && orderToInsert.patientName!.trim().isNotEmpty)
        'patient_name': orderToInsert.patientName!.trim(),
      if (orderToInsert.pharmacyUid != null && orderToInsert.pharmacyUid!.isNotEmpty)
        'pharmacy_uid': orderToInsert.pharmacyUid,
    };

    try {
      final res = await client
          .from('orders')
          .insert(tier1Payload)
          .select()
          .single();

      final created = OrderItem.fromJson(Map<String, dynamic>.from(res as Map)).copyWith(
        deliveryAddress: resolvedAddress,
        deliveryLatitude: resolvedLat,
        deliveryLongitude: resolvedLng,
        patientName: orderToInsert.patientName,
      );
      _mockOrders.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('[OrderService] Tier 1 insert notice: $e. Retrying with GPS and core delivery payload...');
      try {
        // Tier 2: Core + Delivery Address + GPS Coordinates (excluding optional patient_name and pharmacy_uid in case those columns are not in schema)
        final tier2Payload = <String, dynamic>{
          'medicine_name': orderToInsert.medicineName,
          'quantity': orderToInsert.quantity,
          'total_price': orderToInsert.totalPrice,
          'patient_email': orderToInsert.patientEmail,
          'status': orderToInsert.status,
          'delivery_address': resolvedAddress,
          'delivery_latitude': resolvedLat,
          'delivery_longitude': resolvedLng,
        };

        final res = await client
            .from('orders')
            .insert(tier2Payload)
            .select()
            .single();

        final created = OrderItem.fromJson(Map<String, dynamic>.from(res as Map)).copyWith(
          deliveryAddress: resolvedAddress,
          deliveryLatitude: resolvedLat,
          deliveryLongitude: resolvedLng,
          patientName: orderToInsert.patientName,
        );
        _mockOrders.insert(0, created);
        return created;
      } catch (tier2Err) {
        debugPrint('[OrderService] Tier 2 insert notice: $tier2Err. Retrying with delivery address only...');
        try {
          // Tier 3: Core + Delivery Address only (in case delivery_latitude/longitude columns are missing)
          final tier3Payload = <String, dynamic>{
            'medicine_name': orderToInsert.medicineName,
            'quantity': orderToInsert.quantity,
            'total_price': orderToInsert.totalPrice,
            'patient_email': orderToInsert.patientEmail,
            'status': orderToInsert.status,
            'delivery_address': resolvedAddress,
          };

          final res = await client
              .from('orders')
              .insert(tier3Payload)
              .select()
              .single();

          final created = OrderItem.fromJson(Map<String, dynamic>.from(res as Map)).copyWith(
            deliveryAddress: resolvedAddress,
            deliveryLatitude: resolvedLat,
            deliveryLongitude: resolvedLng,
            patientName: orderToInsert.patientName,
          );
          _mockOrders.insert(0, created);
          return created;
        } catch (tier3Err) {
          debugPrint('[OrderService] Tier 3 insert notice: $tier3Err. Retrying with minimal payload...');
          try {
            // Tier 4: Minimal payload fallback
            final minimalPayload = <String, dynamic>{
              'medicine_name': orderToInsert.medicineName,
              'quantity': orderToInsert.quantity,
              'total_price': orderToInsert.totalPrice,
              'patient_email': orderToInsert.patientEmail,
              'status': orderToInsert.status,
            };

            final res = await client
                .from('orders')
                .insert(minimalPayload)
                .select()
                .single();

            final created = OrderItem.fromJson(Map<String, dynamic>.from(res as Map)).copyWith(
              deliveryAddress: orderToInsert.deliveryAddress,
              deliveryLatitude: orderToInsert.deliveryLatitude,
              deliveryLongitude: orderToInsert.deliveryLongitude,
              patientName: orderToInsert.patientName,
            );
            _mockOrders.insert(0, created);
            return created;
          } catch (minErr) {
            debugPrint('[OrderService] Notice inserting order in Supabase (buffering locally): $minErr');
            final simulated = orderToInsert.copyWith(
              id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
              createdAt: DateTime.now(),
            );
            _mockOrders.insert(0, simulated);
            return simulated;
          }
        }
      }
    }
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPatient([String? patientEmail]) async {
    final client = _client;
    final email = (patientEmail != null && patientEmail.isNotEmpty)
        ? patientEmail
        : (_client?.auth.currentUser?.email ?? 'patient@carepharma.com');

    List<OrderItem> items = [];

    if (client != null) {
      try {
        dynamic res;
        try {
          res = await client
              .from('orders')
              .select('*')
              .ilike('patient_email', email)
              .order('created_at', ascending: false);
        } catch (_) {
          try {
            res = await client
                .from('orders')
                .select('*')
                .ilike('patient_email', email);
          } catch (_) {
            res = await client.from('orders').select('*');
          }
        }

        final all = (res as List<dynamic>)
            .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

        items = all.where((o) =>
            o.patientEmail.isEmpty ||
            o.patientEmail.toLowerCase() == email.toLowerCase() ||
            email == 'patient@carepharma.com'
        ).toList();
      } catch (e) {
        debugPrint('[OrderService] Notice fetching patient orders from Supabase: $e');
      }
    }

    // Merge recent local / buffer orders
    final local = _mockOrders.where((o) =>
        o.patientEmail.toLowerCase() == email.toLowerCase() ||
        o.patientEmail.isEmpty ||
        email == 'patient@carepharma.com'
    ).toList();

    for (final loc in local) {
      if (!items.any((db) => db.id.isNotEmpty && db.id == loc.id)) {
        items.add(loc);
      }
    }

    items.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });

    return items;
  }

  @override
  Future<List<OrderItem>> fetchOrdersForPharmacy(String pharmacyUid) async {
    final client = _client;
    List<OrderItem> list = [];

    if (client != null) {
      try {
        final query = client.from('orders').select('*');
        dynamic res;
        try {
          res = pharmacyUid.isNotEmpty
              ? await query.or('pharmacy_uid.eq.$pharmacyUid,pharmacy_uid.is.null').order('created_at', ascending: false)
              : await query.order('created_at', ascending: false);
        } catch (_) {
          try {
            res = pharmacyUid.isNotEmpty
                ? await query.eq('pharmacy_uid', pharmacyUid).order('created_at', ascending: false)
                : await query.order('created_at', ascending: false);
          } catch (_) {
            res = await query;
          }
        }

        list = (res as List<dynamic>)
            .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

        // Dynamically resolve real patient full names from public.profiles
        if (list.isNotEmpty) {
          final patientEmails = list
              .map((o) => o.patientEmail.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();

          if (patientEmails.isNotEmpty) {
            try {
              final profilesRes = await client
                  .from('profiles')
                  .select('email, full_name')
                  .inFilter('email', patientEmails);

              final Map<String, String> emailToName = {};
              for (final row in profilesRes as List<dynamic>) {
                final email = row['email']?.toString().toLowerCase();
                final name = row['full_name']?.toString();
                if (email != null && name != null && name.trim().isNotEmpty) {
                  emailToName[email] = name.trim();
                }
              }

              if (emailToName.isNotEmpty) {
                list = list.map((order) {
                  final resolved = emailToName[order.patientEmail.trim().toLowerCase()];
                  if (resolved != null && resolved.isNotEmpty) {
                    return order.copyWith(patientName: resolved);
                  }
                  return order;
                }).toList();
              }
            } catch (e) {
              debugPrint('[OrderService] Notice enriching patient names from profiles: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[OrderService] Notice fetching pharmacy orders from Supabase: $e');
      }
    }

    final local = _mockOrders.where((o) =>
        pharmacyUid.isEmpty || o.pharmacyUid == null || o.pharmacyUid == pharmacyUid
    ).toList();

    for (final l in local) {
      if (!list.any((o) => o.id.isNotEmpty && o.id == l.id)) {
        list.add(l);
      }
    }

    list.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });

    return list;
  }

  @override
  Future<OrderItem?> fetchLatestOrderForPatient([String? patientEmail]) async {
    final orders = await fetchOrdersForPatient(patientEmail);
    if (orders.isNotEmpty) return orders.first;
    if (_mockOrders.isNotEmpty) return _mockOrders.first;
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
        // 1. Target order_id primary key as used in the orders table
        await client.from('orders').update({'status': status}).eq('order_id', orderId);
        return;
      } catch (e) {
        final err1 = e.toString().toLowerCase();
        if (err1.contains('order_id') && err1.contains('does not exist')) {
          // 2. Fallback to 'UID' primary key
          try {
            await client.from('orders').update({'status': status}).eq('UID', orderId);
            return;
          } catch (e2) {
            final err2 = e2.toString().toLowerCase();
            // 3. Fallback to 'id' primary key
            if (err2.contains('uid') && err2.contains('does not exist')) {
              try {
                await client.from('orders').update({'status': status}).eq('id', orderId);
                return;
              } catch (e3) {
                debugPrint('[OrderService] Error updating status via id: $e3');
                rethrow;
              }
            }
            debugPrint('[OrderService] Error updating status via UID: $e2');
            rethrow;
          }
        }
        debugPrint('[OrderService] Error updating order status: $e');
        rethrow;
      }
    }
  }

  static void resetMockState() {
    _mockOrders.clear();
  }
}
