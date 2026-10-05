import 'package:flutter/material.dart';
import '../../services/medicine_service.dart';
import '../../models/medicine.dart';
import '../../widgets/medicine_dialog.dart';

/// Screen 10 (Direct Pharmacist Portal): Real-Time Inventory Search
/// Filters the medicine list locally in real-time as the pharmacist types,
/// matching against brand name and generic salt composition.
class PharmacistInventoryScreen extends StatefulWidget {
  const PharmacistInventoryScreen({
    super.key,
    this.medicineService,
  });

  final IMedicineService? medicineService;

  @override
  State<PharmacistInventoryScreen> createState() => _PharmacistInventoryScreenState();
}

class _PharmacistInventoryScreenState extends State<PharmacistInventoryScreen> {
  late final IMedicineService _medicineService;

  List<Medicine> _allMedicines = [];     // Stores original fetched data
  List<Medicine> _filteredMedicines = []; // Stores filtered items for display
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _medicineService = widget.medicineService ?? const MedicineService();
    _fetchMyInventory();
    _searchController.addListener(_filterMedicines);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMedicines);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _medicineService.fetchMedicines();
      if (mounted) {
        setState(() {
          _allMedicines = items;
          _isLoading = false;
        });
        _filterMedicines();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Filter logic based on search text input matching BOTH brand name AND generic salt
  void _filterMedicines() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMedicines = List.from(_allMedicines);
      } else {
        _filteredMedicines = _allMedicines.where((med) {
          final name = med.name.toLowerCase();
          final salt = (med.genericSalt ?? '').toLowerCase();
          final manufacturer = med.manufacturer.toLowerCase();
          final type = med.type.toLowerCase();
          return name.contains(query) ||
              salt.contains(query) ||
              manufacturer.contains(query) ||
              type.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteMedicine(Medicine med) async {
    if (med.uid == null) return;
    try {
      await _medicineService.deleteMedicine(med.uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${med.name} deleted successfully!')),
        );
        _fetchMyInventory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  void _openAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (_) => MedicineDialog(
        onSave: (newMedicine) async {
          await _medicineService.createMedicine(newMedicine);
          if (mounted) {
            _fetchMyInventory();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Pharmacy Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: _fetchMyInventory,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Medicine',
            onPressed: _openAddMedicineDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by brand name or generic salt...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterMedicines();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // Salt match count info chip
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Filtering ${_filteredMedicines.length} items matching "${_searchController.text.trim()}"',
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Inventory List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _fetchMyInventory,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredMedicines.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'No medicines in inventory yet.'
                                        : 'No medicines match "${_searchController.text}".',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _openAddMedicineDialog,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Medicine'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: _filteredMedicines.length,
                            itemBuilder: (context, index) {
                              final med = _filteredMedicines[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.medication, color: Colors.teal.shade700, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (med.genericSalt != null && med.genericSalt!.isNotEmpty)
                                              Text(
                                                'Salt: ${med.genericSalt!}',
                                                style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Price: ${med.formattedPrice} • Stock: ${med.stock} • ${med.type}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Delete Medicine',
                                        onPressed: () => _deleteMedicine(med),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
