import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../services/order_service.dart';
import '../../models/order.dart';
import '../../auth_service.dart';
import 'live_order_tracking_screen.dart';
import 'user_profile_screen.dart';

/// Screen 4: Multi-Pharmacy Cart & Checkout with Split-Fulfillment
class CartCheckoutScreen extends StatefulWidget {
  const CartCheckoutScreen({super.key});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  int _item1Qty = 2;
  int _item2Qty = 1;
  int _item3Qty = 1;
  String _paymentMethod = 'COD';

  final AuthService _authService = const AuthService();
  final OrderService _orderService = const OrderService();
  String _recipientName = 'Customer';
  String _recipientPhone = '';
  final TextEditingController _addressController = TextEditingController();
  double? _deliveryLat;
  double? _deliveryLng;
  bool _isLocating = false;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAddress() async {
    try {
      final profile = await _authService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          if (profile.fullName != null && profile.fullName!.isNotEmpty) {
            _recipientName = profile.fullName!;
          }
          if (profile.phone != null && profile.phone!.isNotEmpty) {
            _recipientPhone = profile.phone!;
          }
          if (profile.deliveryAddress != null && profile.deliveryAddress!.isNotEmpty) {
            _addressController.text = profile.deliveryAddress!;
          }
          _deliveryLat = profile.latitude;
          _deliveryLng = profile.longitude;
        });
      } else if (mounted) {
        setState(() {
          _addressController.text = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _addressController.text = '';
        });
      }
    }
  }

  Future<void> _detectGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS location service.')),
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine GPS coordinates. Please try again.')),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

      final nonNullPos = pos;
      final lat = nonNullPos.latitude;
      final lng = nonNullPos.longitude;
      if (mounted) {
        setState(() {
          _deliveryLat = lat;
          _deliveryLng = lng;
          _isLocating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery destination set to current GPS coordinates!')),
        );
      }

      // Persist GPS coordinates to user profile in Supabase
      if (_authService.currentUser != null) {
        try {
          final existingProfile = await _authService.getUserProfile();
          if (existingProfile != null) {
            final updated = existingProfile.copyWith(
              latitude: lat,
              longitude: lng,
              deliveryAddress: _addressController.text.trim().isNotEmpty
                  ? _addressController.text.trim()
                  : existingProfile.deliveryAddress,
            );
            await _authService.saveUserProfile(updated);
          }
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e')),
        );
      }
    }
  }

  Future<void> _placeOrder(double totalPayable) async {
    final manualAddress = _addressController.text.trim();
    if (manualAddress.isEmpty && _deliveryLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address or use current GPS location.')),
      );
      return;
    }
    final effectiveAddress = manualAddress.isNotEmpty
        ? manualAddress
        : (_deliveryLat != null && _deliveryLng != null
            ? 'GPS Pin: ${_deliveryLat!.toStringAsFixed(4)}, ${_deliveryLng!.toStringAsFixed(4)}'
            : 'Standard Delivery Destination');

    final lat = _deliveryLat ?? 18.5204;
    final lng = _deliveryLng ?? 73.8567;

    setState(() => _isPlacingOrder = true);
    try {
      final user = _authService.currentUser;
      final email = user?.email ?? _authService.currentUserEmail ?? 'customer@carepharma.local';

      final order = OrderItem(
        id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        medicineName: 'Prescription Generic Bundle (3 Items)',
        quantity: _item1Qty + _item2Qty + _item3Qty,
        totalPrice: totalPayable,
        patientEmail: email,
        deliveryAddress: effectiveAddress,
        deliveryLatitude: lat,
        deliveryLongitude: lng,
        status: 'placed',
      );

      final created = await _orderService.createOrder(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully! Live delivery tracking active.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LiveOrderTrackingScreen(initialOrder: created)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double store1Total = (_item1Qty * 18.0) + (_item2Qty * 12.5);
    final double store2Total = _item3Qty * 74.0;
    final double genericStorePrice = store1Total + store2Total;
    const double deliveryFee = 15.0;
    final double totalPayable = genericStorePrice + deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cart & Checkout',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '3 items • 2 Local Pharmacies',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CarePharma 24/7 Support: 1800-420-9900')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SPLIT-ORDER REASSURANCE BANNER
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping, color: AppColors.onSecondaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              'Split Hyperlocal Fulfillment',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              'Speed Optimized',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Your order is grouped by pharmacy for faster direct store delivery via dedicated store runners.',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // PRESCRIPTION VERIFIED BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rx Verified: Prescriptions Linked', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Validated for Schedule H drugs by Dr. A. Kulkarni', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PHARMACY GROUP 1: Apollo Diagnostics & Meds
            _buildPharmacyOrderSection(
              storeName: 'Apollo Diagnostics & Meds',
              storeTag: 'Store #1',
              distance: '0.8 km',
              deliveryETA: 'Same Day Delivery',
              items: [
                _buildCartItem(
                  title: 'Paracetamol IP 650mg (Genext)',
                  subtitle: 'Strip of 15 tablets • Dolo-650 generic substitute',
                  price: 18.00,
                  mrp: 58.50,
                  discount: '69% OFF',
                  quantity: _item1Qty,
                  onIncrement: () => setState(() => _item1Qty++),
                  onDecrement: () => setState(() {
                    if (_item1Qty > 1) _item1Qty--;
                  }),
                ),
                _buildCartItem(
                  title: 'Cetirizine 10mg IP (Cipla Generic)',
                  subtitle: 'Strip of 10 tablets • Anti-allergic',
                  price: 12.50,
                  mrp: 35.00,
                  discount: '64% OFF',
                  quantity: _item2Qty,
                  onIncrement: () => setState(() => _item2Qty++),
                  onDecrement: () => setState(() {
                    if (_item2Qty > 1) _item2Qty--;
                  }),
                ),
              ],
              subtotal: store1Total,
              isFreeDelivery: true,
            ),
            const SizedBox(height: 16),

            // PHARMACY GROUP 2: MedLife Generic Care
            _buildPharmacyOrderSection(
              storeName: 'MedLife Generic Care',
              storeTag: 'Store #2',
              distance: '1.4 km',
              deliveryETA: 'Same Day Delivery',
              items: [
                _buildCartItem(
                  title: 'Pantoprazole 40mg IP (Generic)',
                  subtitle: 'Strip of 15 tablets • Pan-40 equivalent',
                  price: 74.00,
                  mrp: 185.00,
                  discount: '60% OFF',
                  quantity: _item3Qty,
                  onIncrement: () => setState(() => _item3Qty++),
                  onDecrement: () => setState(() {
                    if (_item3Qty > 1) _item3Qty--;
                  }),
                ),
              ],
              subtotal: store2Total,
              isFreeDelivery: false,
            ),
            const SizedBox(height: 16),

            // DELIVERY ADDRESS CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delivery Address',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_deliveryLat != null && _deliveryLng != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'GPS: ${_deliveryLat!.toStringAsFixed(3)}, ${_deliveryLng!.toStringAsFixed(3)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                              ).then((_) => _loadProfileAddress());
                            },
                            child: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Delivery Address *',
                      hintText: 'Enter street address, building, or use GPS below',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.place, color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLocating ? null : _detectGpsLocation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isLocating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.my_location, size: 16),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isLocating ? 'Acquiring GPS...' : 'Use Current Location (GPS)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  if (_recipientPhone.isNotEmpty || _recipientName != 'Customer') ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Recipient: $_recipientName ($_recipientPhone)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // PAYMENT METHOD SELECTION
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Payment Method',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('100% Secure', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentRadio(
                    title: 'Cash on Delivery (Dummy COD)',
                    subtitle: 'Dummy test placeholder option • Pay directly on arrival',
                    value: 'COD',
                    tag: 'DEFAULT OPTION',
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // COMPREHENSIVE BILL SUMMARY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Branded Equivalent MRP',
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('₹356.50', style: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.outline, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Generic Store Price',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('₹${genericStorePrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Delivery Partner Fees (2 Stores)',
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹30.00 ', style: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.outline, fontSize: 11)),
                          Text('₹15.00', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Platform & Safety Handling',
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('FREE', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Payable', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Inclusive of all local taxes', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.surfaceContainer, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${totalPayable.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const Text('total payable', style: TextStyle(fontSize: 11, color: AppColors.outline)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPlacingOrder ? null : () => _placeOrder(totalPayable),
                icon: _isPlacingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_isPlacingOrder ? 'Processing...' : 'Place Order (Track Live)'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyOrderSection({
    required String storeName,
    required String storeTag,
    required String distance,
    required String deliveryETA,
    required List<Widget> items,
    required double subtotal,
    required bool isFreeDelivery,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              storeName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, size: 15, color: AppColors.primary),
                        ],
                      ),
                      Text(
                        '$distance away • $deliveryETA',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      storeTag,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Store Subtotal: ₹${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isFreeDelivery ? 'Delivery: FREE' : 'Delivery: ₹15.00',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFreeDelivery ? AppColors.secondary : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required String title,
    required String subtitle,
    required double price,
    required double mrp,
    required String discount,
    required int quantity,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('GENERIC BIO-EQUIV', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                ),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('MRP ₹${mrp.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: AppColors.outline)),
                    Text(discount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onDecrement,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.remove, size: 16, color: AppColors.primary),
                  ),
                ),
                Text('$quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: onIncrement,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Icon(Icons.add, size: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRadio({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    String? tag,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer.withValues(alpha: 0.15) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.outline,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      if (tag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.outline),
          ],
        ),
      ),
    );
  }
}
