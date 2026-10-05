import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import 'medicine_search_screen.dart';

/// Screen 7: Live Order Tracking
/// Pulls real live orders from the Supabase orders table for the patient.
/// If no active orders exist, displays a clean empty state.
class LiveOrderTrackingScreen extends StatefulWidget {
  const LiveOrderTrackingScreen({
    super.key,
    this.initialOrder,
    this.orderService,
  });

  final OrderItem? initialOrder;
  final IOrderService? orderService;

  @override
  State<LiveOrderTrackingScreen> createState() => _LiveOrderTrackingScreenState();
}

class _LiveOrderTrackingScreenState extends State<LiveOrderTrackingScreen> {
  int _currentStep = 1; // 1: Placed, 2: Verified, 3: Packed, 4: Out for Delivery, 5: Delivered
  OrderItem? _order;
  bool _isLoading = true;
  bool _isDeliveryConfirmed = false;
  late final IOrderService _orderService;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? const OrderService();
    _order = widget.initialOrder;
    if (_order != null) {
      _applyOrderStatus(_order!.status);
      _isLoading = false;
    } else {
      _syncLiveOrder();
    }
  }

  Future<void> _syncLiveOrder() async {
    setState(() => _isLoading = true);
    try {
      final latest = await _orderService.fetchLatestOrderForPatient();
      if (mounted) {
        setState(() {
          _order = latest;
          _isLoading = false;
          if (latest != null) {
            _applyOrderStatus(latest.status);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyOrderStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('delivered') || lower.contains('confirmed')) {
      _isDeliveryConfirmed = lower.contains('confirmed');
    }

    switch (lower) {
      case 'pending':
      case 'placed':
        _currentStep = 1;
        break;
      case 'verified':
      case 'confirmed':
      case 'store rx':
        _currentStep = 2;
        break;
      case 'packing':
      case 'packed':
        _currentStep = 3;
        break;
      case 'dispatched':
      case 'out_for_delivery':
      case 'out for delivery':
      case 'on way':
        _currentStep = 4;
        break;
      case 'delivered':
      case 'delivered & confirmed':
        _currentStep = 5;
        break;
      default:
        _currentStep = 1;
    }
  }

  String _getStatusDescription() {
    switch (_currentStep) {
      case 1:
        return 'Order placed and logged in pharmacy queue • Awaiting verification';
      case 2:
        return 'Prescription & inventory verified by licensed pharmacist';
      case 3:
        return 'Order packed and sealed for delivery';
      case 4:
        return 'Dispatched for direct delivery to your destination';
      case 5:
        return 'Successfully delivered to your destination';
      default:
        return 'Processing order';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          title: const Text('Live Order Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Live Order Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No Active Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have no active orders in the database. Browse inventory and place an order to track live delivery here.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MedicineSearchScreen()),
                    );
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search Medicines'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final orderId = _order!.id.length > 8 ? _order!.id.substring(0, 8).toUpperCase() : _order!.id;
    final address = _order!.deliveryAddress ?? 'Registered delivery address';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _order!.status.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    address,
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _syncLiveOrder,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STATUS STEPPER CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowTeal, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _order!.status,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Step $_currentStep of 5',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Stepper row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepNode(1, 'Placed', Icons.check, isDone: _currentStep >= 1, isActive: _currentStep == 1),
                      _buildStepConnector(isDone: _currentStep > 1),
                      _buildStepNode(2, 'Verified', Icons.check, isDone: _currentStep >= 2, isActive: _currentStep == 2),
                      _buildStepConnector(isDone: _currentStep > 2),
                      _buildStepNode(3, 'Packed', Icons.check, isDone: _currentStep >= 3, isActive: _currentStep == 3),
                      _buildStepConnector(isDone: _currentStep > 3),
                      _buildStepNode(4, 'Dispatched', Icons.two_wheeler, isDone: _currentStep >= 4, isActive: _currentStep == 4),
                      _buildStepConnector(isDone: _currentStep > 4),
                      _buildStepNode(5, 'Delivered', Icons.home, isDone: _currentStep >= 5, isActive: _currentStep == 5),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _getStatusDescription(),
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // DELIVERY CONFIRMATION / VERIFICATION PROMPT CARD
            if (_order!.status.toLowerCase().contains('delivered')) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                        ? const Color(0xFF34A853)
                        : const Color(0xFFFFB300),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                              ? Icons.verified
                              : Icons.mark_email_read_outlined,
                          color: _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                              ? const Color(0xFF137333)
                              : const Color(0xFFF57F17),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                              ? 'Delivery Verified & Confirmed'
                              : 'Delivery Confirmation Required',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                                ? const Color(0xFF137333)
                                : const Color(0xFFF57F17),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDeliveryConfirmed || _order!.status.toLowerCase() == 'delivered & confirmed'
                          ? 'You have successfully verified delivery receipt of this order. Thank you for choosing CareWell Pharma!'
                          : 'The pharmacy partner has marked this order as delivered. Please confirm that you have received your medicine package.',
                      style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                    ),
                    if (!_isDeliveryConfirmed && _order!.status.toLowerCase() == 'delivered') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isDeliveryConfirmed = true);
                            await _orderService.updateOrderStatus(_order!.id, 'Delivered & Confirmed');
                            if (mounted) {
                              setState(() {
                                _order = _order!.copyWith(status: 'Delivered & Confirmed');
                              });
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Delivery receipt confirmed and verified!')),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Confirm Delivery Received'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00685F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // REAL DELIVERY DESTINATION CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowTeal, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Delivery Destination',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                  if (_order!.deliveryLatitude != null && _order!.deliveryLongitude != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'GPS Coordinates: ${_order!.deliveryLatitude!.toStringAsFixed(4)}, ${_order!.deliveryLongitude!.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ],
                  if (_order!.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ordered on: ${_order!.createdAt!.toLocal().toString().split('.')[0]}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ORDER ITEMS SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowTeal, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Items Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildItemRow(
                    _order!.medicineName,
                    '${_order!.quantity} Unit(s)',
                    '₹${_order!.totalPrice.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Paid',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${_order!.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepNode(int step, String label, IconData icon, {required bool isDone, required bool isActive}) {
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDone ? AppColors.primary : AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: isActive ? Border.all(color: AppColors.secondaryContainer, width: 2.5) : null,
            ),
            child: Icon(
              icon,
              size: 13,
              color: isDone ? Colors.white : AppColors.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isDone ? AppColors.primary : AppColors.outline,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: isDone ? AppColors.primary : AppColors.surfaceContainerHigh,
      ),
    );
  }

  Widget _buildItemRow(String name, String pack, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(pack, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
        Text(price, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
