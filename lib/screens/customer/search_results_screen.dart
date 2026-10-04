import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'medicine_detail_screen.dart';
import 'cart_checkout_screen.dart';
import 'map_nearby_pharmacies_screen.dart';

/// Screen 2: Search Results with Generic Alternatives Benchmark
class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    this.initialQuery = 'Crocin Advanced 650mg',
  });

  final String initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  int _cartCount = 2;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(String medicineName) {
    setState(() => _cartCount++);
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
              MaterialPageRoute(builder: (_) => const CartCheckoutScreen()),
            );
          },
        ),
      ),
    );
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
            decoration: InputDecoration(
              hintText: 'Search Medicine...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, size: 18, color: AppColors.outline),
                      onPressed: () {
                        setState(() => _searchController.clear());
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
                    MaterialPageRoute(builder: (_) => const CartCheckoutScreen()),
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

            // Branded Reference Benchmark Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication, color: AppColors.onSurfaceVariant, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Crocin Advanced 650mg',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ORIGINAL BRANDED',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'GlaxoSmithKline Pharmaceuticals • 15 Tablets Strip',
                              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Active Salt: Paracetamol IP (650mg)',
                              style: TextStyle(fontSize: 12, color: AppColors.outline),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Standard MRP', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          const Text(
                            '₹58.50',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.outline,
                            ),
                          ),
                          Text(
                            '(₹3.90/tab)',
                            style: TextStyle(fontSize: 11, color: AppColors.outline.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.verified_user, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Exact same active chemical molecule & therapeutic bio-efficacy',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Generic Alternatives Heading & Savings Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identified Generic Substitutes (4)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'All verified generic equivalents with Paracetamol IP 650mg',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
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
                        'Save up to ₹40.50',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card 1: Top Recommended Genext
            _buildGenericMedicineCard(
              name: 'Paracetamol IP 650mg (Genext)',
              composition: 'Composition: Paracetamol IP 650mg • Tablet',
              manufacturer: 'Genext Pharma Pvt Ltd',
              packSize: '15 Tablets strip',
              pharmacyName: 'Apollo Diagnostics & Meds',
              pharmacyDistance: '0.8 km',
              deliveryETA: '35 mins',
              price: 18.00,
              mrp: 58.50,
              savingsPercent: '69%',
              savingsInr: '₹40.50',
              perTabPrice: '₹1.20',
              inStockCount: 38,
              badgeTag: 'TOP VALUE CHOICE',
              isTopChoice: true,
            ),
            const SizedBox(height: 12),

            // Card 2: Paracip 650
            _buildGenericMedicineCard(
              name: 'Paracip 650 (Cipla Generic)',
              composition: 'Composition: Paracetamol IP 650mg • Tablet',
              manufacturer: 'Cipla Therapeutics',
              packSize: '15 Tablets strip',
              pharmacyName: 'MedLife Generic Care',
              pharmacyDistance: '1.1 km',
              deliveryETA: '25 mins',
              price: 21.00,
              mrp: 58.50,
              savingsPercent: '64%',
              savingsInr: '₹37.50',
              perTabPrice: '₹1.40',
              inStockCount: 14,
              badgeTag: 'POPULAR REPLACEMENT',
              isTopChoice: false,
            ),
            const SizedBox(height: 12),

            // Card 3: P-650
            _buildGenericMedicineCard(
              name: 'P-650 Generic Tablet',
              composition: 'Composition: Paracetamol IP 650mg • Tablet',
              manufacturer: 'Apex Laboratories',
              packSize: '15 Tablets strip',
              pharmacyName: 'Apollo Jan Aushadhi',
              pharmacyDistance: '2.4 km',
              deliveryETA: '45 mins',
              price: 24.00,
              mrp: 58.50,
              savingsPercent: '59%',
              savingsInr: '₹34.50',
              perTabPrice: '₹1.60',
              inStockCount: 22,
              badgeTag: 'JAN AUSHADHI VERIFIED',
              isTopChoice: false,
            ),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              composition,
              style: const TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              'Mfr: $manufacturer • $packSize',
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

            // Price & Add to Cart Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
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
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _addToCart(name),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
