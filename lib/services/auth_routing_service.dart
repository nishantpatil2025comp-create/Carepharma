import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'medicine_service.dart';
import '../screens/inventory_screen.dart';
import '../screens/pharmacy/add_pharmacy_screen.dart';
import '../screens/customer/user_onboarding_screen.dart';
import '../screens/customer/customer_home_screen.dart';
import '../theme/app_colors.dart';

/// Central service managing dual-role authentication routing,
/// tailored onboarding flows, and database checks for CareWell Pharma.
class AuthRoutingService {
  const AuthRoutingService({
    AuthService? authService,
    this.medicineService,
  })  : _authService = authService ?? const AuthService();

  final AuthService _authService;
  final IMedicineService? medicineService;

  /// Resolves the destination screen based on authenticated role and database state.
  Future<Widget> resolveDestinationScreen({
    String? preferredRole,
    String? email,
  }) async {
    final currentUser = _authService.currentUser;
    final effectiveEmail = email ?? currentUser?.email ?? _authService.currentUserEmail;
    final userId = currentUser?.id ?? _authService.currentUserId;

    // 1. Determine role from parameter, user metadata, or profiles table
    String? role = preferredRole?.trim().toLowerCase();
    role ??= await _authService.getUserRole(user: currentUser, email: effectiveEmail);

    if (role == null || (role != 'pharmacist' && role != 'user')) {
      // Role is unspecified -> Prompt user to select their role
      return RoleSelectionPromptScreen(
        authService: _authService,
        medicineService: medicineService,
        email: effectiveEmail,
      );
    }

    // Persist determined role
    await _authService.setUserRole(role, user: currentUser, email: effectiveEmail);

    // 2. Pharmacist Flow
    if (role == 'pharmacist') {
      final pharmacyExists = await _authService.checkPharmacyExists(
        email: effectiveEmail,
        userId: userId,
      );

      if (!pharmacyExists) {
        // New Pharmacist (No store found): Redirect to "Register / Add Pharmacy" form
        return AddPharmacyScreen(
          initialEmail: effectiveEmail,
          redirectToDashboard: true,
        );
      } else {
        // Existing Pharmacist: Direct straight to Pharmacist Admin / Inventory Management Dashboard
        return InventoryScreen(
          medicineService: medicineService,
          authService: _authService,
        );
      }
    }

    // 3. User / Patient Flow
    final isProfileComplete = await _authService.isUserProfileComplete(
      userId: userId,
      email: effectiveEmail,
    );

    if (!isProfileComplete) {
      // New Patient (No completed profile found): Redirect to User Onboarding page
      return UserOnboardingScreen(
        authService: _authService,
        initialEmail: effectiveEmail,
      );
    } else {
      // Existing Patient: Direct straight to User Home Page
      return const CustomerHomeScreen();
    }
  }

  /// Helper to route the user to their resolved destination immediately after login or OTP verification.
  Future<void> navigateAfterAuth(
    BuildContext context, {
    String? preferredRole,
    String? email,
  }) async {
    final destinationScreen = await resolveDestinationScreen(
      preferredRole: preferredRole,
      email: email,
    );

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destinationScreen),
      );
    }
  }
}

/// Fallback interactive dialog screen when user signs in without a pre-selected role
class RoleSelectionPromptScreen extends StatelessWidget {
  const RoleSelectionPromptScreen({
    super.key,
    required this.authService,
    this.medicineService,
    this.email,
  });

  final AuthService authService;
  final IMedicineService? medicineService;
  final String? email;

  Future<void> _selectRole(BuildContext context, String role) async {
    final routing = AuthRoutingService(
      authService: authService,
      medicineService: medicineService,
    );
    await routing.navigateAfterAuth(
      context,
      preferredRole: role,
      email: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Select Account Role', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle, size: 54, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to CareWell Pharma',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please choose how you will be using this account:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 28),

                    // Option 1: Customer / Patient
                    InkWell(
                      onTap: () => _selectRole(context, 'user'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF0066CC).withValues(alpha: 0.3)),
                          color: const Color(0xFF0066CC).withValues(alpha: 0.04),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person, color: Color(0xFF0066CC), size: 28),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Patient / Customer',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0066CC)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Search generic medicines, find nearby stores, and order online.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Color(0xFF0066CC)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Option 2: Pharmacist
                    InkWell(
                      onTap: () => _selectRole(context, 'pharmacist'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF00AA44).withValues(alpha: 0.3)),
                          color: const Color(0xFF00AA44).withValues(alpha: 0.04),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.storefront, color: Color(0xFF00AA44), size: 28),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pharmacist / Store Partner',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00AA44)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Manage medicine stock, inventory, and fulfill deliveries.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Color(0xFF00AA44)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
