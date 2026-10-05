import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth_service.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

/// Screen: Pharmacist Store Profile, Admin Details & Settings
class PharmacistProfileScreen extends StatefulWidget {
  const PharmacistProfileScreen({
    super.key,
    this.authService,
    this.pharmacyService,
  });

  final AuthService? authService;
  final IPharmacyService? pharmacyService;

  @override
  State<PharmacistProfileScreen> createState() => _PharmacistProfileScreenState();
}

class _PharmacistProfileScreenState extends State<PharmacistProfileScreen> {
  late final AuthService _authService;
  late final IPharmacyService _pharmacyService;

  Pharmacy? _pharmacy;
  bool _isLoading = true;

  // Pharmacist Settings
  bool _storeOpen = true;
  bool _audioOrderAlerts = true;
  bool _autoDispatchRunners = true;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? const AuthService();
    _pharmacyService = widget.pharmacyService ?? const PharmacyService();
    _loadPharmacyDetails();
  }

  Future<void> _loadPharmacyDetails() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      final userId = user?.id ?? _authService.currentUserId;
      final email = user?.email ?? _authService.currentUserEmail;

      final store = await _pharmacyService.fetchPharmacyForOwner(userId, email: email);
      if (mounted) {
        setState(() {
          _pharmacy = store ?? Pharmacy(
            uid: 'PH-UID-1011',
            name: 'Apollo Meds & Wellness',
            location: 'Shop 4, High Street, Baner, Pune 411045',
            phone: '+91 98230 11234',
            email: email ?? 'pharmacist@apollomeds.com',
            license: 'MH-PUN-2024-8891',
            latitude: 18.5590,
            longitude: 73.7868,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out Pharmacist'),
        content: const Text('Are you sure you want to log out of your pharmacy store dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CarePharmaApp()),
        (route) => false,
      );
    }
  }

  void _openEditStoreDialog() {
    if (_pharmacy == null) return;

    final nameController = TextEditingController(text: _pharmacy!.name);
    final locationController = TextEditingController(text: _pharmacy!.location ?? '');
    final phoneController = TextEditingController(text: _pharmacy!.phone ?? '');
    final licenseController = TextEditingController(text: _pharmacy!.license ?? '');
    final latController = TextEditingController(text: _pharmacy!.latitude?.toString() ?? '');
    final lonController = TextEditingController(text: _pharmacy!.longitude?.toString() ?? '');

    bool isLocating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Pharmacy Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Pharmacy Store Name',
                      prefixIcon: Icon(Icons.storefront),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Address / Locality (e.g. Karvenagar, Pune)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Store Contact Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Drug License Number',
                      prefixIcon: Icon(Icons.verified_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lonController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isLocating
                        ? null
                        : () async {
                            setModalState(() => isLocating = true);
                            try {
                              final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Please turn on GPS on your device.')),
                                  );
                                }
                                return;
                              }
                              var perm = await Geolocator.checkPermission();
                              if (perm == LocationPermission.denied) {
                                perm = await Geolocator.requestPermission();
                              }
                              if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
                                Position? pos;
                                try {
                                  pos = await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(timeLimit: Duration(seconds: 4)),
                                  );
                                } catch (_) {
                                  pos = await Geolocator.getLastKnownPosition().timeout(
                                    const Duration(seconds: 2),
                                    onTimeout: () => null,
                                  );
                                }
                                if (pos != null) {
                                  latController.text = pos.latitude.toString();
                                  lonController.text = pos.longitude.toString();
                                }
                              }
                            } catch (e) {
                              debugPrint('GPS store fetch note: $e');
                            } finally {
                              setModalState(() => isLocating = false);
                            }
                          },
                    icon: isLocating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('Read Live GPS Location of Store'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00685F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      final updated = _pharmacy!.copyWith(
                        name: nameController.text.trim(),
                        location: locationController.text.trim(),
                        phone: phoneController.text.trim(),
                        license: licenseController.text.trim(),
                        latitude: double.tryParse(latController.text.trim()),
                        longitude: double.tryParse(lonController.text.trim()),
                      );

                      await _pharmacyService.updatePharmacy(updated);
                      if (ctx.mounted) {
                        navigator.pop();
                      }
                      if (mounted) {
                        setState(() => _pharmacy = updated);
                        await _loadPharmacyDetails();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Pharmacy details updated successfully!')),
                        );
                      }
                    },
                    child: const Text('Save Store Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final p = _pharmacy;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Pharmacy Partner Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF00685F)),
            tooltip: 'Edit Store Details',
            onPressed: _openEditStoreDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Log Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STORE HERO CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00685F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.storefront, size: 36, color: Color(0xFF00685F)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.name ?? 'Pharmacy Store',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p?.email ?? 'store@carepharma.com',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00AA44).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'License: ${p?.license ?? "MH-PUN-2024-8891"}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00AA44)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // STORE DETAILS SECTION
            const Text(
              'STORE CONFIGURATION & GPS LOCATION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00685F), letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF00685F)),
                    title: const Text('Store Address / Locality', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(
                      p?.location ?? 'Not specified',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    onTap: _openEditStoreDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Color(0xFF00685F)),
                    title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(
                      p?.phone ?? 'Not specified',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    onTap: _openEditStoreDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.pin_drop, color: Color(0xFF00685F)),
                    title: const Text('GPS Coordinates (Lat / Lng)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(
                      p?.hasCoordinates == true
                          ? '${p!.latitude!.toStringAsFixed(4)}, ${p.longitude!.toStringAsFixed(4)}'
                          : 'No coordinates set (Proximity sorting inactive)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    onTap: _openEditStoreDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // STORE SETTINGS
            const Text(
              'STORE OPERATIONS & DISPATCH SETTINGS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00685F), letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Store Status (Accepting Orders)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(_storeOpen ? 'Open for customer prescription requests' : 'Temporarily paused', style: const TextStyle(fontSize: 12)),
                    value: _storeOpen,
                    activeThumbColor: const Color(0xFF00685F),
                    onChanged: (val) => setState(() => _storeOpen = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Audio Alerts for Incoming Orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Play sound chime when new customer orders arrive', style: TextStyle(fontSize: 12)),
                    value: _audioOrderAlerts,
                    activeThumbColor: const Color(0xFF00685F),
                    onChanged: (val) => setState(() => _audioOrderAlerts = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Auto Runner Dispatch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Automatically assign nearest store runner upon packing', style: TextStyle(fontSize: 12)),
                    value: _autoDispatchRunners,
                    activeThumbColor: const Color(0xFF00685F),
                    onChanged: (val) => setState(() => _autoDispatchRunners = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LOG OUT BUTTON
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Log Out of Pharmacist Portal',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
