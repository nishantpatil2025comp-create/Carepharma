import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth_service.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

/// Screen: User / Patient Profile & Account Settings
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    this.authService,
    this.initialEmail,
  });

  final AuthService? authService;
  final String? initialEmail;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final AuthService _authService;
  UserProfile? _profile;
  bool _isLoading = true;

  // Settings states
  bool _pushNotifications = true;
  bool _smsUpdates = true;
  bool _genericSavingsAlerts = true;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? const AuthService();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      final email = widget.initialEmail ?? user?.email ?? _authService.currentUserEmail;
      final userId = user?.id ?? _authService.currentUserId;

      final p = await _authService.getUserProfile(userId: userId, email: email);
      if (mounted) {
        setState(() {
          _profile = p ?? UserProfile(
            id: userId ?? 'guest_user',
            email: email ?? 'patient@carepharma.com',
            role: 'user',
            fullName: 'CarePharma Patient',
            phone: '+91 98000 00000',
            deliveryAddress: 'Set your delivery address',
            allergies: 'None recorded',
            isProfileCompleted: true,
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
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of CareWell Pharma?'),
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

  void _openEditProfileDialog() {
    if (_profile == null) return;

    final nameController = TextEditingController(text: _profile!.fullName ?? '');
    final phoneController = TextEditingController(text: _profile!.phone ?? '');
    final addressController = TextEditingController(text: _profile!.deliveryAddress ?? '');
    final allergiesController = TextEditingController(text: _profile!.allergies ?? '');

    double? fetchedLat = _profile!.latitude;
    double? fetchedLng = _profile!.longitude;
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
                        'Edit Patient Profile',
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
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
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
                                    const SnackBar(content: Text('Please enable device location services.')),
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
                                  fetchedLat = pos.latitude;
                                  fetchedLng = pos.longitude;
                                  addressController.text = 'GPS Pin: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (Current Location)';
                                }
                              }
                            } catch (e) {
                              debugPrint('GPS fetch note: $e');
                            } finally {
                              setModalState(() => isLocating = false);
                            }
                          },
                    icon: isLocating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 16),
                    label: const Text('Fetch Current GPS Coordinates for Address'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Known Allergies / Health Notes',
                      prefixIcon: Icon(Icons.healing_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      final updated = _profile!.copyWith(
                        fullName: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        deliveryAddress: addressController.text.trim(),
                        allergies: allergiesController.text.trim(),
                        latitude: fetchedLat,
                        longitude: fetchedLng,
                        isProfileCompleted: true,
                      );

                      await _authService.saveUserProfile(updated);
                      if (ctx.mounted) {
                        navigator.pop();
                      }
                      if (mounted) {
                        setState(() => _profile = updated);
                        await _loadProfile();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!')),
                        );
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Edit Profile',
            onPressed: _openEditProfileDialog,
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
            // USER INFO HERO CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (profile?.fullName?.isNotEmpty == true)
                          ? profile!.fullName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? 'CareWell Patient',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.email ?? 'patient@carepharma.com',
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: Color(0xFF00AA44)),
                              SizedBox(width: 4),
                              Text(
                                'Verified Patient Account',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00AA44)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DETAILS SECTION
            const Text(
              'SAVED CONTACT & DELIVERY INFO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone, color: AppColors.primary),
                    title: const Text('Contact Phone', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    subtitle: Text(
                      profile?.phone?.isNotEmpty == true ? profile!.phone! : 'Not specified',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
                    onTap: _openEditProfileDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.home, color: AppColors.primary),
                    title: const Text('Primary Delivery Address', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    subtitle: Text(
                      profile?.deliveryAddress?.isNotEmpty == true ? profile!.deliveryAddress! : 'No address saved',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
                    onTap: _openEditProfileDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.healing, color: AppColors.secondary),
                    title: const Text('Known Allergies / Health Notes', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    subtitle: Text(
                      profile?.allergies?.isNotEmpty == true ? profile!.allergies! : 'None recorded (Safe)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
                    onTap: _openEditProfileDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // PREFERENCES & SETTINGS
            const Text(
              'APP SETTINGS & PREFERENCES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.6),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Real-time runner arrival & dispatch alerts', style: TextStyle(fontSize: 12)),
                    value: _pushNotifications,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('SMS Order Updates', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Receive OTP and delivery verification SMS', style: TextStyle(fontSize: 12)),
                    value: _smsUpdates,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _smsUpdates = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Generic Salt Savings Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Notify when cheaper generic substitutes are in stock', style: TextStyle(fontSize: 12)),
                    value: _genericSavingsAlerts,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _genericSavingsAlerts = val),
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
                  'Log Out of Account',
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
