import 'package:flutter/material.dart';
import '../inventory_screen.dart';
import '../../services/medicine_service.dart';
import '../../auth_service.dart';

/// Screen 10: Pharmacy Generic Inventory Management
/// Integrates the full Supabase CRUD inventory system adhering to the Stitch design specifications.
class PharmacyInventoryScreen extends StatelessWidget {
  const PharmacyInventoryScreen({
    super.key,
    this.medicineService,
    this.authService,
  });

  final IMedicineService? medicineService;
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return InventoryScreen(
      medicineService: medicineService,
      authService: authService,
    );
  }
}
