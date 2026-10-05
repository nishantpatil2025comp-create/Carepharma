import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../services/cart_service.dart';
import '../../auth_service.dart';
import 'medicine_search_screen.dart';
import 'real_nearby_pharmacies_screen.dart';
import 'cart_screen.dart';
import 'upload_prescription_screen.dart';
import 'live_order_tracking_screen.dart';
import 'user_profile_screen.dart';
import '../../services/map_launcher_service.dart';

/// Screen 1: Customer Home Screen from stitch designs
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentNavIndex = 0;
  String _currentLocation = 'Baner, Pune';
  final TextEditingController _searchController = TextEditingController();
  final PharmacyService _pharmacyService = const PharmacyService();
  final AuthService _authService = const AuthService();
  final CartService _cartService = const CartService();
  List<Pharmacy> _nearbyPharmacies = [];
  bool _isLoadingPharmacies = true;
  int _cartCount = 0;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadLocationAndPharmacies();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    try {
      final items = await _cartService.fetchCartItems();
      if (mounted) {
        setState(() => _cartCount = items.length);
      }
    } catch (_) {}
  }

  Future<void> _loadLocationAndPharmacies() async {
    try {
      final profile = await _authService.getUserProfile();
      if (profile != null) {
        if (profile.deliveryAddress != null && profile.deliveryAddress!.isNotEmpty) {
          if (mounted) setState(() => _currentLocation = profile.deliveryAddress!);
        }
        if (profile.latitude != null && profile.longitude != null) {
          _userLat = profile.latitude;
          _userLng = profile.longitude;
        }
      }
    } catch (_) {}

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (serviceEnabled) {
        final perm = await Geolocator.checkPermission().timeout(
          const Duration(milliseconds: 500),
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
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
          }
          if (pos != null) {
            final capturedPos = pos;
            _userLat = capturedPos.latitude;
            _userLng = capturedPos.longitude;
            if (mounted && _currentLocation == 'Baner, Pune') {
              setState(() {
                _currentLocation = 'GPS (${capturedPos.latitude.toStringAsFixed(3)}, ${capturedPos.longitude.toStringAsFixed(3)})';
              });
            }
          }
        }
      }
    } catch (_) {}

    try {
      final stores = await _pharmacyService.fetchPharmacies(userLat: _userLat, userLng: _userLng);
      if (mounted) {
        setState(() {
          _nearbyPharmacies = stores;
          _isLoadingPharmacies = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPharmacies = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToSearch([String query = '']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineSearchScreen(initialQuery: query),
      ),
    ).then((_) => _loadCartCount());
  }

  Future<void> _fetchGpsLocation() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Acquiring live GPS location...'), duration: Duration(seconds: 1)),
      );

      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Please enable GPS location services on your device.')),
          );
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

      if (pos != null) {
        final currentPos = pos;
        if (mounted) {
          setState(() {
            _userLat = currentPos.latitude;
            _userLng = currentPos.longitude;
            _currentLocation = 'GPS: ${currentPos.latitude.toStringAsFixed(4)}, ${currentPos.longitude.toStringAsFixed(4)}';
            _isLoadingPharmacies = true;
          });
        }
        final stores = await _pharmacyService.fetchPharmacies(userLat: currentPos.latitude, userLng: currentPos.longitude);
        if (mounted) {
          setState(() {
            _nearbyPharmacies = stores;
            _isLoadingPharmacies = false;
          });
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not determine GPS coordinates. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get GPS location: $e')),
        );
      }
    }
  }

  void _openLocationSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Delivery Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.primary),
              title: const Text('Use Live GPS Location'),
              subtitle: Text(_userLat != null ? '${_userLat!.toStringAsFixed(4)}, ${_userLng!.toStringAsFixed(4)}' : 'Detect via device GPS sensors'),
              trailing: const Icon(Icons.gps_fixed, color: AppColors.primary),
              onTap: () {
                Navigator.pop(ctx);
                _fetchGpsLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_pin_circle_outlined, color: AppColors.primary),
              title: const Text('Saved Profile Address'),
              subtitle: Text(_currentLocation),
              trailing: const Icon(Icons.check, color: AppColors.primary),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined, color: AppColors.outline),
              title: const Text('Edit Address in Profile'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                ).then((_) => _loadLocationAndPharmacies());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: AppColors.surfaceContainerLowest,
          elevation: 0,
          scrolledUnderElevation: 1,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: InkWell(
            onTap: _openLocationSelector,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DELIVER TO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _currentLocation,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // User Profile
            IconButton(
              icon: const Icon(Icons.person_outline, color: AppColors.primary),
              tooltip: 'User Profile & Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                ).then((_) => _loadLocationAndPharmacies());
              },
            ),
            // Cart badge
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.onSurface),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      ).then((_) => _loadCartCount());
                    },
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$_cartCount',
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowTeal,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _navigateToSearch,
                  decoration: InputDecoration(
                    hintText: 'Search for medicine or generic salt...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.outline),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.mic, color: AppColors.primary, size: 20),
                          onPressed: () => _navigateToSearch(''),
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Genuine Certification Micro-Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondaryFixed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '100% Genuine & CDSCO Certified Generics',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSecondaryFixed,
                        ),
                      ),
                    ),
                    Text(
                      'Learn ›',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Prominent Hero Banner: Generic Savings
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryContainer,
                      AppColors.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.savings, size: 14, color: AppColors.onSecondaryFixed),
                          SizedBox(width: 4),
                          Text(
                            'GENIMED SAVINGS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSecondaryFixed,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Save up to 60% with generic alternatives',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Switch to high-quality bio-equivalent generics and cut down your monthly recurring pharmacy bills drastically.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onPrimaryContainer,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToSearch(''),
                      icon: const Text(
                        'Compare Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      label: const Icon(Icons.arrow_forward, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLowest,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Upload Prescription Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.photo_camera, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Prescription',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Let our licensed pharmacists verify & arrange your generics',
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.onSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Pharmacies Near You Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pharmacies Near You',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        Text(
                          'Verified generic fulfillment partners',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RealNearbyPharmaciesScreen()),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.near_me, size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'View on map',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 160,
              child: _isLoadingPharmacies
                  ? const Center(child: CircularProgressIndicator())
                  : _nearbyPharmacies.isEmpty
                      ? const Center(
                          child: Text(
                            'No registered pharmacies found in your proximity.',
                            style: TextStyle(color: AppColors.outline, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _nearbyPharmacies.length,
                          itemBuilder: (context, index) {
                            final p = _nearbyPharmacies[index];
                            final dist = p.distanceKm != null
                                ? p.formattedDistance
                                : ((p.location != null && p.location!.isNotEmpty) ? p.location! : 'Proximity GPS');
                            return _buildPharmacyCard(
                              name: p.name,
                              distance: dist,
                              address: p.location,
                              deliveryTime: 'Same Day Delivery',
                              latitude: p.latitude,
                              longitude: p.longitude,
                            );
                          },
                        ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.surfaceContainer, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentNavIndex,
          onDestinationSelected: (index) {
            setState(() => _currentNavIndex = index);
            if (index == 1) {
              _navigateToSearch('');
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveOrderTrackingScreen()),
              );
            } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              ).then((_) => _loadLocationAndPharmacies());
            }
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.secondaryFixed.withValues(alpha: 0.5),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }


  Widget _buildPharmacyCard({
    required String name,
    required String distance,
    String? address,
    required String deliveryTime,
    double? latitude,
    double? longitude,
  }) {
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTeal,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.verified, color: AppColors.primary, size: 16),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address != null && address.isNotEmpty ? '$distance • $address' : distance,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 13, color: AppColors.primary),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    deliveryTime.toLowerCase().contains('delivery')
                        ? deliveryTime
                        : 'Delivers in $deliveryTime',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSecondaryFixed),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (latitude != null && longitude != null)
                InkWell(
                  onTap: () => openGoogleMapsRoute(latitude, longitude),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions, size: 14, color: AppColors.primary),
                      SizedBox(width: 2),
                      Text(
                        'Directions',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Generic: Active',
                  style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RealNearbyPharmaciesScreen()),
                  );
                },
                child: const Text('Visit ›', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
