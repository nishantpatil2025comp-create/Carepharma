import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../auth_service.dart';
import '../screens/customer/live_order_tracking_screen.dart';

/// Shows an interactive Order Dialog that saves the order directly to Supabase `orders` table,
/// allowing the user to use their saved profile address or fetch live device GPS coordinates.
Future<void> showOrderDialog(
  BuildContext context,
  Map<String, dynamic> medicine, {
  IOrderService? orderService,
  AuthService? authService,
}) async {
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController addressController = TextEditingController();

  final rawPrice = medicine['Price_INR'] ?? medicine['price_inr'] ?? medicine['price'] ?? 0;
  final double pricePerUnit = rawPrice is num ? rawPrice.toDouble() : (double.tryParse(rawPrice.toString()) ?? 0.0);
  final String medicineName = (medicine['Name'] ?? medicine['name'] ?? 'Generic Medicine').toString();
  final String? pharmacyUid = medicine['pharmacy_uid']?.toString() ?? medicine['added_by']?.toString();

  final effectiveAuth = authService ?? const AuthService();
  final effectiveOrderService = orderService ?? const OrderService();

  // Try pre-filling saved profile address
  double? deliveryLat;
  double? deliveryLng;
  try {
    final user = effectiveAuth.currentUser;
    final email = user?.email ?? effectiveAuth.currentUserEmail;
    final profile = await effectiveAuth.getUserProfile(userId: user?.id, email: email);
    if (profile?.deliveryAddress != null && profile!.deliveryAddress!.trim().isNotEmpty) {
      addressController.text = profile.deliveryAddress!;
      deliveryLat = profile.latitude;
      deliveryLng = profile.longitude;
    }
  } catch (_) {}

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) {
      double totalPrice = pricePerUnit;
      bool isLocating = false;
      bool isPlacingOrder = false;

      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order: $medicineName',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price per unit: ₹${pricePerUnit.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // Quantity input
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      int qty = int.tryParse(value) ?? 1;
                      setStateDialog(() {
                        totalPrice = pricePerUnit * (qty > 0 ? qty : 1);
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Delivery Address input
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Destination Address *',
                      hintText: 'Enter street, house no., or fetch GPS',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Live GPS fetch button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade800,
                      side: BorderSide(color: Colors.teal.shade300),
                    ),
                    onPressed: isLocating
                        ? null
                        : () async {
                            setStateDialog(() => isLocating = true);
                            try {
                              final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enable GPS / Location on your device.')),
                                  );
                                }
                                return;
                              }

                              var perm = await Geolocator.checkPermission();
                              if (perm == LocationPermission.denied) {
                                perm = await Geolocator.requestPermission();
                              }
                              if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                                Position? pos;
                                try {
                                  pos = await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(timeLimit: Duration(seconds: 4)),
                                  );
                                } catch (_) {
                                  pos = await Geolocator.getLastKnownPosition().timeout(
                                    const Duration(seconds: 2),
                                    onTimeout: () => null,
                                  );
                                }
                                if (pos != null) {
                                  deliveryLat = pos.latitude;
                                  deliveryLng = pos.longitude;
                                  addressController.text = 'GPS Pin: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (Live Location)';
                                }
                              }
                            } catch (e) {
                              debugPrint('GPS fetch note: $e');
                            } finally {
                              setStateDialog(() => isLocating = false);
                            }
                          },
                    icon: isLocating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Use Current Location (GPS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Amount
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        Text(
                          '₹${totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isPlacingOrder ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isPlacingOrder
                    ? null
                    : () async {
                        String userEmail = 'patient@carepharma.com';
                        try {
                          final supabaseUser = Supabase.instance.client.auth.currentUser;
                          if (supabaseUser?.email != null) {
                            userEmail = supabaseUser!.email!;
                          } else if (effectiveAuth.currentUserEmail != null) {
                            userEmail = effectiveAuth.currentUserEmail!;
                          }
                        } catch (_) {
                          if (effectiveAuth.currentUserEmail != null) {
                            userEmail = effectiveAuth.currentUserEmail!;
                          }
                        }

                        final deliveryAddress = addressController.text.trim();
                        if (deliveryAddress.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide or fetch a delivery address.')),
                          );
                          return;
                        }

                        setStateDialog(() => isPlacingOrder = true);

                        try {
                          int qty = int.tryParse(quantityController.text) ?? 1;
                          if (qty <= 0) qty = 1;

                          final order = OrderItem(
                            id: '',
                            medicineName: medicineName,
                            quantity: qty,
                            totalPrice: totalPrice,
                            patientEmail: userEmail,
                            deliveryAddress: deliveryAddress,
                            deliveryLatitude: deliveryLat,
                            deliveryLongitude: deliveryLng,
                            pharmacyUid: pharmacyUid,
                            status: 'Pending',
                          );

                          await effectiveOrderService.createOrder(order);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order placed for $medicineName!'),
                                backgroundColor: Colors.teal.shade800,
                                action: SnackBarAction(
                                  label: 'Track Order',
                                  textColor: Colors.amberAccent,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const LiveOrderTrackingScreen()),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to place order: $e')),
                            );
                          }
                        } finally {
                          setStateDialog(() => isPlacingOrder = false);
                        }
                      },
                child: isPlacingOrder
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Order'),
              ),
            ],
          );
        },
      );
    },
  );
}
