import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../auth_service.dart';
import '../../models/user_profile.dart';
import 'customer_home_screen.dart';

/// Screen: User Onboarding / Profile Setup page
/// Shown to newly registered users to capture essential delivery and health details
/// before taking them to the Customer Home Screen.
class UserOnboardingScreen extends StatefulWidget {
  const UserOnboardingScreen({
    super.key,
    this.authService,
    this.initialEmail,
  });

  final AuthService? authService;
  final String? initialEmail;

  @override
  State<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends State<UserOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController(text: 'Flat 402, Green Glen Apts, Baner, Pune');
  final _cityPinController = TextEditingController(text: 'Pune, 411045');
  final _healthNotesController = TextEditingController();

  bool _isLoading = false;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;
  late final AuthService _authService;

  Future<void> _fetchGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS location service.')),
          );
        }
        return;
      }
      var perm = await Geolocator.checkPermission().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => LocationPermission.denied,
      );
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => LocationPermission.denied,
        );
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
          final p = pos;
          setState(() {
            _latitude = p.latitude;
            _longitude = p.longitude;
            _addressController.text = 'GPS Pin: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)} (Current Location)';
          });
        }
      }
    } catch (e) {
      debugPrint('[UserOnboardingScreen] GPS fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? const AuthService();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityPinController.dispose();
    _healthNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = widget.initialEmail ?? _authService.currentUserEmail ?? 'user@carepharma.com';
      final userId = _authService.currentUserId ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

      final profile = UserProfile(
        id: userId,
        email: email,
        role: 'user',
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        deliveryAddress: '${_addressController.text.trim()}, ${_cityPinController.text.trim()}',
        latitude: _latitude,
        longitude: _longitude,
        allergies: _healthNotesController.text.trim().isNotEmpty ? _healthNotesController.text.trim() : null,
        isProfileCompleted: true,
      );

      await _authService.saveUserProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup complete! Welcome to CareWell Pharma.'),
            backgroundColor: AppColors.primary,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Complete Your Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header banner
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 30),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient Profile Setup',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tell us where to deliver and who to contact',
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

                      // Full Name
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Rahul Mehta',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Contact Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone Number *',
                          hintText: 'e.g. +91 98230 44556',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your phone number' : null,
                      ),
                      const SizedBox(height: 16),

                      // Primary Delivery Address
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Street / Delivery Address *',
                          hintText: 'e.g. Flat 402, Green Glen Apts, Baner Road',
                          prefixIcon: Icon(Icons.home_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your delivery address' : null,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isLocating ? null : _fetchGpsLocation,
                        icon: _isLocating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 16),
                        label: const Text('Fetch Current GPS Coordinates for Address'),
                      ),
                      const SizedBox(height: 16),

                      // City and Postal Code
                      TextFormField(
                        controller: _cityPinController,
                        decoration: const InputDecoration(
                          labelText: 'City & PIN Code',
                          hintText: 'e.g. Pune, 411045',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Health / Allergy Notes
                      TextFormField(
                        controller: _healthNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Known Allergies / Health Notes (Optional)',
                          hintText: 'e.g. Penicillin allergy, Diabetic',
                          prefixIcon: Icon(Icons.healing_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _submitProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Profile & Start Shopping', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
