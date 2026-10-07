import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/map_launcher_service.dart';
import '../../theme/app_colors.dart';

/// Screen displaying nearby pharmacies dynamically sorted by live GPS proximity.
/// Fetches actual store coordinates from Supabase 'pharmacies' table.
class RealNearbyPharmaciesScreen extends StatefulWidget {
  const RealNearbyPharmaciesScreen({super.key});

  @override
  State<RealNearbyPharmaciesScreen> createState() => _RealNearbyPharmaciesScreenState();
}

class _RealNearbyPharmaciesScreenState extends State<RealNearbyPharmaciesScreen> {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool isLoading = true;
  List<Map<String, dynamic>> pharmacies = [];
  Position? userPosition;
  String _locationStatus = 'Locating...';

  @override
  void initState() {
    super.initState();
    _fetchLocationAndPharmacies();
  }

  Future<void> _fetchLocationAndPharmacies() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _locationStatus = 'Acquiring GPS coordinates...';
    });

    try {
      Position? position;

      // 1. Safe GPS Location Acquisition with timeout and fallback
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );

        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission().timeout(
            const Duration(seconds: 1),
            onTimeout: () => LocationPermission.denied,
          );

          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission().timeout(
              const Duration(seconds: 2),
              onTimeout: () => LocationPermission.denied,
            );
          }

          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 3),
                ),
              ).timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException('GPS acquisition timed out'),
              );
            } catch (posErr) {
              debugPrint('[RealNearbyPharmacies] Current position note: $posErr. Attempting last known position.');
              position = await Geolocator.getLastKnownPosition().timeout(
                const Duration(seconds: 1),
                onTimeout: () => null,
              );
            }
          }
        }
      } catch (locErr) {
        debugPrint('[RealNearbyPharmacies] Geolocator service check note: $locErr');
      }

      final Position currentPos = position ??
          Position(
            latitude: 18.5590,
            longitude: 73.7868,
            timestamp: DateTime.now(),
            accuracy: 100,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

      if (mounted) {
        setState(() {
          userPosition = currentPos;
          _locationStatus = 'GPS: ${currentPos.latitude.toStringAsFixed(4)}, ${currentPos.longitude.toStringAsFixed(4)}';
        });
      }

      // 2. Fetch pharmacies from Supabase
      final client = _supabase;
      List<dynamic> response = [];
      if (client != null) {
        try {
          response = await client
              .from('pharmacies')
              .select()
              .timeout(const Duration(seconds: 5));
        } catch (dbErr) {
          debugPrint('[RealNearbyPharmacies] Supabase fetch pharmacies note: $dbErr');
        }
      }

      final rawList = List<Map<String, dynamic>>.from(response);

      // Helper to safely extract double from coordinate fields (casing resilient)
      double? parseCoord(dynamic val) {
        if (val == null) return null;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString());
      }

      // 3. Calculate distance and attach to items
      final List<Map<String, dynamic>> computed = [];
      for (var pharmacy in rawList) {
        final item = Map<String, dynamic>.from(pharmacy);
        final lat = parseCoord(
          item['latitude'] ??
          item['Latitude'] ??
          item['lat'] ??
          item['Lat'],
        );
        final lng = parseCoord(
          item['longitude'] ??
          item['Longitude'] ??
          item['lng'] ??
          item['Lng'] ??
          item['lon'] ??
          item['Lon'],
        );

        item['latitude'] = lat;
        item['longitude'] = lng;

        if (lat != null && lng != null) {
          final distanceMeters = Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            lat,
            lng,
          );
          item['distance_km'] = distanceMeters / 1000.0;
        } else {
          item['distance_km'] = 999999.0;
        }
        computed.add(item);
      }

      // Sort by proximity ascending
      computed.sort((a, b) {
        final da = a['distance_km'] as double? ?? 999999.0;
        final db = b['distance_km'] as double? ?? 999999.0;
        return da.compareTo(db);
      });

      if (mounted) {
        setState(() {
          pharmacies = computed;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RealNearbyPharmacies] General fetch error: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location & Stores',
            onPressed: _fetchLocationAndPharmacies,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Container(
            color: Colors.teal.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 13, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Calculating store proximity...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : pharmacies.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No registered pharmacies found in database.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Partner stores will appear here sorted dynamically by proximity.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: pharmacies.length,
                  itemBuilder: (context, index) {
                    final item = pharmacies[index];
                    final name = (item['Name'] ?? item['name'] ?? 'Unnamed Pharmacy').toString();
                    final location = (item['Location'] ?? item['location'] ?? item['Address'] ?? item['address'] ?? 'Local Area').toString();
                    final phone = (item['Phone'] ?? item['phone'] ?? '').toString();
                    final dist = item['distance_km'] as double?;
                    final distStr = (dist != null && dist < 999990.0)
                        ? (dist < 1.0 ? '${(dist * 1000).round()} m away' : '${dist.toStringAsFixed(1)} km away')
                        : 'Distance unavailable';

                    final lat = item['latitude'] as double?;
                    final lng = item['longitude'] as double?;

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.teal.shade50,
                                  child: Icon(Icons.local_pharmacy, color: Colors.teal.shade700, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                phone,
                                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    distStr,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 12),
                                  ),
                                ),
                                if (lat != null && lng != null)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.directions, color: AppColors.primary, size: 16),
                                    label: const Text('Directions', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => openGoogleMapsRoute(lat, lng),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
