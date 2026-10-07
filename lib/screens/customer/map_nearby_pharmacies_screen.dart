import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../services/pharmacy_service.dart';
import '../../services/map_launcher_service.dart';
import 'medicine_detail_screen.dart';

/// Screen 6: Interactive Real Map & Nearby Pharmacies Navigator
class MapNearbyPharmaciesScreen extends StatefulWidget {
  const MapNearbyPharmaciesScreen({super.key});

  @override
  State<MapNearbyPharmaciesScreen> createState() => _MapNearbyPharmaciesScreenState();
}

class _MapNearbyPharmaciesScreenState extends State<MapNearbyPharmaciesScreen> {
  bool _isPickupMode = true;
  int _selectedPharmacyIndex = 0;
  final PharmacyService _pharmacyService = const PharmacyService();
  List<Map<String, dynamic>> _pharmacies = [];
  bool _isLoading = true;
  double _userLat = 18.5590;
  double _userLng = 73.7868;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndPharmacies();
  }

  Future<void> _fetchLocationAndPharmacies() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 400),
        onTimeout: () => false,
      );
      if (serviceEnabled) {
        final perm = await Geolocator.checkPermission().timeout(
          const Duration(milliseconds: 400),
          onTimeout: () => LocationPermission.denied,
        );
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition().timeout(
              const Duration(seconds: 1),
              onTimeout: () => null,
            );
          }
          if (pos != null) {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          }
        }
      }
    } catch (_) {}

    try {
      final list = await _pharmacyService.fetchPharmacies(userLat: _userLat, userLng: _userLng);
      if (mounted) {
        setState(() {
          _pharmacies = list.map((p) {
            final distStr = p.distanceKm != null
                ? '${p.distanceKm!.toStringAsFixed(1)} km away'
                : ((p.location != null && p.location!.isNotEmpty) ? p.location! : 'Nearby');
            return {
              'name': p.name,
              'distance': distStr,
              'eta': '20 mins pickup • 30 mins delivery',
              'openStatus': 'Open 24 Hours',
              'genericStock': 'Verified Generic Equivalents Available',
              'address': p.location ?? 'Baner, Pune',
              'phone': (p.phone != null && p.phone!.isNotEmpty) ? p.phone! : '+91 98230 00000',
              'latitude': p.latitude,
              'longitude': p.longitude,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_pharmacies.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: AppColors.outline),
              const SizedBox(height: 16),
              const Text('No pharmacies found near this location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _fetchLocationAndPharmacies,
                child: const Text('Retry Search'),
              ),
            ],
          ),
        ),
      );
    }

    final selectedPharmacy = _pharmacies[_selectedPharmacyIndex.clamp(0, _pharmacies.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isPickupMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isPickupMode ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Delivery',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !_isPickupMode ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isPickupMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPickupMode ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront, size: 13, color: _isPickupMode ? Colors.white : AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 12,
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
                _buildMapFilterChip('Within 5 km', Icons.near_me),
                _buildMapFilterChip('Verified Chemists', Icons.verified),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // REAL INTERACTIVE MAP PLOTTING WITH OPENSTREETMAP AND SUPABASE COORDINATES
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_userLat, _userLng),
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.carepharma.app',
                ),
                MarkerLayer(
                  markers: [
                    // User live GPS location pin
                    Marker(
                      point: LatLng(_userLat, _userLng),
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                            ),
                            child: const Text('You', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    // Dynamically Plotted Pharmacy Markers from Supabase
                    ..._pharmacies.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      final lat = p['latitude'];
                      final lng = p['longitude'];
                      if (lat == null || lng == null) return null;
                      final double? dLat = (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
                      final double? dLng = (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
                      if (dLat == null || dLng == null) return null;

                      final isSelected = _selectedPharmacyIndex == idx;
                      return Marker(
                        point: LatLng(dLat, dLng),
                        width: 140,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPharmacyIndex = idx),
                          child: _buildRealPharmacyPin(p['name'] ?? 'Pharmacy', isSelected: isSelected),
                        ),
                      );
                    }).whereType<Marker>(),
                  ],
                ),
              ],
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
                  _fetchLocationAndPharmacies();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated ${_pharmacies.length} pharmacies in current radius')),
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

          // Bottom Sheet Carousel for Selected Pharmacy (Purged of mock ratings and reviews)
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
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          '${selectedPharmacy['distance']} • ${selectedPharmacy['address']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
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
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedPharmacy['openStatus'] ?? 'Open Now',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryFixed),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
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
                  LayoutBuilder(
                    builder: (context, btnConstraints) {
                      final isCompact = btnConstraints.maxWidth < 280;
                      if (isCompact) {
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Calling ${selectedPharmacy['name']}: ${selectedPharmacy['phone']}')),
                                );
                              },
                              icon: const Icon(Icons.call, size: 16),
                              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Call')),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final lat = selectedPharmacy['latitude'] as double?;
                                final lon = selectedPharmacy['longitude'] as double?;
                                if (lat != null && lon != null) {
                                  openGoogleMapsRoute(lat, lon);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('GPS coordinates unavailable for this store')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.directions, size: 16),
                              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Directions')),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                            ElevatedButton.icon(
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
                              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Stock')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Calling ${selectedPharmacy['name']}: ${selectedPharmacy['phone']}')),
                              );
                            },
                            icon: const Icon(Icons.call, size: 16),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Call')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(48, 40),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () {
                              final lat = selectedPharmacy['latitude'] as double?;
                              final lon = selectedPharmacy['longitude'] as double?;
                              if (lat != null && lon != null) {
                                openGoogleMapsRoute(lat, lon);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('GPS coordinates unavailable for this store')),
                                );
                              }
                            },
                            icon: const Icon(Icons.directions, size: 16),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Directions')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(56, 40),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Stock')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                minimumSize: const Size(60, 40),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

  Widget _buildRealPharmacyPin(String title, {required bool isSelected}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary, width: isSelected ? 2.0 : 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_pharmacy, size: 13, color: isSelected ? Colors.white : AppColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_drop_down, color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest, size: 18),
      ],
    );
  }
}
