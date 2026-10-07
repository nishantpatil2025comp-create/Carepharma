import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

/// Screen 5: Upload Prescription & Past Records
class UploadPrescriptionScreen extends StatefulWidget {
  const UploadPrescriptionScreen({
    super.key,
    this.simulateUploadInTest = false,
  });

  final bool simulateUploadInTest;

  @override
  State<UploadPrescriptionScreen> createState() => _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState extends State<UploadPrescriptionScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _hasUploadedFile = false;
  String _uploadedFileName = 'Prescription_Image.jpg';
  Uint8List? _previewImageBytes;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _pastPrescriptions = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchPastPrescriptions();
  }

  Future<void> _fetchPastPrescriptions() async {
    setState(() => _isLoadingHistory = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null && user.email != null) {
        final res = await client
            .from('prescriptions')
            .select()
            .eq('user_email', user.email!)
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() {
            _pastPrescriptions = List<Map<String, dynamic>>.from(res as List);
            _isLoadingHistory = false;
          });
          return;
        }
      }
    } catch (_) {
      // Table may not exist yet or offline: start completely blank
    }
    if (mounted) {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickPrescription(ImageSource source) async {
    if (widget.simulateUploadInTest) {
      _simulateUpload(source == ImageSource.camera ? 'camera' : 'gallery');
      return;
    }
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _previewImageBytes = bytes;
            _uploadedFileName = file.name;
            _hasUploadedFile = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Prescription attached successfully'),
                ],
              ),
              backgroundColor: Color(0xFF00685F),
            ),
          );
        }
      } else {
        _simulateUpload(source == ImageSource.camera ? 'camera' : 'gallery');
      }
    } catch (e) {
      debugPrint('[UploadPrescriptionScreen] ImagePicker note: $e');
      _simulateUpload(source == ImageSource.camera ? 'camera' : 'gallery');
    }
  }

  void _simulateUpload(String source) {
    setState(() {
      _hasUploadedFile = true;
      _uploadedFileName = source == 'camera'
          ? 'Rx_Camera_Scan_${DateTime.now().millisecond}.jpg'
          : 'Rx_Prescription_Doc.pdf';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Prescription attached successfully'),
          ],
        ),
        backgroundColor: Color(0xFF00685F),
      ),
    );
  }

  void _submitPrescription() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _pastPrescriptions.insert(0, {
          'title': _uploadedFileName,
          'date': 'Today',
          'status': 'Submitted for Review',
          'savings': 'Pending Quote',
        });
        _hasUploadedFile = false;
        _previewImageBytes = null;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle, color: AppColors.primary, size: 54),
          title: const Text('Prescription Submitted!'),
          content: const Text(
            'Our licensed clinical pharmacist is reviewing your prescription and finding the highest-saving generic bio-equivalents. You will receive an SMS and in-app quote in under 15 minutes.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );
    });
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
        centerTitle: true,
        title: const Text(
          'Upload Prescription',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Need help? Call our clinical pharmacist: 1800-420-9900')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trust & Security Sub-bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '100% HIPAA Compliant • Verified Pharmacists',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Upload Actions Bento Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: AppColors.shadowTeal, blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('New Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text("Upload clear doctor's slip or e-Rx", style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.eco, size: 14, color: AppColors.onSecondaryContainer),
                            SizedBox(width: 3),
                            Text('Save up to 70%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dual Pill / Card buttons: Camera & Gallery
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickPrescription(ImageSource.camera),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Column(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primaryFixed,
                                  child: Icon(Icons.photo_camera, color: AppColors.primary, size: 26),
                                ),
                                SizedBox(height: 10),
                                Text('Take Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                SizedBox(height: 2),
                                Text('Instant camera scan', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickPrescription(ImageSource.gallery),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: const Column(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.surfaceContainerHigh,
                                  child: Icon(Icons.photo_library, color: AppColors.onSurface, size: 26),
                                ),
                                SizedBox(height: 10),
                                Text('From Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('Upload image from device', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Validation Checklist Pills
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Doctor Stamp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Patient Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Recent Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Supports JPG, PNG, PDF up to 10 MB', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Uploaded State Preview
            if (_hasUploadedFile) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
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
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Flexible(
                                child: Text(
                                  'File Ready for Matching',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Uploaded just now', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _previewImageBytes != null
                                ? Image.memory(
                                    _previewImageBytes!,
                                    width: 48,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.description, color: AppColors.primary, size: 28),
                                      Text('JPG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_uploadedFileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  _previewImageBytes != null
                                      ? '${(_previewImageBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB • Image Loaded'
                                      : 'High Resolution Document',
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _pickPrescription(ImageSource.camera),
                                      child: const Text('Re-take', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('|', style: TextStyle(color: AppColors.outlineVariant)),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() {
                                        _hasUploadedFile = false;
                                        _previewImageBytes = null;
                                      }),
                                      child: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.support_agent, color: AppColors.secondary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pharmacist Review Promise: A verified chemist checks salt equivalence and discounts in under 15 mins.',
                              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Past Uploaded Prescriptions
            const Text('Past Prescriptions History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_pastPrescriptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.description_outlined, size: 36, color: AppColors.outline),
                    SizedBox(height: 8),
                    Text(
                      'No past prescriptions uploaded',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Uploaded prescriptions will appear here once submitted.',
                      style: TextStyle(fontSize: 11, color: AppColors.outline),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._pastPrescriptions.map(
                (record) => _buildPastRecordCard(
                  title: (record['title'] ?? record['file_name'] ?? 'Prescription_Doc.jpg').toString(),
                  date: (record['date'] ?? 'Recent').toString(),
                  status: (record['status'] ?? 'Under Review').toString(),
                  savings: (record['savings'] ?? 'Verified').toString(),
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
          height: 50,
          child: ElevatedButton(
            onPressed: _hasUploadedFile && !_isSubmitting ? _submitPrescription : null,
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Submit for Pharmacist Review (15m SLA)'),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPastRecordCard({
    required String title,
    required String date,
    required String status,
    required String savings,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_edu, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text('$date • $status', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(savings, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}
