import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Screen 11: Pharmacy Self-Delivery & Runner Dispatch Management
class PharmacySelfDeliveryScreen extends StatefulWidget {
  const PharmacySelfDeliveryScreen({super.key});

  @override
  State<PharmacySelfDeliveryScreen> createState() => _PharmacySelfDeliveryScreenState();
}

class _PharmacySelfDeliveryScreenState extends State<PharmacySelfDeliveryScreen> {
  int _orderStatusStep = 2; // 1: Received, 2: Preparing/Packing, 3: Handover to Runner, 4: Out for Delivery, 5: Delivered

  void _advanceOrderStatus() {
    setState(() {
      if (_orderStatusStep < 5) {
        _orderStatusStep++;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order status updated to: ${_getStatusText()}'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  String _getStatusText() {
    switch (_orderStatusStep) {
      case 1:
        return 'Order Received';
      case 2:
        return 'Preparing & Packing';
      case 3:
        return 'Handed to Runner';
      case 4:
        return 'Out for Delivery';
      case 5:
        return 'Delivered & Confirmed';
      default:
        return 'Active';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Flexible(
                  child: Text(
                    'Delivery › #GM-89421',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Fleet Runner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Text(
              'Pharmacist: Dr. Anand Kulkarni (Pharm.D)',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP ORDER BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Order #GM-89421',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryFixed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.ac_unit, size: 12, color: AppColors.tertiary),
                            SizedBox(width: 3),
                            Text('Cold-Chain (2-8°C)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onTertiaryFixed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Placed at 02:14 PM (18 mins ago) • Distance: 1.2 km (Baner High St)',
                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                  const SizedBox(height: 16),

                  // Order Lifecycle Stepper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStep(1, 'Received', _orderStatusStep >= 1),
                      _buildMiniConnector(_orderStatusStep > 1),
                      _buildMiniStep(2, 'Packing', _orderStatusStep >= 2),
                      _buildMiniConnector(_orderStatusStep > 2),
                      _buildMiniStep(3, 'Handover', _orderStatusStep >= 3),
                      _buildMiniConnector(_orderStatusStep > 3),
                      _buildMiniStep(4, 'Out for Delivery', _orderStatusStep >= 4),
                      _buildMiniConnector(_orderStatusStep > 4),
                      _buildMiniStep(5, 'Delivered', _orderStatusStep >= 5),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ASSIGNED STORE RUNNER CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Store Runner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryFixed,
                        child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ramesh Pawar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text('Fleet ID: FL-04 • Two-Wheeler • Insulated Box', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                            Text('Rating 4.9 (420+ store deliveries)', style: TextStyle(fontSize: 11, color: AppColors.tertiary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Runner Ramesh (+91 98220 98765)')),
                          );
                        },
                        icon: const Icon(Icons.call, size: 20),
                        tooltip: 'Call Runner',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // CUSTOMER DESTINATION CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Destination & Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aniket Mehta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Flat 402, Green Glen Apts, Baner High Street, Pune 411045', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 2),
                            Text('Phone: +91 98230 44129 (Customer Verified)', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Customer Aniket (+91 98230 44129)')),
                          );
                        },
                        icon: const Icon(Icons.call, size: 20),
                        tooltip: 'Call Customer',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ORDER PACKING CHECKLIST
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prescription Verification & Pack Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildChecklistItem(
                    title: 'Paracetamol IP 650mg (Genext) - 2 Strips',
                    batch: 'Batch: GN-2024-88 • Exp: 10/26 • MRP: ₹58.50',
                    selling: 'Selling: ₹18.00 (Customer Saved 69%)',
                    isChecked: true,
                  ),
                  const Divider(height: 16),
                  _buildChecklistItem(
                    title: 'Cetirizine 10mg IP (Cipla) - 1 Strip',
                    batch: 'Batch: CP-9921 • Exp: 04/27 • MRP: ₹35.00',
                    selling: 'Selling: ₹12.50 (Customer Saved 64%)',
                    isChecked: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.surfaceContainer, width: 1)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _orderStatusStep < 5 ? _advanceOrderStatus : null,
            child: Text(
              _orderStatusStep == 2
                  ? 'Handover to Runner Ramesh'
                  : (_orderStatusStep == 3
                      ? 'Mark Out for Delivery'
                      : (_orderStatusStep == 4 ? 'Confirm Order Delivered (Verify OTP)' : 'Order Completed')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStep(int step, String label, bool isDone) {
    return SizedBox(
      width: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isDone ? AppColors.primary : AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : Text('$step', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
              color: isDone ? AppColors.primary : AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniConnector(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12),
        color: isDone ? AppColors.primary : AppColors.surfaceContainerHigh,
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String batch,
    required String selling,
    required bool isChecked,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(isChecked ? Icons.check_circle : Icons.radio_button_unchecked, color: AppColors.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              Text(batch, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              Text(selling, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
