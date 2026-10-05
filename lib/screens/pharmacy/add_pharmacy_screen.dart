import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/pharmacy_service.dart';
import '../../models/pharmacy.dart';
import 'pharmacy_dashboard_screen.dart';

/// Screen allowing pharmacy store owners to register their store
/// with GPS coordinates directly into Supabase.
class AddPharmacyScreen extends StatefulWidget {
  const AddPharmacyScreen({
    super.key,
    this.pharmacyService,
    this.redirectToDashboard = false,
    this.initialEmail,
    this.onRegistered,
  });

  final IPharmacyService? pharmacyService;
  final bool redirectToDashboard;
  final String? initialEmail;
  final VoidCallback? onRegistered;

  @override
  State<AddPharmacyScreen> createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends State<AddPharmacyScreen> {
  late final IPharmacyService _pharmacyService;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController uidController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lonController = TextEditingController();

  bool isLoading = false;
  bool isFetchingGps = false;

  @override
  void initState() {
    super.initState();
    _pharmacyService = widget.pharmacyService ?? const PharmacyService();
    // Default suggestion for UID
    uidController.text = 'PH-UID-${DateTime.now().millisecondsSinceEpoch % 100000}';
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      emailController.text = widget.initialEmail!;
    }
  }

  /// Fetches current GPS location of user device and populates latitude and longitude fields.
  Future<void> _getCurrentLocation() async {
    setState(() => isFetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled on device. Please enable GPS.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied in settings.')),
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 4)),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      }

      if (position != null && mounted) {
        final pos = position;
        setState(() {
          latController.text = pos.latitude.toStringAsFixed(6);
          lonController.text = pos.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Captured GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine GPS coordinates. Please try again or enter manually.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isFetchingGps = false);
    }
  }

  Future<void> registerPharmacy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final latText = latController.text.trim();
      final lonText = lonController.text.trim();
      final lat = latText.isNotEmpty ? double.tryParse(latText) : null;
      final lon = lonText.isNotEmpty ? double.tryParse(lonText) : null;

      final pharmacy = Pharmacy(
        uid: uidController.text.trim(),
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
        email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
        latitude: lat,
        longitude: lon,
      );

      await _pharmacyService.registerPharmacy(pharmacy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pharmacy registered successfully!'),
            backgroundColor: Color(0xFF00685F),
          ),
        );

        if (widget.onRegistered != null) {
          widget.onRegistered!();
        } else if (widget.redirectToDashboard) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const PharmacyDashboardScreen(),
            ),
            (route) => false,
          );
        } else {
          Navigator.pop(context); // Go back or close screen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error registering pharmacy: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    uidController.dispose();
    nameController.dispose();
    locationController.dispose();
    phoneController.dispose();
    emailController.dispose();
    latController.dispose();
    lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Register New Pharmacy', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.storefront, color: Colors.teal.shade700, size: 28),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Store to CareWell Network',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Enables nearby generic discovery and customer routing',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: uidController,
                        decoration: const InputDecoration(
                          labelText: 'Pharmacy UID *',
                          hintText: 'e.g. PH-UID-1015',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a unique UID' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Pharmacy Name *',
                          hintText: 'e.g. CareWell Chemist & Wellness',
                          prefixIcon: Icon(Icons.local_pharmacy_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter the pharmacy name' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location / Address *',
                          hintText: 'e.g. Karvenagar, Pune 411052',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter the location' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+91 98234 56789',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Email',
                          hintText: 'contact@carewellpharmacy.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // GPS Coordinate Fields with Auto-Detect Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.gps_fixed, size: 18, color: Color(0xFF00685F)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Store GPS Coordinates',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: isFetchingGps ? null : _getCurrentLocation,
                            icon: isFetchingGps
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 16),
                            label: const Text('Use GPS', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: latController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                hintText: 'e.g. 18.5590',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (double.tryParse(val.trim()) == null) {
                                    return 'Invalid number';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: lonController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                hintText: 'e.g. 73.7868',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (double.tryParse(val.trim()) == null) {
                                    return 'Invalid number';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isLoading ? null : registerPharmacy,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save & Register Pharmacy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
