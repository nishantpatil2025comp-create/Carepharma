import 'package:flutter_test/flutter_test.dart';
import 'package:carepharma/models/medicine.dart';
import 'package:carepharma/services/medicine_service.dart';

void main() {
  group('Medicine Model Tests', () {
    test('Correctly deserializes from Supabase PascalCase JSON', () {
      final json = {
        'UID': 'MED-ID-8001',
        'Name': 'Amoxyclav 625 Generic IP',
        'Price_INR': 73.50,
        'Type': 'Tablet',
        'Stock': 142,
        'Manufacturer': 'Cipla Ltd',
        'Expiry_Date': '2026-10-31',
        'pharmacy_uid': 'pharm_123',
        'added_by': 'admin@carepharma.com',
      };

      final med = Medicine.fromJson(json);

      expect(med.uid, 'MED-ID-8001');
      expect(med.name, 'Amoxyclav 625 Generic IP');
      expect(med.priceInr, 73.50);
      expect(med.type, 'Tablet');
      expect(med.stock, 142);
      expect(med.manufacturer, 'Cipla Ltd');
      expect(med.expiryDate, '2026-10-31');
      expect(med.pharmacyUid, 'pharm_123');
      expect(med.addedBy, 'admin@carepharma.com');
      expect(med.isOutOfStock, false);
      expect(med.isLowStock, false);
      expect(med.stockHealth, 'Good');
      expect(med.formattedPrice, '₹73.50');
    });

    test('Correctly detects Low Stock and Out of Stock', () {
      const lowStockMed = Medicine(
        uid: 'MED-ID-8002',
        name: 'Metformin 500mg',
        priceInr: 18.0,
        type: 'Tablet',
        stock: 8,
        manufacturer: 'Sun Pharma',
        expiryDate: '2025-12-31',
      );

      expect(lowStockMed.isLowStock, true);
      expect(lowStockMed.isOutOfStock, false);
      expect(lowStockMed.stockHealth, 'Low Stock');

      const outOfStockMed = Medicine(
        uid: 'MED-ID-8003',
        name: 'Atorvastatin 10mg',
        priceInr: 32.0,
        type: 'Tablet',
        stock: 0,
        manufacturer: 'Intas Pharma',
        expiryDate: '2026-11-20',
      );

      expect(outOfStockMed.isLowStock, false);
      expect(outOfStockMed.isOutOfStock, true);
      expect(outOfStockMed.stockHealth, 'Out of Stock');
    });

    test('toJson produces expected payload for database insertion', () {
      const med = Medicine(
        name: 'Paracetamol 650mg',
        priceInr: 14.50,
        type: 'Tablet',
        stock: 200,
        manufacturer: 'Mankind',
        expiryDate: '2026-08-15',
        pharmacyUid: 'pharm_123',
      );

      final json = med.toJson(includeUid: false);

      expect(json['Name'], 'Paracetamol 650mg');
      expect(json['Price_INR'], 14.50);
      expect(json['Type'], 'Tablet');
      expect(json['Stock'], 200);
      expect(json['Manufacturer'], 'Mankind');
      expect(json['Expiry_Date'], '2026-08-15');
      expect(json['pharmacy_uid'], 'pharm_123');
      expect(json.containsKey('UID'), false); // Database generates UID
    });
  });

  group('MedicineService Tests', () {
    final service = const MedicineService();

    test('fetchMedicines returns list of medicines', () async {
      final list = await service.fetchMedicines();
      expect(list.isNotEmpty, true);
      expect(list.first.name, isNotEmpty);
    });

    test('createMedicine assigns UID and persists pharmacy relationship', () async {
      const newMed = Medicine(
        name: 'Cough Syrup DX',
        priceInr: 85.0,
        type: 'Syrup',
        stock: 50,
        manufacturer: 'Pfizer',
        expiryDate: '2027-05-15',
      );

      final created = await service.createMedicine(newMed);
      expect(created.uid, isNotNull);
      expect(created.name, 'Cough Syrup DX');
      expect(created.priceInr, 85.0);
      expect(created.stock, 50);
    });

    test('updateMedicine updates medicine properties', () async {
      const existing = Medicine(
        uid: 'MED-ID-8001',
        name: 'Amoxyclav 625 Generic IP',
        priceInr: 75.0,
        type: 'Tablet',
        stock: 150,
        manufacturer: 'Cipla Ltd',
        expiryDate: '2026-10-31',
      );

      final updated = await service.updateMedicine(existing);
      expect(updated.priceInr, 75.0);
      expect(updated.stock, 150);
    });

    test('deleteMedicine handles valid medicine UID', () async {
      expect(() => service.deleteMedicine('MED-ID-8001'), returnsNormally);
    });

    test('deleteMedicine throws on empty UID', () async {
      expect(() => service.deleteMedicine(''), throwsArgumentError);
    });
  });
}

