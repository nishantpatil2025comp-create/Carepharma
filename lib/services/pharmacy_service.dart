import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pharmacy.dart';

/// Interface for pharmacy store operations.
abstract class IPharmacyService {
  Future<List<Pharmacy>> fetchPharmacies({double? userLat, double? userLng});
  Future<void> registerPharmacy(Pharmacy pharmacy);
  Future<void> updatePharmacy(Pharmacy pharmacy);
  Future<Pharmacy?> fetchPharmacyForOwner(String? ownerId, {String? email});
  double calculateDistance(double startLat, double startLng, double endLat, double endLng);
}

/// Service managing Supabase pharmacy store operations and GPS proximity sorting.
class PharmacyService implements IPharmacyService {
  const PharmacyService({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory registered pharmacies for offline/test environments (client == null)
  static final List<Pharmacy> _inMemoryPharmacies = [
    const Pharmacy(
      uid: 'PH-UID-1001',
      name: 'Apollo Meds & Wellness',
      location: 'Baner Road, Baner, Pune',
      phone: '+91 98234 56789',
      email: 'pharmacist@apollomeds.com',
      latitude: 18.5590,
      longitude: 73.7868,
      license: 'MH-PUN-2022-10492',
    ),
    const Pharmacy(
      uid: 'PH-UID-1002',
      name: 'HealthPlus Pharmacy',
      location: 'Aundh ITI Road, Pune',
      phone: '+91 98221 44332',
      email: 'healthplus.baner@gmail.com',
      latitude: 18.5580,
      longitude: 73.8075,
      license: 'MH-PUN-2021-09844',
    ),
    const Pharmacy(
      uid: 'PH-UID-1003',
      name: 'Jan Aushadhi Generic Kendra',
      location: 'Balewadi High St, Pune',
      phone: '+91 98210 99887',
      email: 'janaushadhi.balewadi@gmail.com',
      latitude: 18.5750,
      longitude: 73.7710,
      license: 'MH-PUN-2023-14920',
    ),
  ];

  /// Calculates geodesic distance in kilometers between two GPS coordinates using geolocator.
  @override
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    final distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000.0;
  }

  List<Pharmacy> _sortPharmacies(List<Pharmacy> list, double? userLat, double? userLng) {
    if (userLat == null || userLng == null) return list;

    final withDistance = list.map((p) {
      if (p.latitude != null && p.longitude != null) {
        final dist = calculateDistance(userLat, userLng, p.latitude!, p.longitude!);
        return p.copyWith(distanceKm: dist);
      }
      return p;
    }).toList();

    withDistance.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    return withDistance;
  }

  /// Fetches registered pharmacies from Supabase and sorts them by proximity to [userLat], [userLng].
  /// Returns empty list if no pharmacies exist in the database.
  @override
  Future<List<Pharmacy>> fetchPharmacies({double? userLat, double? userLng}) async {
    final client = _client;
    if (client == null) {
      return _sortPharmacies(List<Pharmacy>.from(_inMemoryPharmacies), userLat, userLng);
    }

    try {
      final response = await client
          .from('pharmacies')
          .select('*')
          .order('Name', ascending: true);

      final List<dynamic> list = response as List<dynamic>;
      final pharmacies = list
          .map((item) => Pharmacy.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return _sortPharmacies(pharmacies, userLat, userLng);
    } catch (e) {
      debugPrint('[PharmacyService] Error fetching pharmacies: $e');
      return [];
    }
  }

  /// Registers a new pharmacy directly into the Supabase pharmacies table.
  @override
  Future<void> registerPharmacy(Pharmacy pharmacy) async {
    _inMemoryPharmacies.add(pharmacy);
    final client = _client;
    if (client == null) {
      return;
    }

    try {
      await client.from('pharmacies').insert(pharmacy.toJson());
    } catch (e) {
      debugPrint('[PharmacyService] Error inserting pharmacy: $e');
      rethrow;
    }
  }

  /// Updates an existing pharmacy in the Supabase pharmacies table.
  @override
  Future<void> updatePharmacy(Pharmacy pharmacy) async {
    final idx = _inMemoryPharmacies.indexWhere((p) => p.uid == pharmacy.uid);
    if (idx != -1) {
      _inMemoryPharmacies[idx] = pharmacy;
    }

    final client = _client;
    if (client == null) {
      return;
    }

    try {
      await client.from('pharmacies').update({
        'Name': pharmacy.name,
        'Location': pharmacy.location,
        'Phone': pharmacy.phone,
        'latitude': pharmacy.latitude,
        'longitude': pharmacy.longitude,
      }).eq('UID', pharmacy.uid);
    } catch (e) {
      debugPrint('[PharmacyService] Error updating pharmacy: $e');
      rethrow;
    }
  }

  /// Fetches the pharmacy record for a given owner user id or email.
  @override
  Future<Pharmacy?> fetchPharmacyForOwner(String? ownerId, {String? email}) async {
    final client = _client;
    if (client == null) {
      if (email != null) {
        final match = _inMemoryPharmacies.where((p) => p.email?.toLowerCase() == email.toLowerCase());
        if (match.isNotEmpty) return match.first;
      }
      return _inMemoryPharmacies.isNotEmpty ? _inMemoryPharmacies.first : null;
    }

    try {
      if (email != null && email.isNotEmpty) {
        final res = await client
            .from('pharmacies')
            .select('*')
            .ilike('Email', email)
            .limit(1)
            .maybeSingle();
        if (res != null) {
          return Pharmacy.fromJson(Map<String, dynamic>.from(res as Map));
        }
      }

      if (ownerId != null && ownerId.isNotEmpty) {
        final res = await client
            .from('pharmacies')
            .select('*')
            .eq('owner_id', ownerId)
            .limit(1)
            .maybeSingle();
        if (res != null) {
          return Pharmacy.fromJson(Map<String, dynamic>.from(res as Map));
        }
      }
    } catch (e) {
      debugPrint('[PharmacyService] Error fetching pharmacy for owner: $e');
    }
    return null;
  }
}
