import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/order.dart';
import '../../models/pharmacy.dart';
import '../../services/order_service.dart';
import '../../services/pharmacy_service.dart';
import '../../auth_service.dart';
import '../screen_showcase_sheet.dart';
import 'pharmacy_inventory_screen.dart';
import 'pharmacy_self_delivery_screen.dart';

/// Screen 9: Pharmacy Partner Web/Portal Operations Dashboard
class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({
    super.key,
    this.pharmacyService,
    this.orderService,
    this.authService,
  });

  final IPharmacyService? pharmacyService;
  final IOrderService? orderService;
  final AuthService? authService;

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  bool _isAcceptingOrders = true;
  bool _isAudioAlertsEnabled = true;

  late final IPharmacyService _pharmacyService;
  late final IOrderService _orderService;
  late final AuthService _authService;

  Pharmacy? _pharmacy;
  List<OrderItem> _orders = [];
  bool _isLoading = true;

  static const List<String> _lifecyclePhases = [
    'Pending',
    'Packing',
    'Dispatched',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _pharmacyService = widget.pharmacyService ?? const PharmacyService();
    _orderService = widget.orderService ?? const OrderService();
    _authService = widget.authService ?? const AuthService();
    _loadPharmacyAndOrders();
  }

  Future<void> _loadPharmacyAndOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      final pharmacy = await _pharmacyService.fetchPharmacyForOwner(user?.id, email: user?.email);
      final activePharmacy = pharmacy ??
          const Pharmacy(
            uid: 'PH-UID-1001',
            name: 'Apollo Meds & Wellness',
            location: 'Baner Road, Baner, Pune',
            phone: '+91 98234 56789',
            license: 'MH-PUN-2024-8891',
          );

      final orders = await _orderService.fetchOrdersForPharmacy(activePharmacy.uid);

      if (mounted) {
        setState(() {
          _pharmacy = activePharmacy;
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PharmacyDashboard] Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(OrderItem order, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    await _orderService.updateOrderStatus(order.id, newStatus);
    if (mounted) {
      setState(() {
        final index = _orders.indexWhere((o) => o.id == order.id);
        if (index != -1) {
          _orders[index] = _orders[index].copyWith(status: newStatus);
        }
      });
      final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
      messenger.showSnackBar(
        SnackBar(content: Text('Order #$shortId moved to $newStatus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyName = _pharmacy?.name ?? 'Apollo Meds & Wellness';
    final pharmacyLocation = _pharmacy?.location ?? 'Baner, Pune';
    final pharmacyLicense = _pharmacy?.license ?? 'MH-PUN-2024-8891';

    // Calculate real dynamic KPIs
    final totalOrdersCount = _orders.length;
    final grossRevenue = _orders.fold<double>(0.0, (sum, o) => sum + o.totalPrice);
    final pendingPackingCount = _orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'pending' || s == 'placed' || s == 'packing' || s == 'packed';
    }).length;
    final activeDispatchesCount = _orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'dispatched' || s == 'out for delivery' || s == 'out_for_delivery';
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    pharmacyName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
            ),
            Text(
              '$pharmacyLocation • Lic: $pharmacyLicense',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Refresh Orders',
            onPressed: _loadPharmacyAndOrders,
          ),
          IconButton(
            icon: Icon(
              _isAudioAlertsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isAudioAlertsEnabled ? AppColors.primary : AppColors.outline,
            ),
            tooltip: 'Audio Order Alerts',
            onPressed: () {
              setState(() => _isAudioAlertsEnabled = !_isAudioAlertsEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_isAudioAlertsEnabled ? 'Live audio notifications ON' : 'Audio alerts muted')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: AppColors.primary),
            tooltip: 'All Screens Directory',
            onPressed: () => ScreenShowcaseSheet.show(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadPharmacyAndOrders,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accepting Orders Status Toggle Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isAcceptingOrders
                            ? AppColors.secondaryContainer.withValues(alpha: 0.3)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isAcceptingOrders ? AppColors.secondary : AppColors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _isAcceptingOrders ? AppColors.pharmacyGreen : AppColors.outline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isAcceptingOrders ? 'Accepting Orders (Online)' : 'Store Paused (Offline)',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const Text(
                                        'Incoming orders from 3.5 km radius automatically dispatched',
                                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isAcceptingOrders,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _isAcceptingOrders = val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_isAcceptingOrders ? 'Store is now LIVE' : 'Store order intake PAUSED')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DYNAMIC KPI METRIC CARDS GRID
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _buildKpiCard(
                          'Today\'s Orders',
                          totalOrdersCount.toString(),
                          'Active queue',
                          Icons.receipt_long,
                          AppColors.primary,
                        ),
                        _buildKpiCard(
                          'Gross Revenue',
                          '₹${grossRevenue.toStringAsFixed(0)}',
                          'Fulfilled total',
                          Icons.payments,
                          AppColors.secondary,
                        ),
                        _buildKpiCard(
                          'Pending Packing',
                          pendingPackingCount.toString(),
                          'Action required',
                          Icons.inventory_2,
                          AppColors.tertiary,
                        ),
                        _buildKpiCard(
                          'Active Dispatches',
                          activeDispatchesCount.toString(),
                          'Store runners',
                          Icons.two_wheeler,
                          AppColors.userBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // QUICK NAVIGATION TABS TO INVENTORY & DELIVERY
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PharmacyInventoryScreen()),
                              );
                            },
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Manage Stock Catalog'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLowest,
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PharmacySelfDeliveryScreen()),
                              );
                            },
                            icon: const Icon(Icons.local_shipping),
                            label: const Text('Self-Fleet Dispatch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // LIVE INCOMING ORDERS QUEUE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Live Orders Fulfillment Queue (${_orders.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_orders.length} orders total',
                          style: const TextStyle(fontSize: 11, color: AppColors.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_orders.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No orders found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Orders placed by patients in your delivery radius will appear in this queue in real-time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._orders.map((order) => _buildLiveOrderCard(order)),

                    const SizedBox(height: 20),

                    // GENERIC SUBSTITUTION POLICY CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.compare_arrows, color: AppColors.secondary, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Generic Substitution Policy',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Licensed pharmacists can dispense bio-equivalent generic medicines matching active salts to offer patient savings of up to 70%.',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtext, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.shadowTeal, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(subtext, style: const TextStyle(fontSize: 10, color: AppColors.outline), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildLiveOrderCard(OrderItem order) {
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final currentStatus = order.status;
    final normalizedStatus = _lifecyclePhases.firstWhere(
      (phase) => phase.toLowerCase() == currentStatus.toLowerCase(),
      orElse: () => _lifecyclePhases.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Order #$shortId',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: ' • ${order.formattedDate}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: AppColors.outline),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentStatus.toLowerCase() == 'delivered'
                      ? const Color(0xFFE6F4EA)
                      : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: currentStatus.toLowerCase() == 'delivered'
                        ? const Color(0xFF137333)
                        : AppColors.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.patientEmail,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Destination: ${order.deliveryAddress}',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${order.medicineName} x${order.quantity}',
            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Lifecycle phase progression and total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${order.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(width: 8),

              // Phase dropdown selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: normalizedStatus,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                    items: _lifecyclePhases.map((phase) {
                      return DropdownMenuItem<String>(
                        value: phase,
                        child: Text(phase),
                      );
                    }).toList(),
                    onChanged: (newPhase) {
                      if (newPhase != null && newPhase != currentStatus) {
                        _updateStatus(order, newPhase);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

