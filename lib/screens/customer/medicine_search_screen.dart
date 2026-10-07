import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/cart_service.dart';
import '../../widgets/order_dialog.dart';
import '../../theme/app_colors.dart';
import 'cart_screen.dart';
import 'upload_prescription_screen.dart';

/// Screen for strict query-only medicine and generic salt searching.
/// On initial load, displays zero medicines.
/// Queries Supabase medicines table matching strictly against 'name' and 'generic_salt'.
class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({
    super.key,
    this.initialQuery = '',
    this.cartService,
  });

  final String initialQuery;
  final ICartService? cartService;

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  late final ICartService _cartService;
  late final TextEditingController searchController;

  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  bool hasSearched = false;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _cartService = widget.cartService ?? const CartService();
    searchController = TextEditingController(text: widget.initialQuery);
    _loadCartCount();

    if (widget.initialQuery.trim().isNotEmpty) {
      searchMedicines(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCartCount() async {
    try {
      final items = await _cartService.fetchCartItems();
      if (mounted) {
        setState(() => _cartCount = items.length);
      }
    } catch (_) {}
  }

  Future<void> searchMedicines(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final client = _supabase;
      if (client == null) {
        // Offline / testing without Supabase connection
        setState(() {
          searchResults = [];
          hasSearched = true;
          isSearching = false;
        });
        return;
      }

      // Query Supabase medicines table matching strictly "Name" or generic_salt
      dynamic response;
      try {
        response = await client
            .from('medicines')
            .select()
            .or('"Name".ilike.%$trimmed%,generic_salt.ilike.%$trimmed%')
            .order('"Name"', ascending: true);
      } catch (columnErr) {
        debugPrint('[MedicineSearchScreen] Query note: $columnErr. Trying without order.');
        response = await client
            .from('medicines')
            .select()
            .or('"Name".ilike.%$trimmed%,generic_salt.ilike.%$trimmed%');
      }

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(response as List<dynamic>);

        // Query pharmacies table using pharmacy_uid to resolve pharmacy names
        final pharmacyUids = list
            .map((e) => (e['pharmacy_uid'] ?? e['Pharmacy_UID'])?.toString())
            .where((id) => id != null && id.trim().isNotEmpty)
            .toSet()
            .toList();

        final Map<String, String> pharmacyNames = {};
        if (pharmacyUids.isNotEmpty) {
          try {
            final pharmRes = await client
                .from('pharmacies')
                .select('"UID", "Name"')
                .inFilter('"UID"', pharmacyUids);
            for (final p in pharmRes as List<dynamic>) {
              final uid = (p['UID'] ?? p['uid'] ?? '').toString();
              final name = (p['Name'] ?? p['name'] ?? '').toString();
              if (uid.isNotEmpty && name.isNotEmpty) {
                pharmacyNames[uid] = name;
              }
            }
          } catch (err) {
            debugPrint('[MedicineSearchScreen] Pharmacy lookup notice: $err');
          }
        }

        for (final m in list) {
          final pUid = (m['pharmacy_uid'] ?? m['Pharmacy_UID'])?.toString();
          if (pUid != null && pharmacyNames.containsKey(pUid)) {
            m['pharmacy_name'] = pharmacyNames[pUid];
          } else if (m['pharmacies'] is Map && m['pharmacies']['Name'] != null) {
            m['pharmacy_name'] = m['pharmacies']['Name'];
          } else {
            m['pharmacy_name'] = 'CarePharma Partner Pharmacy';
          }
        }

        list.sort((a, b) {
          final na = (a['Name'] ?? a['name'] ?? '').toString().toLowerCase();
          final nb = (b['Name'] ?? b['name'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
        setState(() {
          searchResults = list;
          hasSearched = true;
          isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> med) async {
    final name = (med['Name'] ?? med['name'] ?? 'Medicine').toString();
    final uid = (med['UID'] ?? med['uid'] ?? med['id'] ?? name).toString();
    final pharmacyUid = (med['pharmacy_uid'] ?? med['Pharmacy_UID'])?.toString();
    final rawPrice = med['Price_INR'] ?? med['price_inr'] ?? 0.0;
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice.toString()) ?? 0.0;

    try {
      await _cartService.addToCart(
        medicineId: uid,
        medicineName: name,
        price: price,
        pharmacyUid: pharmacyUid,
      );
      if (mounted) {
        setState(() => _cartCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added to cart!'),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ).then((_) => _loadCartCount());
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cart: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Search Medicines & Salts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Upload Prescription',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                tooltip: 'View Cart',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ).then((_) => _loadCartCount());
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBA1A1A),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by medicine name or generic salt...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00685F)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFBFC8C6)),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          searchMedicines('');
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {});
                searchMedicines(val);
              },
            ),
          ),
          Expanded(
            child: isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00685F)))
                : !hasSearched
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.manage_search, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Type a medicine name or generic salt to search inventory.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF00685F),
                                  side: const BorderSide(color: Color(0xFF00685F)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                                ),
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('Or Upload Prescription'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : searchResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No matching medicines found in inventory.',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00685F),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const UploadPrescriptionScreen()),
                                    ),
                                    icon: const Icon(Icons.receipt_long, size: 18),
                                    label: const Text('Upload Prescription for Review'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final med = searchResults[index];
                              final name = (med['Name'] ?? med['name'] ?? '').toString();
                              final salt = (med['generic_salt'] ?? med['Generic_Salt'] ?? 'N/A').toString();
                              final pharmacyName = (med['pharmacy_name'] ?? med['Pharmacy_Name'] ?? 'CarePharma Partner Pharmacy').toString();
                              final priceNum = med['Price_INR'] ?? med['price_inr'] ?? 0;
                              final price = priceNum is num ? priceNum.toDouble() : double.tryParse(priceNum.toString()) ?? 0.0;
                              final stock = med['Stock'] ?? med['stock'];

                              return Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isCompact = constraints.maxWidth < 390;

                                      final detailsWidget = Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Generic Salt: $salt',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(Icons.storefront, size: 13, color: Colors.teal.shade700),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  pharmacyName,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade900),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (stock != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Stock: $stock units',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ],
                                      );

                                      final priceWidget = Text(
                                        '₹${price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00685F),
                                          fontSize: 16,
                                        ),
                                      );

                                      final buttonsWidget = Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF00685F),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _addToCart(med),
                                            icon: const Icon(Icons.add_shopping_cart, size: 12),
                                            label: const Text('Add to Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => showOrderDialog(context, med),
                                            child: const Text('Order', style: TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      );

                                      if (isCompact) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.teal.shade50,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.medication, color: Color(0xFF00685F), size: 24),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(child: detailsWidget),
                                                const SizedBox(width: 8),
                                                priceWidget,
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: buttonsWidget,
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.medication, color: Color(0xFF00685F), size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: detailsWidget),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              priceWidget,
                                              const SizedBox(height: 6),
                                              buttonsWidget,
                                            ],
                                          ),
                                        ],
                                      );
                                    },
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
