/// Model representing a pharmacy store record in CarePharma.
class Pharmacy {
  const Pharmacy({
    required this.uid,
    required this.name,
    this.location,
    this.phone,
    this.email,
    this.license,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.rating = 0.0,
    this.reviews = '0',
    this.openStatus = 'Open Now',
  });

  /// Unique pharmacy store identifier (e.g. PH-UID-1015 or UUID).
  final String uid;

  /// Business trade name of pharmacy.
  final String name;

  /// Physical address or locality (e.g. Baner, Pune).
  final String? location;

  /// Contact phone number.
  final String? phone;

  /// Contact email address.
  final String? email;

  /// Drug retail license number.
  final String? license;

  /// GPS Latitude coordinate.
  final double? latitude;

  /// GPS Longitude coordinate.
  final double? longitude;

  /// Calculated proximity distance in kilometers from current user GPS position.
  final double? distanceKm;

  /// Star rating out of 5.0.
  final double rating;

  /// Number of verified user reviews.
  final String reviews;

  /// Opening status (e.g. "Open Now", "Open until 11:00 PM").
  final String openStatus;

  /// Whether valid GPS coordinates are present.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Formatted distance string (e.g. "1.2 km away").
  String get formattedDistance {
    if (distanceKm == null) return 'Distance unavailable';
    if (distanceKm! < 1.0) {
      return '${(distanceKm! * 1000).round()} m away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  /// Deserializes a Pharmacy from Supabase JSON map.
  factory Pharmacy.fromJson(Map<String, dynamic> json, {double? userLat, double? userLng}) {
    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    final rawUid = json['UID'] ?? json['uid'] ?? json['id'] ?? '';
    final rawName = json['Name'] ?? json['name'] ?? 'CareWell Pharmacy';
    final rawLoc = json['Location'] ?? json['location'] ?? json['address'];
    final rawPhone = json['Phone'] ?? json['phone'];
    final rawEmail = json['Email'] ?? json['email'];
    final rawLicense = json['License'] ?? json['license'];
    final rawLat = parseCoord(json['latitude'] ?? json['Latitude'] ?? json['lat']);
    final rawLng = parseCoord(json['longitude'] ?? json['Longitude'] ?? json['lng'] ?? json['lon']);

    return Pharmacy(
      uid: rawUid.toString(),
      name: rawName.toString(),
      location: rawLoc?.toString(),
      phone: rawPhone?.toString(),
      email: rawEmail?.toString(),
      license: rawLicense?.toString(),
      latitude: rawLat,
      longitude: rawLng,
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
      reviews: json['reviews']?.toString() ?? '0',
      openStatus: json['open_status']?.toString() ?? 'Open Now',
    );
  }

  /// Serializes the Pharmacy record for Supabase insertion.
  Map<String, dynamic> toJson() {
    return {
      'UID': uid,
      'Name': name,
      if (location != null && location!.isNotEmpty) 'Location': location,
      if (phone != null && phone!.isNotEmpty) 'Phone': phone,
      if (email != null && email!.isNotEmpty) 'Email': email,
      if (license != null && license!.isNotEmpty) 'License': license,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Returns a copy of this pharmacy with modified properties.
  Pharmacy copyWith({
    String? uid,
    String? name,
    String? location,
    String? phone,
    String? email,
    String? license,
    double? latitude,
    double? longitude,
    double? distanceKm,
    double? rating,
    String? reviews,
    String? openStatus,
  }) {
    return Pharmacy(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      license: license ?? this.license,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      openStatus: openStatus ?? this.openStatus,
    );
  }
}
