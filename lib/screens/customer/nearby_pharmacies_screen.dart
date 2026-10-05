import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/pharmacy_service.dart';
import '../../services/map_launcher_service.dart';
import '../../models/pharmacy.dart';
import '../../theme/app_colors.dart';
import '../pharmacy/add_pharmacy_screen.dart';
import 'map_nearby_pharmacies_screen.dart';
import 'search_results_screen.dart';

/// Screen 6b: GPS-Powered Nearby Pharmacies List
/// Fetches pharmacy coordinates from Supabase, calculates geodesic distance
/// from the user's real GPS position using the `geolocator` package,
/// and sorts the stores ascending by proximity.
class NearbyPharmaciesScreen extends StatefulWidget {
  const NearbyPharmaciesScreen({
    super.key,
    this.pharmacyService,
  });

  final IPharmacyService? pharmacyService;

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  late final IPharmacyService _pharmacyService;

  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;
  bool _isLocating = false;
  String? _errorMessage;

  // Current user GPS position (defaults to Baner, Pune until real GPS is acquired)
  double _userLat = 18.5590;
  double _userLng = 73.7868;
  bool _hasRealGps = false;
  String _locationStatus = 'Using Default Location (Baner, Pune)';

  @override
  void initState() {
    super.initState();
    _pharmacyService = widget.pharmacyService ?? const PharmacyService();
    _initLocationAndFetch();
  }

  /// Attempts to acquire the device's real GPS coordinates and load stores.
  Future<void> _initLocationAndFetch() async {
    await _acquireGpsLocation();
    await _loadPharmacies();
  }

  /// Uses geolocator to request permissions and read real-time GPS position.
  Future<void> _acquireGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'GPS Disabled (Using default Baner, Pune)';
          _hasRealGps = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => LocationPermission.denied,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => LocationPermission.denied,
        );
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Permission Denied (Using default Baner, Pune)';
            _hasRealGps = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Permission Denied Forever (Using default Baner, Pune)';
          _hasRealGps = false;
        });
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 2)),
        ).timeout(const Duration(seconds: 2));
      } catch (posErr) {
        debugPrint('[NearbyPharmaciesScreen] getCurrentPosition note: $posErr. Trying last known position.');
        pos = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 1),
          onTimeout: () => null,
        );
      }

      if (pos != null) {
        final nonNullPos = pos;
        setState(() {
          _userLat = nonNullPos.latitude;
          _userLng = nonNullPos.longitude;
          _hasRealGps = true;
          _locationStatus = 'Live GPS: ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)}';
        });
      } else {
        setState(() {
          _locationStatus = 'GPS fallback (Baner, Pune)';
        });
      }
    } catch (e) {
      debugPrint('[NearbyPharmaciesScreen] Geolocator note: $e');
      setState(() {
        _locationStatus = 'GPS fallback (Baner, Pune)';
      });
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Fetches stores from Supabase and sorts them by proximity to [_userLat], [_userLng].
  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _pharmacyService.fetchPharmacies(
        userLat: _userLat,
        userLng: _userLng,
      );

      if (mounted) {
        setState(() {
          _pharmacies = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLocationAndPharmacies() async {
    await _acquireGpsLocation();
    await _loadPharmacies();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Proximity updated relative to: $_locationStatus')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'Refresh Current GPS',
            onPressed: _isLocating ? null : _refreshLocationAndPharmacies,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.primary),
            tooltip: 'View Visual Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapNearbyPharmaciesScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _acquireGpsLocation();
          await _loadPharmacies();
        },
        child: Column(
          children: [
            // Top Proximity Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  Icon(
                    _hasRealGps ? Icons.gps_fixed : Icons.location_on_outlined,
                    size: 16,
                    color: _hasRealGps ? const Color(0xFF00685F) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationStatus,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddPharmacyScreen()),
                      );
                      _loadPharmacies();
                    },
                    icon: const Icon(Icons.add_business, size: 14),
                    label: const Text('+ Register Store', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Pharmacy Proximity List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                                const SizedBox(height: 8),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadPharmacies, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : _pharmacies.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.storefront_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text('No pharmacies registered yet in this area.'),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AddPharmacyScreen()),
                                    ),
                                    child: const Text('Register First Pharmacy'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _pharmacies.length,
                              itemBuilder: (context, index) {
                                final store = _pharmacies[index];
                                final isClosest = index == 0 && store.distanceKm != null;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isClosest ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade200,
                                      width: isClosest ? 1.5 : 1.0,
                                    ),
                                  ),
                                  elevation: isClosest ? 2 : 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Store Name & Proximity Badge
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (isClosest)
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE6F4EA),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'NEAREST PHARMACY',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF137333),
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  Text(
                                                    store.name,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (store.license != null && store.license!.isNotEmpty)
                                                    Text(
                                                      'Lic: ${store.license!}',
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Proximity Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isClosest ? const Color(0xFF00685F) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.near_me,
                                                    size: 13,
                                                    color: isClosest ? Colors.white : const Color(0xFF00685F),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    store.formattedDistance,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isClosest ? Colors.white : const Color(0xFF00685F),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Address & Coordinates
                                        if (store.location != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.location_on, size: 15, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    store.location!,
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Store Metrics Row (Rating, Status)
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.verified, size: 14, color: Color(0xFF00685F)),
                                                const SizedBox(width: 3),
                                                const Text(
                                                  'Verified Chemist',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00685F)),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.access_time, size: 13, color: Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  store.openStatus,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // Action CTAs
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (store.phone != null && store.phone!.isNotEmpty)
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Calling ${store.name}: ${store.phone!}')),
                                                  );
                                                },
                                                icon: const Icon(Icons.call, size: 16),
                                                label: const Text('Call'),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  minimumSize: Size.zero,
                                                ),
                                              ),
                                            if (store.latitude != null && store.longitude != null)
                                              OutlinedButton.icon(
                                                onPressed: () => openGoogleMapsRoute(store.latitude!, store.longitude!),
                                                icon: const Icon(Icons.directions, size: 16),
                                                label: const Text('Directions'),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  minimumSize: Size.zero,
                                                ),
                                              ),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const SearchResultsScreen()),
                                                );
                                              },
                                              icon: const Icon(Icons.medication_outlined, size: 16),
                                              label: const Text('Browse Stock'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00685F),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                minimumSize: Size.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
