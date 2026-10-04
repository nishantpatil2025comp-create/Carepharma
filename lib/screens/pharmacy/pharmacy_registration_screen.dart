import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'pharmacy_dashboard_screen.dart';

/// Screen 8: Pharmacy Partner Registration & 4-Step Onboarding
class PharmacyRegistrationScreen extends StatefulWidget {
  const PharmacyRegistrationScreen({super.key});

  @override
  State<PharmacyRegistrationScreen> createState() => _PharmacyRegistrationScreenState();
}

class _PharmacyRegistrationScreenState extends State<PharmacyRegistrationScreen> {
  int _currentStep = 2; // Step 1: Basic Info, 2: Verification, 3: Operations, 4: Payout

  // Form Controllers
  final _pharmacyNameController = TextEditingController(text: 'Apollo Meds & Wellness');
  final _phoneController = TextEditingController(text: '+91 98220 44556');
  final _emailController = TextEditingController(text: 'chemist@apollomeds.com');
  final _licenseController = TextEditingController(text: 'MH-PUN-2024-8891');
  final _gstinController = TextEditingController(text: '27AABCA1234F1Z5');
  final _pharmacistRegController = TextEditingController(text: 'MH-PH-88921');
  final _deliveryRadiusController = TextEditingController(text: '3.5 km');
  final _runnerCountController = TextEditingController(text: '2 dedicated runners');
  final _bankAccountController = TextEditingController(text: '50100492817263');
  final _ifscController = TextEditingController(text: 'HDFC0001234');

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _gstinController.dispose();
    _pharmacistRegController.dispose();
    _deliveryRadiusController.dispose();
    _runnerCountController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      // Completed registration
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle, color: AppColors.pharmacyGreen, size: 54),
          title: const Text('Partner Application Submitted!'),
          content: const Text(
            'Your pharmacy documents have been received. We will verify Form 20/21 within 24 hours. You can now explore your partner dashboard.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PharmacyDashboardScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.pharmacyGreen),
              child: const Text('Enter Pharmacy Dashboard'),
            ),
          ],
        ),
      );
    }
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
        title: const Text('Pharmacy Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save & Exit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stepper Navigation Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowTeal, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                '$_currentStep',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getStepTitle(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_currentStep * 25)}% Completed',
                        style: const TextStyle(fontSize: 12, color: AppColors.outline, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _currentStep / 4.0,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 4 Interactive Step Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildStepTab(1, 'Basic Info', Icons.check)),
                      Expanded(child: _buildStepTab(2, 'Verification', Icons.verified_user)),
                      Expanded(child: _buildStepTab(3, 'Operations', Icons.local_shipping)),
                      Expanded(child: _buildStepTab(4, 'Payout', Icons.account_balance)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Reassurance / Promo Hero Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '0% COMMISSION • 60 DAYS PROMO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join 1,200+ neighborhood chemists boosting high-margin generic prescription orders.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 14, color: AppColors.secondaryContainer),
                          SizedBox(width: 4),
                          Text('24h fast approvals', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: AppColors.secondaryContainer),
                          SizedBox(width: 4),
                          Text('CDSCO compliant', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic Form Section based on _currentStep
            if (_currentStep == 1) _buildBasicInfoSection(),
            if (_currentStep == 2) _buildVerificationSection(),
            if (_currentStep == 3) _buildOperationsSection(),
            if (_currentStep == 4) _buildPayoutSection(),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.surfaceContainer, width: 1)),
        ),
        child: Row(
          children: [
            if (_currentStep > 1)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 1) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _nextStep,
                child: Text(_currentStep == 4 ? 'Submit Application' : 'Next Step ›'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Step 1 of 4 • Basic Identity';
      case 2:
        return 'Step 2 of 4 • Verification & Licenses';
      case 3:
        return 'Step 3 of 4 • Operations & Delivery';
      case 4:
        return 'Step 4 of 4 • Bank Payout Details';
      default:
        return '';
    }
  }

  Widget _buildStepTab(int step, String label, IconData icon) {
    final isDone = step < _currentStep;
    final isActive = step == _currentStep;

    return InkWell(
      onTap: () => setState(() => _currentStep = step),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.secondaryContainer
                  : (isActive ? AppColors.primary : AppColors.surfaceContainerHigh),
              shape: BoxShape.circle,
              border: isActive ? Border.all(color: AppColors.secondaryFixed, width: 3) : null,
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: isDone ? AppColors.onSecondaryContainer : (isActive ? Colors.white : AppColors.outline),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pharmacy Store Identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _pharmacyNameController,
            decoration: const InputDecoration(labelText: 'Registered Pharmacy Name *', prefixIcon: Icon(Icons.store)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Primary Business Phone *', prefixIcon: Icon(Icons.phone)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Store Email *', prefixIcon: Icon(Icons.email)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Drug Licenses & GST Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _licenseController,
            decoration: const InputDecoration(labelText: 'Form 20 / 21 Drug License No *', prefixIcon: Icon(Icons.badge)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gstinController,
            decoration: const InputDecoration(labelText: 'GSTIN Number *', prefixIcon: Icon(Icons.receipt)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pharmacistRegController,
            decoration: const InputDecoration(labelText: 'Head Pharmacist State Council Reg No *', prefixIcon: Icon(Icons.medical_services)),
          ),
          const SizedBox(height: 16),
          // Certificate Upload Pill
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant, style: BorderStyle.solid),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_upload, color: AppColors.primary, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Drug License Copy (PDF/JPG)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('License_2024_Form20.pdf (Uploaded)', style: TextStyle(fontSize: 11, color: AppColors.secondary)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: AppColors.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery & Fulfillment Operations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryRadiusController,
            decoration: const InputDecoration(labelText: 'Self-Delivery Coverage Radius *', prefixIcon: Icon(Icons.share_location)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _runnerCountController,
            decoration: const InputDecoration(labelText: 'In-Store Runners Fleet Size *', prefixIcon: Icon(Icons.two_wheeler)),
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.ac_unit, color: AppColors.primary),
            title: Text('Cold-Chain (2-8°C) Storage Equipped', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('Insulin & vaccines temperature monitoring', style: TextStyle(fontSize: 11)),
            trailing: Icon(Icons.check_box, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bank Account & Settlement Payout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _bankAccountController,
            decoration: const InputDecoration(labelText: 'Bank Account Number *', prefixIcon: Icon(Icons.account_balance)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ifscController,
            decoration: const InputDecoration(labelText: 'IFSC Code *', prefixIcon: Icon(Icons.pin)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Daily automated settlements via RTGS/NEFT with 0% platform fee for 60 days.',
            style: TextStyle(fontSize: 11, color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}
