import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/order.dart';
import '../models/pharmacy.dart';
import '../services/medicine_service.dart';
import '../services/order_service.dart';
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
    this.orderService,
  });

  final IMedicineService? medicineService;
  final AuthService? authService;
  final IOrderService? orderService;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final IMedicineService _medicineService;
  late final AuthService _authService;
  late final IOrderService _orderService;
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

  // Orders State for Orders / Dispatch Tab
  List<OrderItem> _orders = [];
  bool _isLoadingOrders = false;
  String _orderFilterStatus = 'All';

  static const _primaryColor = Color(0xFF00685F);
  static const _surfaceBg = Color(0xFFF7F9FB);

  @override
  void initState() {
    super.initState();
    _medicineService = widget.medicineService ?? const MedicineService();
    _authService = widget.authService ?? const AuthService();
    _orderService = widget.orderService ?? const OrderService();
    _searchController.addListener(_onSearchChanged);
    _loadMedicines();
    _loadPharmacyDetails();
    _loadOrders();
  }

  Future<void> _loadPharmacyDetails() async {
    try {
      final user = _authService.currentUser;
      final email = user?.email ?? _authService.currentUserEmail;
      final p = await _pharmacyService.fetchPharmacyForOwner(user?.id, email: email);
      if (mounted && p != null) {
        setState(() => _currentPharmacy = p);
        _loadOrders();
      }
    } catch (_) {}
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);
    try {
      String pharmacyUid = _currentPharmacy?.uid ?? '';
      if (pharmacyUid.isEmpty) {
        final resolved = await _medicineService.getPharmacyUid();
        if (resolved != null) pharmacyUid = resolved;
      }
      final orders = await _orderService.fetchOrdersForPharmacy(pharmacyUid);
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      debugPrint('[InventoryScreen] Notice loading pharmacy orders: $e');
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<void> _updateOrderStatus(OrderItem order, String newStatus) async {
    final oldStatus = order.status;
    final messenger = ScaffoldMessenger.of(context);
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;

    // 1. Optimistic real-time UI state refresh: updates screen immediately
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == order.id);
      if (idx != -1) {
        _orders[idx] = _orders[idx].copyWith(status: newStatus);
      }
    });

    try {
      await _orderService.updateOrderStatus(order.id, newStatus);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Order #$shortId status updated to $newStatus'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Revert if remote update failed
      if (mounted) {
        setState(() {
          final idx = _orders.indexWhere((o) => o.id == order.id);
          if (idx != -1) {
            _orders[idx] = _orders[idx].copyWith(status: oldStatus);
          }
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update status in Supabase: $e'),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<OrderItem> get _filteredOrders {
    if (_orderFilterStatus == 'All') return _orders;
    return _orders.where((o) {
      final s = o.status.toLowerCase();
      final target = _orderFilterStatus.toLowerCase();
      if (target == 'pending') {
        return s == 'pending' || s == 'placed';
      }
      if (target == 'verified') {
        return s == 'verified';
      }
      if (target == 'packed') {
        return s == 'packed' || s == 'packing';
      }
      if (target == 'dispatched') {
        return s == 'dispatched' || s.contains('delivery');
      }
      if (target == 'delivered') {
        return s.contains('delivered');
      }
      return s == target;
    }).toList();
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
            tooltip: _selectedNavTab == 1 ? 'Refresh Orders' : 'Refresh Inventory',
            onPressed: _selectedNavTab == 1 ? _loadOrders : _loadMedicines,
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
      body: _selectedNavTab == 1 ? _buildOrdersView() : _buildInventoryView(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavTab,
        onDestinationSelected: (idx) async {
          if (idx == 2) {
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
            if (idx == 1) {
              _loadOrders();
            }
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Orders / Dispatch',
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

  Widget _buildInventoryView() {
    final totalSkus = _medicines.length;
    final lowStockCount = _medicines.where((m) => m.isLowStock).length;
    final activeGenericsCount = _medicines.where((m) => !m.isOutOfStock).length;
    final filtered = _filteredMedicines;

    return RefreshIndicator(
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
    );
  }

  Widget _buildOrdersView() {
    final filtered = _filteredOrders;
    final totalOrders = _orders.length;
    final pendingPackingCount = _orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'pending' || s == 'placed' || s == 'packing' || s == 'packed';
    }).length;
    final dispatchedCount = _orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'dispatched' || s == 'out for delivery' || s == 'out_for_delivery';
    }).length;
    final grossRevenue = _orders.fold<double>(0.0, (sum, o) => sum + o.totalPrice);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders & Dispatch Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Live patient orders queue, phase updates & fulfillment tracking',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6D7A77)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: _primaryColor),
                  tooltip: 'Refresh Orders',
                  onPressed: _loadOrders,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dynamic KPI Cards (Responsive for compact screens)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;
                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          _MetricCard(
                            title: 'Total Orders',
                            value: '$totalOrders',
                            color: const Color(0xFF191C1E),
                            icon: Icons.receipt_long_outlined,
                          ),
                          const SizedBox(width: 8),
                          _MetricCard(
                            title: 'Pending Pack',
                            value: '$pendingPackingCount',
                            color: const Color(0xFF924628),
                            icon: Icons.pending_actions,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MetricCard(
                            title: 'Dispatched',
                            value: '$dispatchedCount',
                            color: const Color(0xFF1B6EBB),
                            icon: Icons.two_wheeler,
                          ),
                          const SizedBox(width: 8),
                          _MetricCard(
                            title: 'Revenue',
                            value: '₹${grossRevenue.toStringAsFixed(0)}',
                            color: _primaryColor,
                            icon: Icons.currency_rupee,
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    _MetricCard(
                      title: 'Total Orders',
                      value: '$totalOrders',
                      color: const Color(0xFF191C1E),
                      icon: Icons.receipt_long_outlined,
                    ),
                    const SizedBox(width: 8),
                    _MetricCard(
                      title: 'Pending Pack',
                      value: '$pendingPackingCount',
                      color: const Color(0xFF924628),
                      icon: Icons.pending_actions,
                    ),
                    const SizedBox(width: 8),
                    _MetricCard(
                      title: 'Dispatched',
                      value: '$dispatchedCount',
                      color: const Color(0xFF1B6EBB),
                      icon: Icons.two_wheeler,
                    ),
                    const SizedBox(width: 8),
                    _MetricCard(
                      title: 'Revenue',
                      value: '₹${grossRevenue.toStringAsFixed(0)}',
                      color: _primaryColor,
                      icon: Icons.currency_rupee,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Pending', 'Verified', 'Packed', 'Dispatched', 'Delivered'].map((status) {
                  final isSelected = _orderFilterStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(status),
                      selectedColor: _primaryColor.withValues(alpha: 0.15),
                      checkmarkColor: _primaryColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? _primaryColor : const Color(0xFF3D4947),
                      ),
                      onSelected: (_) {
                        setState(() => _orderFilterStatus = status);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Orders list or empty state
            if (_isLoadingOrders)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: _primaryColor),
                      SizedBox(height: 16),
                      Text(
                        'Fetching incoming orders...',
                        style: TextStyle(color: Color(0xFF6D7A77)),
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
                        Icons.inbox_outlined,
                        size: 56,
                        color: Color(0xFFBCC9C6),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No orders found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Incoming patient orders in your delivery radius will show here in real-time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Color(0xFF6D7A77)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadOrders,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh Queue'),
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
                'Showing ${filtered.length} of $totalOrders orders',
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
                  final order = filtered[index];
                  return _buildPharmacistOrderCard(order);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacistOrderCard(OrderItem order) {
    final shortId = order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final currentStatus = order.status;
    const lifecyclePhases = ['Pending', 'Verified', 'Packed', 'Dispatched', 'Delivered'];
    
    // Normalize status into one of the 5 canonical lifecycle phases
    String normalizedStatus;
    final lower = currentStatus.toLowerCase();
    if (lower == 'pending' || lower == 'placed') {
      normalizedStatus = 'Pending';
    } else if (lower == 'verified') {
      normalizedStatus = 'Verified';
    } else if (lower == 'packing' || lower == 'packed') {
      normalizedStatus = 'Packed';
    } else if (lower.contains('dispatch') || lower.contains('delivery')) {
      normalizedStatus = 'Dispatched';
    } else if (lower.contains('delivered')) {
      normalizedStatus = 'Delivered';
    } else {
      normalizedStatus = lifecyclePhases.firstWhere(
        (phase) => phase.toLowerCase() == lower,
        orElse: () => 'Pending',
      );
    }

    Color statusColor;
    Color statusBg;
    switch (normalizedStatus.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFB45309);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'verified':
        statusColor = const Color(0xFF0284C7);
        statusBg = const Color(0xFFE0F2FE);
        break;
      case 'packed':
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFDBEAFE);
        break;
      case 'dispatched':
        statusColor = const Color(0xFF6D28D9);
        statusBg = const Color(0xFFEDE9FE);
        break;
      case 'delivered':
        statusColor = const Color(0xFF15803D);
        statusBg = const Color(0xFFDCFCE7);
        break;
      default:
        statusColor = _primaryColor;
        statusBg = _primaryColor.withValues(alpha: 0.1);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Order #$shortId',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF191C1E)),
                      children: [
                        TextSpan(
                          text: ' • ${order.formattedDate}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF6D7A77)),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      normalizedStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Patient Real Full Name and Contact Info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: _primaryColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: (order.patientName != null && order.patientName!.trim().isNotEmpty)
                          ? order.patientName!.trim()
                          : (order.patientEmail.trim().isNotEmpty ? order.patientEmail.trim() : 'Patient (Pending)'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF191C1E)),
                      children: [
                        if (order.patientName != null &&
                            order.patientName!.trim().isNotEmpty &&
                            order.patientEmail.trim().isNotEmpty &&
                            order.patientEmail.trim() != order.patientName!.trim())
                          TextSpan(
                            text: ' • ${order.patientEmail.trim()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF6D7A77)),
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: _primaryColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty)
                        ? order.deliveryAddress!.trim()
                        : 'No delivery address specified',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A77)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Medicine Item and Units
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication, size: 16, color: _primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.medicineName.trim().isNotEmpty ? order.medicineName.trim() : 'Prescription Medicine'} (x${order.quantity} units)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${order.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Phase advancement actions - responsive Wrap eliminates layout overflows on narrow mobile viewports
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Quick progression CTA button
                if (normalizedStatus == 'Pending') ...[
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'Verified'),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Verify Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'Packed'),
                    icon: const Icon(Icons.inventory_2_outlined, size: 14),
                    label: const Text('Start Packing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ] else if (normalizedStatus == 'Verified')
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'Packed'),
                    icon: const Icon(Icons.inventory_2_outlined, size: 14),
                    label: const Text('Start Packing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else if (normalizedStatus == 'Packed')
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'Dispatched'),
                    icon: const Icon(Icons.two_wheeler, size: 14),
                    label: const Text('Dispatch Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else if (normalizedStatus == 'Dispatched')
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'Delivered'),
                    icon: const Icon(Icons.task_alt, size: 14),
                    label: const Text('Mark Delivered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Text('Delivered & Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ],
                  ),

                // Direct Phase Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: normalizedStatus,
                      isDense: true,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)),
                      items: lifecyclePhases.map((phase) {
                        return DropdownMenuItem<String>(
                          value: phase,
                          child: Text(phase),
                        );
                      }).toList(),
                      onChanged: (newPhase) {
                        if (newPhase != null && newPhase != currentStatus) {
                          _updateOrderStatus(order, newPhase);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
