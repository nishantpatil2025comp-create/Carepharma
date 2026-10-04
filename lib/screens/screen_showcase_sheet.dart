import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'customer/customer_home_screen.dart';
import 'customer/search_results_screen.dart';
import 'customer/medicine_detail_screen.dart';
import 'customer/cart_checkout_screen.dart';
import 'customer/upload_prescription_screen.dart';
import 'customer/map_nearby_pharmacies_screen.dart';
import 'customer/live_order_tracking_screen.dart';
import 'pharmacy/pharmacy_registration_screen.dart';
import 'pharmacy/pharmacy_dashboard_screen.dart';
import 'pharmacy/pharmacy_inventory_screen.dart';
import 'pharmacy/pharmacy_self_delivery_screen.dart';
import 'auth/interactive_login_screen.dart';

/// Interactive modal sheet that allows instant navigation to all 12 app screens.
class ScreenShowcaseSheet extends StatelessWidget {
  const ScreenShowcaseSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScreenShowcaseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Screen Directory',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'All 12 screens from Stitch designs',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildSectionHeader('Customer Marketplace (7 Screens)'),
                _buildScreenTile(
                  context,
                  title: '1. Customer Home Screen',
                  subtitle: 'Savings hero, categories, nearby pharmacies, quick compare',
                  icon: Icons.home,
                  routeBuilder: (_) => const CustomerHomeScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '2. Search & Generic Results',
                  subtitle: 'Branded benchmark, salt equivalence, generic alternatives list',
                  icon: Icons.search,
                  routeBuilder: (_) => const SearchResultsScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '3. Medicine Detail & Comparison',
                  subtitle: 'Bio-equivalence, 69% savings, pharmacy stock, quantity stepper',
                  icon: Icons.medication,
                  routeBuilder: (_) => const MedicineDetailScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '4. Cart & Multi-Pharmacy Checkout',
                  subtitle: 'Split store fulfillment, Rx verified, UPI/COD, bill breakdown',
                  icon: Icons.shopping_cart,
                  routeBuilder: (_) => const CartCheckoutScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '5. Upload Prescription & Records',
                  subtitle: 'Camera/gallery upload, verification rules, past Rx history',
                  icon: Icons.upload_file,
                  routeBuilder: (_) => const UploadPrescriptionScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '6. Map Nearby Pharmacies',
                  subtitle: 'Interactive map, delivery/pickup toggle, pharmacy pins & bottom sheet',
                  icon: Icons.map,
                  routeBuilder: (_) => const MapNearbyPharmaciesScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '7. Live Order Tracking',
                  subtitle: '5-stage live stepper, store runner card, route map, cold-chain tag',
                  icon: Icons.delivery_dining,
                  routeBuilder: (_) => const LiveOrderTrackingScreen(),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Pharmacy Partner Portal (4 Screens)'),
                _buildScreenTile(
                  context,
                  title: '8. Pharmacy Partner Registration',
                  subtitle: '4-step onboarding, drug license Form 20/21, delivery operations',
                  icon: Icons.app_registration,
                  routeBuilder: (_) => const PharmacyRegistrationScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '9. Pharmacy Web / Portal Dashboard',
                  subtitle: 'Order queue, live audio alerts, KPI metrics, generic requests',
                  icon: Icons.dashboard,
                  routeBuilder: (_) => const PharmacyDashboardScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '10. Generic Inventory Management',
                  subtitle: 'Stock catalog, live Supabase CRUD, low stock alerts, add medicine',
                  icon: Icons.inventory_2,
                  routeBuilder: (_) => const PharmacyInventoryScreen(),
                ),
                _buildScreenTile(
                  context,
                  title: '11. Self-Delivery & Runner Dispatch',
                  subtitle: 'Runner assignment, stage progression, customer address verification',
                  icon: Icons.local_shipping,
                  routeBuilder: (_) => const PharmacySelfDeliveryScreen(),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Authentication & Portal (1 Screen)'),
                _buildScreenTile(
                  context,
                  title: '12. Interactive Multi-Role Login Portal',
                  subtitle: 'Role selector, User login form, Pharmacy Admin login form with demo autofill',
                  icon: Icons.security,
                  routeBuilder: (_) => const InteractiveLoginScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildScreenTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget Function(BuildContext) routeBuilder,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: routeBuilder));
        },
      ),
    );
  }
}
