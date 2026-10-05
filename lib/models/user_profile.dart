/// Model representing a user/patient profile in CareWell Pharma.
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.role = 'user',
    this.fullName,
    this.phone,
    this.deliveryAddress,
    this.cityPincode,
    this.allergies,
    this.latitude,
    this.longitude,
    this.isProfileCompleted = false,
    this.createdAt,
  });

  /// Unique Supabase auth user id (UUID).
  final String id;

  /// User's email address.
  final String? email;

  /// User role: 'user' or 'pharmacist'.
  final String role;

  /// Full name of the user or patient.
  final String? fullName;

  /// Contact phone number for delivery updates.
  final String? phone;

  /// Primary delivery address.
  final String? deliveryAddress;

  /// City and postal code (e.g. "Pune 411045").
  final String? cityPincode;

  /// Known allergies or health notes.
  final String? allergies;

  /// GPS Latitude for home delivery pin.
  final double? latitude;

  /// GPS Longitude for home delivery pin.
  final double? longitude;

  /// Whether the user has completed their onboarding profile setup.
  final bool isProfileCompleted;

  /// Record creation timestamp.
  final DateTime? createdAt;

  /// Alias getter for deliveryAddress
  String? get address => deliveryAddress;

  /// Returns true if the user has completed their profile setup.
  bool get hasCompletedProfile =>
      isProfileCompleted &&
      fullName != null &&
      fullName!.trim().isNotEmpty &&
      deliveryAddress != null &&
      deliveryAddress!.trim().isNotEmpty;

  /// Creates a [UserProfile] from Supabase JSON.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['UID'] ?? '').toString(),
      email: json['email']?.toString(),
      role: (json['role'] ?? 'user').toString().toLowerCase(),
      fullName: json['full_name']?.toString() ?? json['name']?.toString(),
      phone: json['phone']?.toString(),
      deliveryAddress: json['delivery_address']?.toString() ?? json['address']?.toString(),
      cityPincode: json['city_pincode']?.toString(),
      allergies: json['allergies']?.toString() ?? json['health_notes']?.toString(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      isProfileCompleted: json['is_profile_completed'] == true ||
          (json['full_name'] != null && json['full_name'].toString().trim().isNotEmpty),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  /// Converts this [UserProfile] to JSON for Supabase upsert.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (email != null) 'email': email,
      'role': role.toLowerCase(),
      if (fullName != null) 'full_name': fullName!.trim(),
      if (phone != null) 'phone': phone!.trim(),
      if (deliveryAddress != null) 'delivery_address': deliveryAddress!.trim(),
      if (deliveryAddress != null) 'address': deliveryAddress!.trim(),
      if (cityPincode != null) 'city_pincode': cityPincode!.trim(),
      if (allergies != null) 'allergies': allergies!.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'is_profile_completed': isProfileCompleted,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? role,
    String? fullName,
    String? phone,
    String? deliveryAddress,
    String? cityPincode,
    String? allergies,
    double? latitude,
    double? longitude,
    bool? isProfileCompleted,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      cityPincode: cityPincode ?? this.cityPincode,
      allergies: allergies ?? this.allergies,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
