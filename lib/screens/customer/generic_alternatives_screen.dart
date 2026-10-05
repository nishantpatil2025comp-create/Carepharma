import 'package:flutter/material.dart';
import '../../services/medicine_service.dart';
import '../../services/cart_service.dart';
import '../../models/medicine.dart';
import '../../theme/app_colors.dart';
import 'cart_checkout_screen.dart';

/// Screen 2b: Generic Salt & Alternative Medicine Explorer
/// Groups and displays branded medications and generic substitutes under their
/// respective generic salt active molecules.
class GenericAlternativesScreen extends StatefulWidget {
  const GenericAlternativesScreen({
    super.key,
    this.medicineService,
    this.cartService,
  });

  final IMedicineService? medicineService;
  final ICartService? cartService;

  @override
  State<GenericAlternativesScreen> createState() => _GenericAlternativesScreenState();
}

class _GenericAlternativesScreenState extends State<GenericAlternativesScreen> {
  late final IMedicineService _medicineService;
  late final ICartService _cartService;

  List<Medicine> _medicines = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _medicineService = widget.medicineService ?? const MedicineService();
    _cartService = widget.cartService ?? const CartService();
    _loadMedicines();
    _loadCartCount();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadCartCount() async {
    try {
      final items = await _cartService.fetchCartItems();
      if (mounted) setState(() => _cartCount = items.length);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _medicineService.fetchMedicines();
      if (mounted) {
        setState(() {
          _medicines = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Groups medicines by their genericSalt active molecule.
  Map<String, List<Medicine>> get _groupedMedicines {
    final query = _searchController.text.trim().toLowerCase();
    final Map<String, List<Medicine>> groups = {};

    for (final med in _medicines) {
      final saltKey = med.genericSalt?.trim().isNotEmpty == true
          ? med.genericSalt!.trim()
          : 'Other Active Molecules';

      if (query.isNotEmpty) {
        final matchesQuery = med.name.toLowerCase().contains(query) ||
            saltKey.toLowerCase().contains(query) ||
            med.manufacturer.toLowerCase().contains(query);
        if (!matchesQuery) continue;
      }

      groups.putIfAbsent(saltKey, () => []).add(med);
    }

    return groups;
  }

  Future<void> _addToCart(Medicine med) async {
    try {
      await _cartService.addToCart(
        medicineId: med.uid ?? med.name,
        medicineName: med.name,
        price: med.priceInr,
      );
      if (mounted) {
        setState(() => _cartCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${med.name} added to cart!'),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartCheckoutScreen()),
                ).then((_) => _loadCartCount());
              },
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedMedicines;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Generic Salt & Alternatives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartCheckoutScreen())),
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by generic salt (e.g. Paracetamol, Amoxicillin)...',
                prefixIcon: const Icon(Icons.science_outlined, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // Salt Groupings List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No medicines found for "${_searchController.text}".'
                                    : 'No generic medicines registered in inventory.',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final saltName = grouped.keys.elementAt(index);
                          final medsInGroup = grouped[saltName]!;

                          // Find highest priced (branded reference) and lowest priced (maximum savings)
                          medsInGroup.sort((a, b) => a.priceInr.compareTo(b.priceInr));
                          final lowest = medsInGroup.first;
                          final highest = medsInGroup.last;
                          final hasSavings = highest.priceInr > lowest.priceInr;
                          final maxSavingsInr = hasSavings ? (highest.priceInr - lowest.priceInr) : 0.0;
                          final maxSavingsPercent = hasSavings ? ((maxSavingsInr / highest.priceInr) * 100).round() : 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Generic Salt Header Bar
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed.withValues(alpha: 0.3),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.science, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              saltName,
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              '${medsInGroup.length} alternative formulation${medsInGroup.length > 1 ? 's' : ''} available',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (hasSavings && maxSavingsPercent > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F4EA),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Save up to $maxSavingsPercent%',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF137333)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Alternatives Table / Cards
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: medsInGroup.map((med) {
                                      final isLowest = med == lowest && hasSavings;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isLowest ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isLowest ? const Color(0xFF86EFAC) : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (isLowest)
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 4),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF16A34A),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'BEST VALUE GENERIC',
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                                      ),
                                                    ),
                                                  Text(
                                                    med.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${med.manufacturer} • ${med.type}',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  med.formattedPrice,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isLowest ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SizedBox(
                                                  height: 28,
                                                  child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: isLowest ? const Color(0xFF16A34A) : AppColors.primary,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                    onPressed: () => _addToCart(med),
                                                    child: const Text('Add'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
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
