import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/models/pharmacy.dart';
import 'package:carepharma/services/pharmacy_service.dart';

void main() {
  group('Pharmacy Model Tests', () {
    test('Correctly deserializes from Supabase PascalCase JSON', () {
      final json = {
        'UID': 'PH-UID-1015',
        'Name': 'CareWell Meds Karvenagar',
        'Location': 'Karvenagar, Pune',
        'Phone': '+91 98234 11223',
        'Email': 'carewell.karvenagar@gmail.com',
        'latitude': 18.4912,
        'longitude': 73.8215,
        'license': 'MH-PUN-2023-88',
      };

      final pharmacy = Pharmacy.fromJson(json);

      expect(pharmacy.uid, 'PH-UID-1015');
      expect(pharmacy.name, 'CareWell Meds Karvenagar');
      expect(pharmacy.location, 'Karvenagar, Pune');
      expect(pharmacy.phone, '+91 98234 11223');
      expect(pharmacy.email, 'carewell.karvenagar@gmail.com');
      expect(pharmacy.latitude, 18.4912);
      expect(pharmacy.longitude, 73.8215);
      expect(pharmacy.hasCoordinates, isTrue);
    });

    test('Correctly serializes to Supabase insert payload', () {
      const pharmacy = Pharmacy(
        uid: 'PH-UID-1020',
        name: 'Apollo Pharmacy Kothrud',
        location: 'Kothrud, Pune',
        phone: '+91 99887 76655',
        email: 'apollo.kothrud@gmail.com',
        latitude: 18.5074,
        longitude: 73.8077,
      );

      final json = pharmacy.toJson();

      expect(json['UID'], 'PH-UID-1020');
      expect(json['Name'], 'Apollo Pharmacy Kothrud');
      expect(json['Location'], 'Kothrud, Pune');
      expect(json['Phone'], '+91 99887 76655');
      expect(json['Email'], 'apollo.kothrud@gmail.com');
      expect(json['latitude'], 18.5074);
      expect(json['longitude'], 73.8077);
    });

    test('Formats distance correctly', () {
      const p1 = Pharmacy(
        uid: 'PH-1',
        name: 'Med 1',
        location: 'Baner',
        distanceKm: 0.85,
      );
      expect(p1.formattedDistance, '850 m away');

      const p2 = Pharmacy(
        uid: 'PH-2',
        name: 'Med 2',
        location: 'Baner',
        distanceKm: 2.34,
      );
      expect(p2.formattedDistance, '2.3 km away');

      const p3 = Pharmacy(
        uid: 'PH-3',
        name: 'Med 3',
        location: 'Baner',
        distanceKm: null,
      );
      expect(p3.formattedDistance, 'Distance unavailable');
    });
  });

  group('PharmacyService Geodesic Distance & Proximity Sorting Tests', () {
    const service = PharmacyService();

    test('Calculates geodesic distance between two points accurately', () {
      // Baner (18.5590, 73.7868) to Aundh (18.5580, 73.8075) ~ 2.18 km
      final distanceKm = service.calculateDistance(
        18.5590,
        73.7868,
        18.5580,
        73.8075,
      );

      expect(distanceKm, greaterThan(2.0));
      expect(distanceKm, lessThan(2.5));
    });

    test('Sorts pharmacies by ascending proximity to user location', () async {
      // User in Baner (18.5590, 73.7868)
      final pharmacies = await service.fetchPharmacies(
        userLat: 18.5590,
        userLng: 73.7868,
      );

      expect(pharmacies, isNotEmpty);
      // Verify every pharmacy has calculated distanceKm
      for (final p in pharmacies) {
        expect(p.distanceKm, isNotNull);
      }

      // Verify ascending order
      for (int i = 0; i < pharmacies.length - 1; i++) {
        expect(
          pharmacies[i].distanceKm! <= pharmacies[i + 1].distanceKm!,
          isTrue,
          reason: 'Item at $i (${pharmacies[i].name}: ${pharmacies[i].distanceKm}km) should be closer than item at ${i + 1} (${pharmacies[i + 1].name}: ${pharmacies[i + 1].distanceKm}km)',
        );
      }
    });

    test('Handles null user coordinates gracefully without distance calculation', () async {
      final pharmacies = await service.fetchPharmacies(
        userLat: null,
        userLng: null,
      );
      expect(pharmacies, isNotEmpty);
      expect(pharmacies.first.distanceKm, isNull);
    });
  });
}
