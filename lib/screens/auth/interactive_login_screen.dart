import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../auth_service.dart';
import '../../services/medicine_service.dart';
import '../customer/customer_home_screen.dart';
import '../pharmacy/pharmacy_dashboard_screen.dart';
import '../pharmacy/pharmacy_registration_screen.dart';
import '../screen_showcase_sheet.dart';

/// Screen 12: Interactive Multi-Role Login Portal
class InteractiveLoginScreen extends StatefulWidget {
  const InteractiveLoginScreen({
    super.key,
    this.authService,
    this.medicineService,
  });

  final AuthService? authService;
  final IMedicineService? medicineService;

  @override
  State<InteractiveLoginScreen> createState() => _InteractiveLoginScreenState();
}

class _InteractiveLoginScreenState extends State<InteractiveLoginScreen> {
  // Current view: 0 = Role Selection, 1 = User Login, 2 = Pharmacy Admin Login
  int _currentView = 0;

  // Controllers for User Login
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController();
  bool _obscureUserPassword = true;

  // Controllers for Pharmacy Login
  final _pharmacyIdController = TextEditingController();
  final _pharmacyEmailController = TextEditingController();
  final _pharmacyPasswordController = TextEditingController();
  bool _obscurePharmacyPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _pharmacyIdController.dispose();
    _pharmacyEmailController.dispose();
    _pharmacyPasswordController.dispose();
    super.dispose();
  }

  void _autofillUser() {
    setState(() {
      _userEmailController.text = 'rahul.mehta@example.com';
      _userPasswordController.text = 'demo123';
    });
  }

  void _autofillPharmacy() {
    setState(() {
      _pharmacyIdController.text = 'PH-88291';
      _pharmacyEmailController.text = 'chemist@apollomeds.com';
      _pharmacyPasswordController.text = 'demo123';
    });
  }

  Future<void> _handleUserLogin() async {
    final email = _userEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate auth or Supabase OTP signin
      final authService = widget.authService ?? const AuthService();
      await authService.sendOtpCode(email);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
    );
  }

  Future<void> _handlePharmacyLogin() async {
    final email = _pharmacyEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter pharmacy email');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = widget.authService ?? const AuthService();
      await authService.sendOtpCode(email);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PharmacyDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.apps, color: AppColors.primary),
            tooltip: 'All Screens Directory',
            onPressed: () => ScreenShowcaseSheet.show(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _currentView == 0
                      ? _buildRoleSelectionView()
                      : (_currentView == 1 ? _buildUserLoginView() : _buildPharmacyLoginView()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // VIEW 1: Role Decision Cards
  Widget _buildRoleSelectionView() {
    return Column(
      key: const ValueKey('role_selection'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pharmacy Icon Header
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.local_pharmacy, size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 14),

        // Verified Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            border: Border.all(color: const Color(0xFFA7F3D0)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 14, color: Color(0xFF047857)),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Verified Generic Marketplace',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'CarePharma',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Find affordable medicines nearby and save up to 70%',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 28),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'CHOOSE PORTAL TO CONTINUE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 10),

        // Button 1: Login as User
        InkWell(
          onTap: () => setState(() => _currentView = 1),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.userBlue,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x330066CC), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Login as User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Order medicines & track deliveries', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Button 2: Login as Pharmacy Admin
        InkWell(
          onTap: () => setState(() => _currentView = 2),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pharmacyGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x3300AA44), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.store, color: Colors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Login as Pharmacy Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Manage stock, orders & dispatch', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Trust Badges Footnote
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping, size: 16, color: Color(0xFF047857)),
                SizedBox(width: 4),
                Text('Hyperlocal 30m SLA', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
            Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.health_and_safety, size: 16, color: Color(0xFF0066CC)),
                SizedBox(width: 4),
                Text('CDSCO Certified', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // VIEW 2: User Login
  Widget _buildUserLoginView() {
    return Column(
      key: const ValueKey('user_login'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _currentView = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.userBlueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Customer Portal',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.userBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('User Login', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Welcome back! Sign in to order verified generic medicines.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Demo Autofill Pill
        InkWell(
          onTap: _autofillUser,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.userBlueLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, size: 16, color: AppColors.userBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo Autofill: rahul.mehta@example.com (Tap)',
                    style: TextStyle(fontSize: 11, color: AppColors.userBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _userEmailController,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userPasswordController,
          obscureText: _obscureUserPassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureUserPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureUserPassword = !_obscureUserPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleUserLogin,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.userBlue),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Login to Customer Portal'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
              );
            },
            child: const Text('Skip & Browse Customer App ›'),
          ),
        ),
      ],
    );
  }

  // VIEW 3: Pharmacy Admin Login
  Widget _buildPharmacyLoginView() {
    return Column(
      key: const ValueKey('pharmacy_login'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _currentView = 0),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.pharmacyGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retailer Admin',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.pharmacyGreen),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Pharmacy Admin Login', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Access orders, drug stock, and dispatch management.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        // Demo Autofill Pill
        InkWell(
          onTap: _autofillPharmacy,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pharmacyGreenLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, size: 16, color: AppColors.pharmacyGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo Autofill: PH-88291 / chemist@apollomeds.com (Tap)',
                    style: TextStyle(fontSize: 11, color: AppColors.pharmacyGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _pharmacyIdController,
          decoration: const InputDecoration(
            labelText: 'Pharmacy Name / ID *',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pharmacyEmailController,
          decoration: const InputDecoration(
            labelText: 'Registered Chemist Email *',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pharmacyPasswordController,
          obscureText: _obscurePharmacyPassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePharmacyPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePharmacyPassword = !_obscurePharmacyPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePharmacyLogin,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacyGreen),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Login to Pharmacy Portal'),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('New pharmacy partner? ', style: TextStyle(fontSize: 12)),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PharmacyRegistrationScreen()),
                );
              },
              child: const Text(
                'Register Store ›',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.pharmacyGreen),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
