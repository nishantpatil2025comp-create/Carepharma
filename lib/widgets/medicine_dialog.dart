import 'package:flutter/material.dart';
import '../models/medicine.dart';

/// Modal dialog for adding or editing a medicine record.
/// Does NOT allow manual input of UID or Pharmacy UID (assigned automatically).
class MedicineDialog extends StatefulWidget {
  const MedicineDialog({
    super.key,
    this.existingMedicine,
    required this.onSave,
  });

  /// If provided, dialog operates in Edit mode; otherwise in Add mode.
  final Medicine? existingMedicine;

  /// Callback when user submits valid medicine data.
  final Future<void> Function(Medicine medicine) onSave;

  @override
  State<MedicineDialog> createState() => _MedicineDialogState();
}

class _MedicineDialogState extends State<MedicineDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _expiryController;

  late String _selectedType;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _formulationTypes = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Ointment',
    'Drops',
    'Inhaler',
    'Injection',
    'Sachet',
  ];

  @override
  void initState() {
    super.initState();
    final med = widget.existingMedicine;
    _nameController = TextEditingController(text: med?.name ?? '');
    _priceController = TextEditingController(
      text: med != null ? med.priceInr.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(
      text: med != null ? med.stock.toString() : '',
    );
    _manufacturerController = TextEditingController(text: med?.manufacturer ?? '');
    _expiryController = TextEditingController(text: med?.expiryDate ?? '');

    _selectedType = (med != null && _formulationTypes.contains(med.type))
        ? med.type
        : _formulationTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _manufacturerController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      setState(() => _errorMessage = 'Please enter a valid price (₹ >= 0)');
      return;
    }

    final stock = int.tryParse(_stockController.text.trim());
    if (stock == null || stock < 0) {
      setState(() => _errorMessage = 'Please enter a valid stock quantity (>= 0)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final medicine = Medicine(
        uid: widget.existingMedicine?.uid,
        name: _nameController.text.trim(),
        priceInr: price,
        type: _selectedType,
        stock: stock,
        manufacturer: _manufacturerController.text.trim(),
        expiryDate: _expiryController.text.trim(),
        pharmacyUid: widget.existingMedicine?.pharmacyUid,
      );

      await widget.onSave(medicine);
      if (mounted) {
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingMedicine != null;
    const primaryColor = Color(0xFF00685F);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.medication_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Medicine' : 'Add New Medicine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDAD6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBA1A1A)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF93000A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // 1. Medicine Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                    hintText: 'e.g. Amoxyclav 625 Generic IP',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Medicine name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Type & Price Grid
                Row(
                  children: [
                    // Formulation Type Dropdown
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _formulationTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price (₹)
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹) *',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Price is required';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Stock Quantity & Expiry Date
                Row(
                  children: [
                    // Stock
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock Units *',
                          hintText: 'e.g. 100',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Stock is required';
                          }
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Must be >= 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expiry Date
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _expiryController,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date *',
                          hintText: 'YYYY-MM-DD or MM/YYYY',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event, size: 20),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 365)),
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              );
                              if (picked != null) {
                                final month = picked.month.toString().padLeft(2, '0');
                                final day = picked.day.toString().padLeft(2, '0');
                                _expiryController.text = '${picked.year}-$month-$day';
                              }
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Expiry is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Manufacturer
                TextFormField(
                  controller: _manufacturerController,
                  decoration: const InputDecoration(
                    labelText: 'Manufacturer / Chemist *',
                    hintText: 'e.g. Cipla Ltd, Sun Pharma, Mankind',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Manufacturer is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Actions: Cancel & Save
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        isEdit ? 'Update Medicine' : 'Save Medicine',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
