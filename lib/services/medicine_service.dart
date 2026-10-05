import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine.dart';

/// Interface for medicine inventory operations to facilitate testing and clean architecture.
abstract class IMedicineService {
  Future<List<Medicine>> fetchMedicines({String? pharmacyUid});
  Future<Medicine> createMedicine(Medicine medicine);
  Future<Medicine> updateMedicine(Medicine medicine);
  Future<void> deleteMedicine(String uid);
  Future<String?> getPharmacyUid();
  Future<List<Medicine>> fetchCustomerMedicines({String? query, String? genericSalt}) async => fetchMedicines();
}

/// Service managing Supabase CRUD operations for medicines and pharmacy inventory.
class MedicineService implements IMedicineService {
  const MedicineService({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  static final List<Medicine> _inMemoryMedicines = [
    const Medicine(
      uid: 'MED-ID-8001',
      name: 'Amoxyclav 625 Generic IP',
      priceInr: 73.50,
      type: 'Tablet',
      stock: 142,
      manufacturer: 'Cipla Ltd',
      expiryDate: '2026-10-31',
      pharmacyUid: 'mock_pharmacy_uid',
      genericSalt: 'Amoxicillin + Clavulanic Acid 625mg',
    ),
    const Medicine(
      uid: 'MED-ID-8002',
      name: 'Metformin 500mg SR',
      priceInr: 18.00,
      type: 'Tablet',
      stock: 8,
      manufacturer: 'Sun Pharma',
      expiryDate: '2025-12-31',
      pharmacyUid: 'mock_pharmacy_uid',
      genericSalt: 'Metformin Hydrochloride 500mg',
    ),
    const Medicine(
      uid: 'MED-ID-8003',
      name: 'Cough Syrup DX',
      priceInr: 85.00,
      type: 'Syrup',
      stock: 0,
      manufacturer: 'Pfizer',
      expiryDate: '2027-05-15',
      pharmacyUid: 'mock_pharmacy_uid',
      genericSalt: 'Dextromethorphan Hydrobromide',
    ),
  ];

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Resolves the pharmacy UID associated with the currently authenticated user.
  @override
  Future<String?> getPharmacyUid() async {
    final client = _client;
    if (client == null) return 'mock_pharmacy_uid';

    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Try finding pharmacy by owner_id (Auth UUID)
      final res = await client
          .from('pharmacies')
          .select('UID')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (res != null && res['UID'] != null) {
        return res['UID'].toString();
      }

      // 2. Try finding pharmacy by Email
      if (user.email != null && user.email!.isNotEmpty) {
        final emailRes = await client
            .from('pharmacies')
            .select('UID')
            .ilike('Email', user.email!)
            .maybeSingle();

        if (emailRes != null && emailRes['UID'] != null) {
          // Link owner_id for future queries
          try {
            await client
                .from('pharmacies')
                .update({'owner_id': user.id})
                .eq('UID', emailRes['UID']);
          } catch (_) {}
          return emailRes['UID'].toString();
        }
      }

      // 3. If no pharmacy exists for this pharmacist, auto-create one
      try {
        final newPharmacy = await client
            .from('pharmacies')
            .insert({
              'Name': 'Apollo Meds & Wellness',
              'Email': user.email,
              'owner_id': user.id,
            })
            .select('UID')
            .single();

        return newPharmacy['UID']?.toString();
      } catch (e) {
        debugPrint('[MedicineService] Auto-provision pharmacy note: $e');
      }

      // Fallback to user ID if table schema uses direct user ID mapping
      return user.id;
    } catch (e) {
      debugPrint('[MedicineService] Error resolving pharmacy UID: $e');
      return user.id;
    }
  }

  /// Fetches medicines strictly belonging to the authenticated pharmacist.
  @override
  Future<List<Medicine>> fetchMedicines({String? pharmacyUid}) async {
    final client = _client;
    if (client == null) {
      // Offline / Test mock fallback
      return List<Medicine>.from(_inMemoryMedicines);
    }

    try {
      final currentUserEmail = client.auth.currentUser?.email;

      // If no user is logged in, return empty list
      if (currentUserEmail == null) {
        return [];
      }

      final targetPharmacyUid = pharmacyUid ?? await getPharmacyUid();

      PostgrestFilterBuilder query = client.from('medicines').select('*');

      if (targetPharmacyUid != null && targetPharmacyUid.isNotEmpty) {
        query = query.or('added_by.eq.$currentUserEmail,pharmacy_uid.eq.$targetPharmacyUid');
      } else {
        query = query.eq('added_by', currentUserEmail);
      }

      final List<dynamic> response = await query.order('UID', ascending: true);

      final result = response
          .map((item) => Medicine.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      return result;
    } catch (e) {
      debugPrint('[MedicineService] Error fetching medicines: $e');
      return [];
    }
  }

  /// Fetches catalog medicines from Supabase matching strictly name and generic_salt.
  /// On empty query or empty database, returns empty list without placeholder fallbacks.
  @override
  Future<List<Medicine>> fetchCustomerMedicines({String? query, String? genericSalt}) async {
    final client = _client;
    final trimmedQuery = query?.trim() ?? '';
    final trimmedSalt = genericSalt?.trim() ?? '';

    if (trimmedQuery.isEmpty && trimmedSalt.isEmpty) {
      return [];
    }

    if (client == null) {
      var list = List<Medicine>.from(_inMemoryMedicines);
      if (trimmedQuery.isNotEmpty) {
        final q = trimmedQuery.toLowerCase();
        list = list.where((m) =>
          m.name.toLowerCase().contains(q) ||
          (m.genericSalt?.toLowerCase().contains(q) ?? false)
        ).toList();
      }
      if (trimmedSalt.isNotEmpty) {
        final s = trimmedSalt.toLowerCase();
        list = list.where((m) => m.genericSalt?.toLowerCase().contains(s) ?? false).toList();
      }
      return list;
    }

    try {
      List<dynamic> response;
      try {
        PostgrestFilterBuilder dbQuery = client.from('medicines').select('*');
        if (trimmedQuery.isNotEmpty) {
          dbQuery = dbQuery.or('Name.ilike.%$trimmedQuery%,Generic_Salt.ilike.%$trimmedQuery%');
        }
        if (trimmedSalt.isNotEmpty) {
          dbQuery = dbQuery.ilike('Generic_Salt', '%$trimmedSalt%');
        }
        response = await dbQuery.order('Name', ascending: true);
      } catch (_) {
        try {
          PostgrestFilterBuilder dbQuery = client.from('medicines').select('*');
          if (trimmedQuery.isNotEmpty) {
            dbQuery = dbQuery.or('"Name".ilike.%$trimmedQuery%,"Generic_Salt".ilike.%$trimmedQuery%');
          }
          if (trimmedSalt.isNotEmpty) {
            dbQuery = dbQuery.ilike('"Generic_Salt"', '%$trimmedSalt%');
          }
          response = await dbQuery.order('"Name"', ascending: true);
        } catch (_) {
          PostgrestFilterBuilder dbQuery = client.from('medicines').select('*');
          if (trimmedQuery.isNotEmpty) {
            dbQuery = dbQuery.or('Name.ilike.%$trimmedQuery%,Generic_Salt.ilike.%$trimmedQuery%');
          }
          if (trimmedSalt.isNotEmpty) {
            dbQuery = dbQuery.ilike('Generic_Salt', '%$trimmedSalt%');
          }
          response = await dbQuery;
        }
      }

      final result = response
          .map((item) => Medicine.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return result;
    } catch (e) {
      debugPrint('[MedicineService] Error fetching customer medicines: $e');
      return [];
    }
  }

  /// Inserts a new medicine into the database.
  /// Backend generates the UID and assigns the authenticated pharmacy_uid.
  @override
  Future<Medicine> createMedicine(Medicine medicine) async {
    final client = _client;
    if (client == null) {
      final sim = medicine.copyWith(
        uid: medicine.uid ?? 'MED-ID-${DateTime.now().millisecondsSinceEpoch % 10000}',
        pharmacyUid: medicine.pharmacyUid ?? 'mock_pharmacy_uid',
      );
      _inMemoryMedicines.add(sim);
      return sim;
    }

    try {
      final pharmacyUid = medicine.pharmacyUid ?? await getPharmacyUid();
      final user = client.auth.currentUser;

      // Prepare payload - DO NOT include manual UID so the database generates it
      final payload = medicine.toJson(includeUid: false);
      if (pharmacyUid != null) {
        payload['pharmacy_uid'] = pharmacyUid;
      }
      if (user?.email != null) {
        payload['added_by'] = user!.email;
      }

      final dynamic response = await client
          .from('medicines')
          .insert(payload)
          .select()
          .single();

      return Medicine.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('[MedicineService] Error creating medicine: $e');
      rethrow;
    }
  }

  /// Updates an existing medicine identified by its unique UID.
  @override
  Future<Medicine> updateMedicine(Medicine medicine) async {
    final client = _client;
    final uid = medicine.uid;
    if (uid == null || uid.isEmpty) {
      throw ArgumentError('Medicine UID is required to perform an update.');
    }

    final idx = _inMemoryMedicines.indexWhere((m) => m.uid == uid);
    if (idx != -1) {
      _inMemoryMedicines[idx] = medicine;
    }

    if (client == null) {
      return medicine;
    }

    try {
      final payload = <String, dynamic>{
        'Name': medicine.name,
        'Price_INR': medicine.priceInr,
        'Type': medicine.type,
        'Stock': medicine.stock,
        'Manufacturer': medicine.manufacturer,
        'Expiry_Date': medicine.expiryDate,
      };

      final dynamic response = await client
          .from('medicines')
          .update(payload)
          .eq('UID', uid)
          .select()
          .single();

      return Medicine.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('[MedicineService] Error updating medicine $uid: $e');
      rethrow;
    }
  }

  /// Deletes a medicine by its unique UID.
  @override
  Future<void> deleteMedicine(String uid) async {
    if (uid.isEmpty) {
      throw ArgumentError('Medicine UID is required to perform deletion.');
    }

    _inMemoryMedicines.removeWhere((m) => m.uid == uid);

    final client = _client;
    if (client == null) return;

    try {
      await client.from('medicines').delete().eq('UID', uid);
    } catch (e) {
      debugPrint('[MedicineService] Error deleting medicine $uid: $e');
      rethrow;
    }
  }

  /// Resets in-memory state for clean test isolation.
  static void resetMockState() {
    _inMemoryMedicines.clear();
  }
}

