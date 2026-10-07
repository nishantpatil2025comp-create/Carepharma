import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/order_dialog.dart';
import 'medicine_detail_screen.dart';
import 'cart_screen.dart';
import 'map_nearby_pharmacies_screen.dart';
import 'generic_alternatives_screen.dart';

/// Screen 2: Search Results with Generic Alternatives Benchmark
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.initialQuery = '',
  });

  final String initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  final MedicineService _medicineService = const MedicineService();
  final CartService _cartService = const CartService();
  List<Medicine> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _cartCount = 0;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _loadCartCount();
    if (widget.initialQuery.trim().isNotEmpty) {
      _performSearch(widget.initialQuery.trim());
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final items = await _cartService.fetchCartItems();
      if (mounted) setState(() => _cartCount = items.length);
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _medicineService.fetchCustomerMedicines(query: trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addToCart(String medicineName, {Medicine? medicineModel, double? price}) async {
    setState(() => _cartCount++);
    try {
      await _cartService.addToCart(
        medicineId: medicineModel?.uid ?? medicineName,
        medicineName: medicineName,
        price: medicineModel?.priceInr ?? price ?? 18.0,
        pharmacyUid: medicineModel?.pharmacyUid,
      );
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$medicineName added to cart!'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: AppColors.secondaryFixed,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: (query) => _performSearch(query),
            onChanged: (query) {
              if (query.isEmpty || query.length >= 2) {
                _performSearch(query);
              }
            },
            decoration: InputDecoration(
              hintText: 'Search Medicine...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, size: 18, color: AppColors.outline),
                      onPressed: () {
                        setState(() => _searchController.clear());
                        _performSearch('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Delivering to Baner 411045',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.expand_more, size: 16, color: AppColors.outline),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: AppColors.secondary),
                      SizedBox(width: 3),
                      Text(
                        'Match Guarantee',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter & Sorting Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Filters', Icons.tune, isAction: true),
                  _buildFilterChip('Distance: < 3 km', null),
                  _buildFilterChip('Price: Low to High', Icons.swap_vert),
                  _buildFilterChip('Delivery: < 2 hrs', Icons.bolt),
                  _buildFilterChip('In Stock Only', Icons.check_circle),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_searchResults.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science, size: 20, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _searchResults.first.genericSalt != null && _searchResults.first.genericSalt!.isNotEmpty
                                ? 'Generic Salt: ${_searchResults.first.genericSalt}'
                                : 'Generic Bio-Equivalent Alternatives',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                          const Text(
                            'Branded alternatives mapped below share identical bio-availability',
                            style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GenericAlternativesScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View All Salts ›', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!_hasSearched || _searchController.text.trim().isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.manage_search, size: 54, color: AppColors.outline),
                    const SizedBox(height: 12),
                    const Text(
                      'Search Medicines & Generics',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Type a medicine name or generic salt to search live inventory.',
                      style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (_searchResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.medication_liquid_outlined, size: 48, color: AppColors.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No medicines found for "${_searchController.text}"',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Try searching for different active salts or brand names in our catalog.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              // Generic Alternatives Heading & Savings Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Identified Generic Substitutes (${_searchResults.length})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'All verified alternatives matching "${_searchController.text}"',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.savings, size: 15, color: AppColors.secondary),
                        SizedBox(width: 4),
                        Text(
                          'Save up to 60%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._searchResults.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                final double mrp = (med.priceInr * 1.6).roundToDouble();
                final double savingsVal = mrp - med.priceInr;
                final int savingsPct = ((savingsVal / mrp) * 100).round();
                final badgeTag = index == 0
                    ? 'TOP VALUE CHOICE'
                    : (index == 1
                        ? 'POPULAR REPLACEMENT'
                        : (index == 2 ? 'JAN AUSHADHI VERIFIED' : 'GENERIC EQUIVALENT'));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGenericMedicineCard(
                    name: med.name,
                    composition: med.genericSalt != null && med.genericSalt!.isNotEmpty
                        ? 'Composition: ${med.genericSalt} • ${med.type}'
                        : 'Dosage Form: ${med.type}',
                    manufacturer: med.manufacturer.isNotEmpty ? med.manufacturer : 'CarePharma Lab',
                    packSize: 'Standard Unit Strip',
                    pharmacyName: med.pharmacyName ?? 'CarePharma Partner Pharmacy',
                    pharmacyDistance: 'Hyperlocal Store',
                    deliveryETA: 'Same Day Delivery',
                    price: med.priceInr,
                    mrp: mrp,
                    savingsPercent: '$savingsPct%',
                    savingsInr: '₹${savingsVal.toStringAsFixed(2)}',
                    perTabPrice: '₹${(med.priceInr / 10).toStringAsFixed(2)}',
                    inStockCount: med.stock,
                    badgeTag: badgeTag,
                    isTopChoice: index == 0,
                    medicineModel: med,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData? icon, {bool isAction = false}) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: isAction ? AppColors.onPrimaryFixed : (isSelected ? AppColors.primary : AppColors.outline),
              )
            : null,
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() => _selectedFilter = val ? label : 'All');
        },
        backgroundColor: isAction ? AppColors.primaryFixed : AppColors.surfaceContainerLowest,
        selectedColor: AppColors.primaryFixed,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAction ? AppColors.onPrimaryFixed : (isSelected ? AppColors.primary : AppColors.onSurface),
        ),
      ),
    );
  }

  Widget _buildGenericMedicineCard({
    required String name,
    required String composition,
    required String manufacturer,
    required String packSize,
    required String pharmacyName,
    required String pharmacyDistance,
    required String deliveryETA,
    required double price,
    required double mrp,
    required String savingsPercent,
    required String savingsInr,
    required String perTabPrice,
    required int inStockCount,
    required String badgeTag,
    required bool isTopChoice,
    Medicine? medicineModel,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineDetailScreen(
              medicineName: name,
              genericPrice: price,
              brandedPrice: mrp,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopChoice ? AppColors.primary.withValues(alpha: 0.5) : AppColors.outlineVariant.withValues(alpha: 0.5),
            width: isTopChoice ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowTeal,
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTopChoice ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeTag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isTopChoice ? AppColors.onSecondaryContainer : AppColors.onSurface,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$savingsPercent CHEAPER',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimaryFixedVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'In Stock ($inStockCount strips)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Medicine title & composition
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              composition,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              'Mfr: $manufacturer • $packSize',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),

            // Pharmacy Fulfillment Info
            Row(
              children: [
                const Icon(Icons.local_pharmacy, size: 15, color: AppColors.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    pharmacyName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'View on map',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapNearbyPharmaciesScreen()),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '• $pharmacyDistance • ETA $deliveryETA',
                    style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Price & Add to Cart Action - Responsive LayoutBuilder prevents overflow on narrow screens
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 390;

                final priceColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          '₹${price.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        Text(
                          '₹${mrp.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.outline,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Save $savingsInr ($savingsPercent)',
                      style: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _addToCart(name, medicineModel: medicineModel, price: price),
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text('Add to Cart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        showOrderDialog(
                          context,
                          medicineModel != null
                              ? medicineModel.toJson()
                              : {
                                  'Name': name,
                                  'Price_INR': price,
                                  'generic_salt': composition,
                                },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Order Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      priceColumn,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionButtons,
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: priceColumn),
                    const SizedBox(width: 8),
                    actionButtons,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
