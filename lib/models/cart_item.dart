/// Model representing an item in the user's shopping cart in Supabase `cart` table.
class CartItem {
  const CartItem({
    required this.id,
    required this.userEmail,
    required this.medicineId,
    required this.medicineName,
    required this.priceInr,
    this.quantity = 1,
    this.pharmacyUid,
    this.createdAt,
  });

  /// Unique Cart Item UUID.
  final String id;

  /// Email of the user who owns this cart item.
  final String userEmail;

  /// Associated medicine identifier/UID.
  final String medicineId;

  /// Display name of the medicine.
  final String medicineName;

  /// Price per unit in INR.
  final double priceInr;

  /// Quantity selected.
  final int quantity;

  /// Fulfilling pharmacy UID.
  final String? pharmacyUid;

  /// Timestamp when item was added to cart.
  final DateTime? createdAt;

  /// Total calculated price for this line item.
  double get totalPrice => priceInr * quantity;

  /// Creates a [CartItem] from Supabase JSON.
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: (json['id'] ?? '').toString(),
      userEmail: (json['user_email'] ?? json['userEmail'] ?? '').toString(),
      medicineId: (json['medicine_id'] ?? json['medicineId'] ?? '').toString(),
      medicineName: (json['medicine_name'] ?? json['medicineName'] ?? json['name'] ?? '').toString(),
      priceInr: json['price_inr'] != null
          ? double.tryParse(json['price_inr'].toString()) ?? 0.0
          : (json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : 0.0),
      quantity: json['quantity'] != null ? int.tryParse(json['quantity'].toString()) ?? 1 : 1,
      pharmacyUid: json['pharmacy_uid']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  /// Converts this [CartItem] into JSON for Supabase insert/update.
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && !id.startsWith('mock_')) 'id': id,
      'user_email': userEmail,
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'price_inr': priceInr,
      'quantity': quantity,
      if (pharmacyUid != null && pharmacyUid!.isNotEmpty) 'pharmacy_uid': pharmacyUid,
    };
  }

  /// Creates a copy with optionally updated fields.
  CartItem copyWith({
    String? id,
    String? userEmail,
    String? medicineId,
    String? medicineName,
    double? priceInr,
    int? quantity,
    String? pharmacyUid,
    DateTime? createdAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      priceInr: priceInr ?? this.priceInr,
      quantity: quantity ?? this.quantity,
      pharmacyUid: pharmacyUid ?? this.pharmacyUid,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
