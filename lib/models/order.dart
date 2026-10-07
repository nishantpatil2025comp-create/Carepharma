/// Model representing a medicine order in CareWell Pharma.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.medicineName,
    required this.quantity,
    required this.totalPrice,
    required this.patientEmail,
    this.patientName,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.pharmacyUid,
    this.status = 'Pending',
    this.createdAt,
  });

  /// Unique order identifier (UUID or order_id).
  final String id;

  /// Name of the ordered medicine.
  final String medicineName;

  /// Quantity of units ordered.
  final int quantity;

  /// Total price paid / payable in INR.
  final double totalPrice;

  /// Email of the user/patient placing the order.
  final String patientEmail;

  /// Real full name of the patient.
  final String? patientName;

  /// Delivery address destination.
  final String? deliveryAddress;

  /// GPS Latitude for delivery pin.
  final double? deliveryLatitude;

  /// GPS Longitude for delivery pin.
  final double? deliveryLongitude;

  /// Fulfilling pharmacy UID.
  final String? pharmacyUid;

  /// Order status ('Pending', 'Verified', 'Packed', 'Dispatched', 'Delivered').
  final String status;

  /// Order placement timestamp.
  final DateTime? createdAt;

  /// Formatted creation time string.
  String get formattedDate {
    if (createdAt == null) return 'Recent';
    final dt = createdAt!.toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Deserializes from Supabase JSON.
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 1;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? 1;
    }

    return OrderItem(
      id: (json['order_id'] ?? json['Order_ID'] ?? json['UID'] ?? json['uid'] ?? json['id'] ?? '').toString(),
      medicineName: (json['medicine_name'] ?? json['name'] ?? 'Generic Medicine').toString(),
      quantity: parseInt(json['quantity']),
      totalPrice: parseDouble(json['total_price'] ?? json['price']),
      patientEmail: (json['patient_email'] ?? json['email'] ?? json['user_email'] ?? '').toString(),
      patientName: (json['patient_name'] ?? json['full_name'] ?? json['profiles']?['full_name'])?.toString(),
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLatitude: json['delivery_latitude'] != null ? parseDouble(json['delivery_latitude']) : null,
      deliveryLongitude: json['delivery_longitude'] != null ? parseDouble(json['delivery_longitude']) : null,
      pharmacyUid: (json['pharmacy_uid'] ?? json['pharmacy_id'])?.toString(),
      status: (json['status'] ?? 'Pending').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  /// Serializes for Supabase insertion.
  Map<String, dynamic> toJson({bool includeOrderId = false}) {
    return {
      if (includeOrderId && id.isNotEmpty) 'order_id': id,
      'medicine_name': medicineName,
      'quantity': quantity,
      'total_price': totalPrice,
      'patient_email': patientEmail,
      if (patientName != null && patientName!.trim().isNotEmpty) 'patient_name': patientName!.trim(),
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryLatitude != null) 'delivery_latitude': deliveryLatitude,
      if (deliveryLongitude != null) 'delivery_longitude': deliveryLongitude,
      if (pharmacyUid != null) 'pharmacy_uid': pharmacyUid,
      'status': status,
    };
  }

  OrderItem copyWith({
    String? id,
    String? medicineName,
    int? quantity,
    double? totalPrice,
    String? patientEmail,
    String? patientName,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? pharmacyUid,
    String? status,
    DateTime? createdAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      patientEmail: patientEmail ?? this.patientEmail,
      patientName: patientName ?? this.patientName,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      pharmacyUid: pharmacyUid ?? this.pharmacyUid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
