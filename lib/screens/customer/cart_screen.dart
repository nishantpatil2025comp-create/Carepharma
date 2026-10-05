import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../auth_service.dart';
import '../../theme/app_colors.dart';
import 'live_order_tracking_screen.dart';
import 'upload_prescription_screen.dart';

/// Screen representing the User's Shopping Cart and Checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.cartService,
    this.authService,
  });

  final ICartService? cartService;
  final AuthService? authService;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final ICartService _cartService;
  late final AuthService _authService;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool _isLoading = true;
  bool _isCheckingOut = false;
  bool _isLocating = false;
  List<CartItem> _cartItems = [];
  String _deliveryAddress = 'Loading address...';
  double? _deliveryLat;
  double? _deliveryLng;
  bool _useCurrentGps = false;

  @override
  void initState() {
    super.initState();
    _cartService = widget.cartService ?? const CartService();
    _authService = widget.authService ?? const AuthService();
    _fetchCartAndProfile();
  }

  Future<void> _fetchCartAndProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      final userEmail = user?.email ?? _authService.currentUserEmail ?? 'patient@carepharma.com';

      // 1. Fetch Cart Items from Supabase cart table
      final items = await _cartService.fetchCartItems(userEmail);

      // 2. Fetch User Profile Address from Supabase profiles table
      String resolvedAddress = 'Baner, Pune (Default Hub)';
      final client = _supabase;
      if (client != null) {
        try {
          final profileResponse = await client
              .from('profiles')
              .select('address, city_pincode, delivery_address, latitude, longitude')
              .eq('email', userEmail)
              .maybeSingle();

          if (profileResponse != null) {
            final addr = profileResponse['address'] ?? profileResponse['delivery_address'];
            final cityPin = profileResponse['city_pincode'];
            if (addr != null && addr.toString().trim().isNotEmpty) {
              resolvedAddress = cityPin != null && cityPin.toString().trim().isNotEmpty
                  ? '${addr.toString().trim()}, ${cityPin.toString().trim()}'
                  : addr.toString().trim();
            }
            if (profileResponse['latitude'] != null) {
              _deliveryLat = double.tryParse(profileResponse['latitude'].toString());
            }
            if (profileResponse['longitude'] != null) {
              _deliveryLng = double.tryParse(profileResponse['longitude'].toString());
            }
          }
        } catch (_) {}
      } else {
        final profile = await _authService.getUserProfile();
        if (profile != null && profile.deliveryAddress != null && profile.deliveryAddress!.isNotEmpty) {
          resolvedAddress = profile.cityPincode != null && profile.cityPincode!.isNotEmpty
              ? '${profile.deliveryAddress!}, ${profile.cityPincode!}'
              : profile.deliveryAddress!;
          _deliveryLat = profile.latitude;
          _deliveryLng = profile.longitude;
        }
      }

      if (mounted) {
        setState(() {
          _cartItems = items;
          _deliveryAddress = resolvedAddress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cart: $e')),
        );
      }
    }
  }

  /// Fetches live GPS device location coordinates for delivery destination.
  Future<void> _fetchGpsAddress() async {
    setState(() => _isLocating = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Please enable GPS location service on your device.')),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

      var perm = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => LocationPermission.denied,
      );
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => LocationPermission.denied,
        );
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

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

      if (pos == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not determine GPS coordinates. Please try again.')),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

      final nonNullPos = pos;
      if (mounted) {
        setState(() {
          _deliveryLat = nonNullPos.latitude;
          _deliveryLng = nonNullPos.longitude;
          _deliveryAddress =
              'GPS Location: Lat ${nonNullPos.latitude.toStringAsFixed(4)}, Lon ${nonNullPos.longitude.toStringAsFixed(4)}';
          _useCurrentGps = true;
          _isLocating = false;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Delivery destination set to current GPS coordinates!')),
        );
      }

      // Persist GPS coordinates to user profile in Supabase
      if (_authService.currentUser != null) {
        try {
          final existingProfile = await _authService.getUserProfile();
          if (existingProfile != null) {
            final updated = existingProfile.copyWith(
              latitude: nonNullPos.latitude,
              longitude: nonNullPos.longitude,
              deliveryAddress: _deliveryAddress,
            );
            await _authService.saveUserProfile(updated);
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        messenger.showSnackBar(
          SnackBar(content: Text('GPS error: $e')),
        );
      }
    }
  }

  /// Calculates total price of all items currently in cart.
  double get totalPrice {
    double total = 0.0;
    for (final item in _cartItems) {
      total += item.totalPrice;
    }
    return total;
  }

  /// Handles checkout: loops through cart items, inserts into orders table, and clears cart.
  Future<void> _checkout() async {
    if (_cartItems.isEmpty) return;

    final user = _authService.currentUser;
    final userEmail = user?.email ?? _authService.currentUserEmail ?? 'patient@carepharma.com';

    setState(() => _isCheckingOut = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final itemsToOrder = List<CartItem>.from(_cartItems);

      // Perform checkout and insert orders into Supabase orders table
      final placedOrders = await _cartService.checkout(
        items: itemsToOrder,
        deliveryAddress: _deliveryAddress,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
        userEmail: userEmail,
      );

      if (mounted) {
        setState(() {
          _cartItems.clear();
          _isCheckingOut = false;
        });

        // Show confirmation dialog indicating order was placed
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00685F), size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order Placed Successfully!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your order containing ${itemsToOrder.length} item(s) has been placed with status "Pending".',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Destination:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _deliveryAddress,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  if (placedOrders.isNotEmpty) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveOrderTrackingScreen(
                          initialOrder: placedOrders.first,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00685F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingOut = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    }
  }

  Future<void> _incrementQuantity(CartItem item) async {
    try {
      await _cartService.updateQuantity(item.id, item.quantity + 1);
      await _fetchCartAndProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
      }
    }
  }

  Future<void> _decrementQuantity(CartItem item) async {
    try {
      if (item.quantity > 1) {
        await _cartService.updateQuantity(item.id, item.quantity - 1);
      } else {
        await _cartService.removeFromCart(item.id);
      }
      await _fetchCartAndProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    try {
      await _cartService.removeFromCart(item.id);
      await _fetchCartAndProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.medicineName} removed from cart.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00685F);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Your Cart & Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Upload Prescription',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
            ),
          ),
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Cart?'),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _cartService.clearCart();
                  _fetchCartAndProfile();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _cartItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Your cart is empty',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191C1E)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Browse medicines and generic substitutes to add them to your cart.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Browse Catalog'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade700,
                            side: BorderSide(color: Colors.teal.shade700),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                          ),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Upload Prescription'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Upload Prescription Banner
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                      ),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00685F).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00685F).withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.receipt_long, color: Color(0xFF00685F), size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Have a doctor\'s prescription?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00685F),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Attach Rx for pharmacist review and highest-saving alternatives',
                                    style: TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Color(0xFF00685F), size: 14),
                          ],
                        ),
                      ),
                    ),
                    // Cart items list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.medication, color: primaryColor, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.medicineName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${item.priceInr.toStringAsFixed(2)} per unit',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Quantity Stepper
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 16),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => _decrementQuantity(item),
                                        ),
                                        Text(
                                          '${item.quantity}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 16),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => _incrementQuantity(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Line total
                                  Text(
                                    '₹${item.totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryColor,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                    onPressed: () => _removeItem(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Delivery & Checkout Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Delivery Address Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Delivery Address:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF191C1E)),
                                ),
                                TextButton.icon(
                                  onPressed: _isLocating ? null : _fetchGpsAddress,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: primaryColor,
                                  ),
                                  icon: _isLocating
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                                        )
                                      : const Icon(Icons.my_location, size: 15),
                                  label: const Text('Use GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _useCurrentGps ? Icons.gps_fixed : Icons.home_outlined,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _deliveryAddress,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF191C1E)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Total Amount Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF191C1E)),
                                ),
                                Text(
                                  '₹${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Payment Method (Strictly Cash on Delivery / Dummy)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.payments_outlined, size: 16, color: Color(0xFF166534)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Payment: Cash on Delivery (Dummy COD) • Pay on arrival',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Place Order Now CTA
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                onPressed: _isCheckingOut ? null : _checkout,
                                child: _isCheckingOut
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Place Order Now',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
