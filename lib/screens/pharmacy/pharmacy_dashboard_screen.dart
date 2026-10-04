import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../screen_showcase_sheet.dart';
import 'pharmacy_inventory_screen.dart';
import 'pharmacy_self_delivery_screen.dart';

/// Screen 9: Pharmacy Partner Web/Portal Operations Dashboard
class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  bool _isAcceptingOrders = true;
  bool _isAudioAlertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Flexible(
                  child: Text(
                    'Apollo Meds & Wellness',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
            ),
            Text(
              'Baner, Pune (Branch #12) • Lic: MH-PUN-2024-8891',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Audio alerts toggle
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
      body: SingleChildScrollView(
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

            // KPI METRIC CARDS GRID
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _buildKpiCard('Today\'s Orders', '34', '+12% vs y\'day', Icons.receipt_long, AppColors.primary),
                _buildKpiCard('Gross Revenue', '₹14,850', '68% generics', Icons.payments, AppColors.secondary),
                _buildKpiCard('Pending Packing', '5', 'Action required', Icons.inventory_2, AppColors.tertiary),
                _buildKpiCard('Active Dispatches', '4', 'Store runners', Icons.two_wheeler, AppColors.userBlue),
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Live Orders Fulfillment Queue (5)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Auto-refresh (5s)',
                  style: TextStyle(fontSize: 11, color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildOrderQueueCard(
              orderId: 'Order #GM-89421',
              time: '2 mins ago',
              customer: 'Aniket Mehta • Baner High St (1.2 km)',
              items: 'Paracetamol IP 650mg x2, Cetirizine 10mg x1',
              total: '₹48.50 (Prepaid UPI)',
              isColdChain: true,
              actionLabel: 'Pack & Assign Runner',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PharmacySelfDeliveryScreen()),
                );
              },
            ),
            _buildOrderQueueCard(
              orderId: 'Order #GM-89418',
              time: '14 mins ago',
              customer: 'Priya Sharma • Pancard Club Rd (0.8 km)',
              items: 'Metformin 500mg SR x2 strips',
              total: '₹36.00 (Cash on Delivery)',
              isColdChain: false,
              actionLabel: 'Verify Rx & Pack',
              onAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order #GM-89418 marked Packed!')),
                );
              },
            ),
            const SizedBox(height: 20),

            // GENERIC SUBSTITUTION REQUESTS CARD
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
                                'Patient Generic Switch Request',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Save 69%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Prescribed: Crocin 650mg (MRP ₹58.50) -> Requested: Paracetamol IP 650mg Genext (₹18.00)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Generic substitution approved and confirmed to patient!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                      child: const Text('Approve Generic Bio-Equivalent & Dispense'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildOrderQueueCard({
    required String orderId,
    required String time,
    required String customer,
    required String items,
    required String total,
    required bool isColdChain,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: orderId,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: ' • $time',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: AppColors.outline),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isColdChain) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ac_unit, size: 11, color: AppColors.tertiary),
                      SizedBox(width: 3),
                      Text('Cold Chain', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onTertiaryFixed)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(customer, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text(items, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  total,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
