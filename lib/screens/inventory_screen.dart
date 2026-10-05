import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/pharmacy.dart';
import '../services/medicine_service.dart';
import '../services/pharmacy_service.dart';
import '../auth_service.dart';
import '../widgets/medicine_card.dart';
import '../widgets/medicine_dialog.dart';
import 'pharmacy/pharmacist_profile_screen.dart';

/// Full Pharmacy Admin Inventory Screen implementing real Supabase integration.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    this.medicineService,
    this.authService,
  });

  final IMedicineService? medicineService;
  final AuthService? authService;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final IMedicineService _medicineService;
  late final AuthService _authService;
  final PharmacyService _pharmacyService = const PharmacyService();
  Pharmacy? _currentPharmacy;
  int _selectedNavTab = 0;

  List<Medicine> _medicines = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search and Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStockStatus = 'All';

  static const _primaryColor = Color(0xFF00685F);
  static const _surfaceBg = Color(0xFFF7F9FB);

  @override
  void initState() {
    super.initState();
    _medicineService = widget.medicineService ?? const MedicineService();
    _authService = widget.authService ?? const AuthService();
    _searchController.addListener(_onSearchChanged);
    _loadMedicines();
    _loadPharmacyDetails();
  }

  Future<void> _loadPharmacyDetails() async {
    try {
      final user = _authService.currentUser;
      final email = user?.email ?? _authService.currentUserEmail;
      final p = await _pharmacyService.fetchPharmacyForOwner(user?.id, email: email);
      if (mounted && p != null) {
        setState(() => _currentPharmacy = p);
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches medicines strictly belonging to the authenticated pharmacy.
  Future<void> _loadMedicines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _medicineService.fetchMedicines();
      if (mounted) {
        setState(() {
          _medicines = items;
          _isLoading = false;
        });
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

  /// Opens the Add Medicine modal.
  void _openAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (_) => MedicineDialog(
        onSave: (newMedicine) async {
          final created = await _medicineService.createMedicine(newMedicine);
          if (mounted) {
            setState(() {
              _medicines.insert(0, created);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${created.name} added to inventory!'),
                backgroundColor: _primaryColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Opens the Edit Medicine modal.
  void _openEditMedicineDialog(Medicine med) {
    showDialog(
      context: context,
      builder: (_) => MedicineDialog(
        existingMedicine: med,
        onSave: (updated) async {
          final result = await _medicineService.updateMedicine(updated);
          if (mounted) {
            setState(() {
              final idx = _medicines.indexWhere((m) => m.uid == result.uid);
              if (idx != -1) {
                _medicines[idx] = result;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${result.name} updated successfully!'),
                backgroundColor: _primaryColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  /// Displays confirmation dialog and deletes medicine upon confirmation.
  void _confirmDelete(Medicine med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Delete Medicine',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${med.name}" from the inventory?\n\nThis will permanently remove the record from Supabase.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF3D4947)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (med.uid != null) {
                  await _medicineService.deleteMedicine(med.uid!);
                  if (mounted) {
                    setState(() {
                      _medicines.removeWhere((m) => m.uid == med.uid);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${med.name} deleted successfully!'),
                        backgroundColor: const Color(0xFFBA1A1A),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: const Color(0xFFBA1A1A),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Quick restock: Increments stock count by 10 units.
  Future<void> _quickRestock(Medicine med) async {
    final updated = med.copyWith(stock: med.stock + 10);
    try {
      final saved = await _medicineService.updateMedicine(updated);
      if (mounted) {
        setState(() {
          final idx = _medicines.indexWhere((m) => m.uid == saved.uid);
          if (idx != -1) {
            _medicines[idx] = saved;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restocked ${saved.name} (+10 units)'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restock: $e'),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  /// Filters medicines according to search text and dropdown selections.
  List<Medicine> get _filteredMedicines {
    final query = _searchController.text.trim().toLowerCase();
    return _medicines.where((med) {
      // 1. Text filter (matches name, generic salt, manufacturer, type, or UID)
      if (query.isNotEmpty) {
        final matchName = med.name.toLowerCase().contains(query);
        final matchSalt = med.genericSalt != null && med.genericSalt!.toLowerCase().contains(query);
        final matchManufacturer = med.manufacturer.toLowerCase().contains(query);
        final matchType = med.type.toLowerCase().contains(query);
        final matchUid = med.uid != null && med.uid!.toLowerCase().contains(query);
        if (!matchName && !matchSalt && !matchManufacturer && !matchType && !matchUid) {
          return false;
        }
      }

      // 2. Category filter
      if (_selectedCategory != 'All') {
        if (med.type.toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }

      // 3. Stock Status filter
      if (_selectedStockStatus == 'In Stock' && med.isOutOfStock) {
        return false;
      }
      if (_selectedStockStatus == 'Low Stock' && !med.isLowStock) {
        return false;
      }
      if (_selectedStockStatus == 'Out of Stock' && !med.isOutOfStock) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalSkus = _medicines.length;
    final lowStockCount = _medicines.where((m) => m.isLowStock).length;
    final activeGenericsCount = _medicines.where((m) => !m.isOutOfStock).length;
    final filtered = _filteredMedicines;

    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.local_pharmacy, color: _primaryColor, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentPharmacy?.name ?? 'Apollo Meds & Wellness',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Verified Store',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _currentPharmacy?.location ?? 'Pharmacist Admin Dashboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A77)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
            onPressed: _loadMedicines,
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Store Profile & Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PharmacistProfileScreen(
                    authService: _authService,
                    pharmacyService: _pharmacyService,
                  ),
                ),
              );
              _loadPharmacyDetails();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMedicines,
        color: _primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header & Action CTA (Responsive Layout)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 480;
                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Generic Inventory & Stock Control',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage stock levels, batch pricing, and marketplace availability.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Color(0xFF6D7A77)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openAddMedicineDialog,
                          icon: const Icon(Icons.add_circle, size: 18),
                          label: const Text(
                            'Add Medicine',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generic Inventory & Stock Control',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage stock levels, batch pricing, and marketplace availability.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Color(0xFF6D7A77)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _openAddMedicineDialog,
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text(
                          'Add Medicine',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // 2. Metrics Indicator Cards
              Row(
                children: [
                  _MetricCard(
                    title: 'Total SKUs',
                    value: '$totalSkus',
                    color: const Color(0xFF191C1E),
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    title: 'Low Stock',
                    value: '$lowStockCount',
                    color: const Color(0xFF924628),
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    title: 'Active Generics',
                    value: '$activeGenericsCount',
                    color: _primaryColor,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Search & Filter Bar Card
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Input
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by brand name, salt, manufacturer...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D7A77)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF2F4F6),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dropdown Filters Row
                      Row(
                        children: [
                          // Category Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              isDense: true,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All Types', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Tablet',
                                  child: Text('Tablets', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Capsule',
                                  child: Text('Capsules', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Syrup',
                                  child: Text('Syrups', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Ointment',
                                  child: Text('Ointments', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Drops',
                                  child: Text('Drops', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Inhaler',
                                  child: Text('Inhalers', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Injection',
                                  child: Text('Injections', overflow: TextOverflow.ellipsis),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stock Status Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedStockStatus,
                              isDense: true,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Stock Status',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All Stock', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'In Stock',
                                  child: Text('In Stock', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Low Stock',
                                  child: Text('Low (<15)', overflow: TextOverflow.ellipsis),
                                ),
                                DropdownMenuItem(
                                  value: 'Out of Stock',
                                  child: Text('Out (0)', overflow: TextOverflow.ellipsis),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedStockStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Content Area: Loading / Error / Empty / List
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: _primaryColor),
                        SizedBox(height: 16),
                        Text(
                          'Loading medicines from Supabase...',
                          style: TextStyle(color: Color(0xFF6D7A77)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFBA1A1A),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load inventory',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFBA1A1A)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadMedicines,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: Color(0xFFBCC9C6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No medicines found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191C1E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'No records match your search or filters.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6D7A77)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openAddMedicineDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add First Medicine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Showing ${filtered.length} of $totalSkus medicines',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D7A77),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final med = filtered[index];
                    return MedicineCard(
                      key: ValueKey(med.uid ?? index),
                      medicine: med,
                      onEdit: () => _openEditMedicineDialog(med),
                      onDelete: () => _confirmDelete(med),
                      onQuickRestock: () => _quickRestock(med),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavTab,
        onDestinationSelected: (idx) async {
          if (idx == 1) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PharmacistProfileScreen(
                  authService: _authService,
                  pharmacyService: _pharmacyService,
                ),
              ),
            );
            _loadPharmacyDetails();
          } else {
            setState(() => _selectedNavTab = idx);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Store & Settings',
          ),
        ],
      ),
    );
  }
}

/// Helper Card for quick metrics
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6D7A77),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
