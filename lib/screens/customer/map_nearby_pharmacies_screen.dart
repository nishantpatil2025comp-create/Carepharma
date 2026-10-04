import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'medicine_detail_screen.dart';

/// Screen 6: Interactive Map & Nearby Pharmacies Navigator
class MapNearbyPharmaciesScreen extends StatefulWidget {
  const MapNearbyPharmaciesScreen({super.key});

  @override
  State<MapNearbyPharmaciesScreen> createState() => _MapNearbyPharmaciesScreenState();
}

class _MapNearbyPharmaciesScreenState extends State<MapNearbyPharmaciesScreen> {
  bool _isPickupMode = true;
  int _selectedPharmacyIndex = 0;

  final List<Map<String, dynamic>> _pharmacies = [
    {
      'name': 'HealthPlus Pharmacy',
      'distance': '1.2 km away',
      'eta': '25 mins pickup • 35 mins delivery',
      'rating': '4.8',
      'reviews': '120+',
      'openStatus': 'Open until 11:00 PM',
      'genericStock': 'Paracetamol IP (₹18.00 - Save 69%)',
      'address': 'Shop 4, High Street, Baner, Pune',
      'phone': '+91 98230 11234',
    },
    {
      'name': 'MedLife Generic Care',
      'distance': '0.8 km away',
      'eta': '15 mins pickup • 25 mins delivery',
      'rating': '4.9',
      'reviews': '340+',
      'openStatus': 'Open 24 Hours',
      'genericStock': 'Paracip 650 (₹21.00 - Save 64%)',
      'address': 'Ground Floor, Pancard Club Rd, Baner',
      'phone': '+91 98230 55678',
    },
    {
      'name': 'Apollo Jan Aushadhi Store',
      'distance': '2.4 km away',
      'eta': '30 mins pickup • 45 mins delivery',
      'rating': '4.7',
      'reviews': '85',
      'openStatus': 'Open until 10:00 PM',
      'genericStock': 'P-650 Generic (₹24.00 - Save 59%)',
      'address': 'Main Road, Aundh, Pune',
      'phone': '+91 98230 99887',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPharmacy = _pharmacies[_selectedPharmacyIndex];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          // Segmented mode pill: Delivery vs Pickup
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _isPickupMode = false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isPickupMode ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !_isPickupMode ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isPickupMode = true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isPickupMode ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront, size: 13, color: _isPickupMode ? Colors.white : AppColors.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isPickupMode ? Colors.white : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _buildMapFilterChip('In Stock: Paracetamol 650', Icons.check_circle, isSelected: true),
                _buildMapFilterChip('Open Now', Icons.schedule),
                _buildMapFilterChip('Within 2 km', Icons.near_me),
                _buildMapFilterChip('Top Rated 4.5+', Icons.star),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // SIMULATED VECTOR CLINICAL MAP CANVAS
          Positioned.fill(
            child: CustomPaint(
              painter: _ClinicalMapPainter(selectedPinIndex: _selectedPharmacyIndex),
            ),
          ),

          // Search this area floating button
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updated 3 pharmacies in current radius')),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Search this area', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.primary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),

          // User Current Location Pin
          Positioned(
            left: 100,
            top: 240,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Pharmacy Pin 1
          Positioned(
            left: 230,
            top: 110,
            child: _buildInteractivePin(0, 'HealthPlus', '₹18', isSelected: _selectedPharmacyIndex == 0),
          ),

          // Pharmacy Pin 2
          Positioned(
            left: 180,
            top: 310,
            child: _buildInteractivePin(1, 'MedLife', '₹21', isSelected: _selectedPharmacyIndex == 1),
          ),

          // Pharmacy Pin 3
          Positioned(
            right: 40,
            top: 210,
            child: _buildInteractivePin(2, 'Jan Aushadhi', '₹24', isSelected: _selectedPharmacyIndex == 2),
          ),

          // Bottom Sheet Carousel for Selected Pharmacy
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_pharmacy, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPharmacy['name'],
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 14, color: AppColors.tertiary),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${selectedPharmacy['rating']}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                                      ),
                                      Flexible(
                                        child: Text(
                                          ' (${selectedPharmacy['reviews']}) • ${selectedPharmacy['distance']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.outline),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Open Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryFixed)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medication, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedPharmacy['genericStock'],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling ${selectedPharmacy['name']}: ${selectedPharmacy['phone']}')),
                          );
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 42),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicineDetailScreen(
                                  medicineName: 'Paracetamol IP 650mg (${selectedPharmacy['name']})',
                                  genericPrice: 18.00,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View Available Stock'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(100, 42),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFilterChip(String label, IconData icon, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 14, color: isSelected ? AppColors.onSecondaryContainer : AppColors.primary),
        label: Text(label),
        backgroundColor: isSelected ? AppColors.secondaryContainer : AppColors.surfaceContainerLowest,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildInteractivePin(int index, String title, String price, {required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPharmacyIndex = index),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_pharmacy, size: 13, color: isSelected ? Colors.white : AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '$title • $price',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_drop_down, color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest, size: 20),
        ],
      ),
    );
  }
}

/// Custom painter for rendering the clean modern clinical vector map
class _ClinicalMapPainter extends CustomPainter {
  _ClinicalMapPainter({required this.selectedPinIndex});

  final int selectedPinIndex;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft Land Background
    final bgPaint = Paint()..color = const Color(0xFFEDF3EF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Green Park Zones
    final parkPaint = Paint()..color = const Color(0xFFD9EBD9);
    final parkPath1 = Path()
      ..moveTo(0, 80)
      ..quadraticBezierTo(80, 50, 120, 140)
      ..quadraticBezierTo(140, 220, 20, 260)
      ..close();
    canvas.drawPath(parkPath1, parkPaint);

    final parkPath2 = Path()
      ..moveTo(size.width - 100, 180)
      ..quadraticBezierTo(size.width - 20, 140, size.width, 220)
      ..lineTo(size.width, 360)
      ..quadraticBezierTo(size.width - 80, 320, size.width - 100, 180)
      ..close();
    canvas.drawPath(parkPath2, parkPaint);

    // 3. Main Roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFCDDBD4)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Road 1: Diagonal
    final road1 = Path()
      ..moveTo(0, 140)
      ..quadraticBezierTo(size.width * 0.4, 130, size.width, 180);
    canvas.drawPath(road1, roadBorderPaint);
    canvas.drawPath(road1, roadPaint);

    // Road 2: Vertical
    final road2 = Path()
      ..moveTo(size.width * 0.52, 0)
      ..lineTo(size.width * 0.52, size.height);
    canvas.drawPath(road2, roadBorderPaint);
    canvas.drawPath(road2, roadPaint);

    // Road 3: Cross street
    final road3 = Path()
      ..moveTo(20, 300)
      ..lineTo(size.width - 20, 270);
    canvas.drawPath(road3, roadBorderPaint);
    canvas.drawPath(road3, roadPaint);

    // 4. Dash Navigation Route to selected pin
    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(100, 240)
      ..quadraticBezierTo(150, 210, 230, 130);
    canvas.drawPath(routePath, routePaint);
  }

  @override
  bool shouldRepaint(covariant _ClinicalMapPainter oldDelegate) =>
      oldDelegate.selectedPinIndex != selectedPinIndex;
}
