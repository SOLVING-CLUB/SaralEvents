import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_theme.dart';
import 'vendor_service.dart';
import 'vendor_models.dart';

class ApprovalPendingScreen extends StatefulWidget {
  const ApprovalPendingScreen({super.key});

  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  final VendorService _vendorService = VendorService();
  List<VendorDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final session = context.read<AppSession>();
    final vendor = session.vendorProfile;
    if (vendor?.id == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final docs = await _vendorService.getVendorDocuments(vendor!.id!);
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading documents: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _viewDocument(VendorDocument doc) async {
    final url = Uri.parse(doc.fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open document')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await context.read<AppSession>().reloadVendorProfile();
    await _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final vendor = session.vendorProfile;
    
    // If vendor is approved, redirect to app
    if (vendor?.approvalStatus == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/app');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Account Verification'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 64,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Documents Under Verification',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Thank you for submitting your vendor details and documents.'
                              '\n\nOur team is reviewing your account. This usually takes between 2–7 business days.'
                              '\n\nYou will receive a notification once your account is approved.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (vendor?.approvalStatus == 'rejected' && vendor?.approvalNotes != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Rejection Reason',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      vendor!.approvalNotes!,
                                      style: TextStyle(color: Colors.red.shade800),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Business Details Section
                    if (vendor != null) ...[
                      Text(
                        'Business Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Business Name', vendor.businessName),
                              if (vendor.vendorName != null)
                                _buildDetailRow('Vendor/Owner Name', vendor.vendorName!),
                              _buildDetailRow('Category', vendor.category),
                              _buildDetailRow('Address', vendor.address),
                              if (vendor.phoneNumber != null)
                                _buildDetailRow('Contact', vendor.phoneNumber!),
                              if (vendor.email != null)
                                _buildDetailRow('Email', vendor.email!),
                              if (vendor.gstNumber != null)
                                _buildDetailRow('GST Number', vendor.gstNumber!),
                              if (vendor.panNumber != null)
                                _buildDetailRow('PAN Number', vendor.panNumber!),
                              if (vendor.aadhaarNumber != null)
                                _buildDetailRow('Aadhaar Number', vendor.aadhaarNumber!),
                              if (vendor.accountHolderName != null) ...[
                                const Divider(height: 24),
                                Text(
                                  'Bank Details',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow('Account Holder', vendor.accountHolderName!),
                                if (vendor.accountNumber != null)
                                  _buildDetailRow('Account Number', vendor.accountNumber!),
                                if (vendor.ifscCode != null)
                                  _buildDetailRow('IFSC Code', vendor.ifscCode!),
                                if (vendor.bankName != null)
                                  _buildDetailRow('Bank Name', vendor.bankName!),
                                if (vendor.branchName != null)
                                  _buildDetailRow('Branch Name', vendor.branchName!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Documents Section
                    Text(
                      'Uploaded Documents',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_documents.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No documents uploaded yet',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._documents.map((doc) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                doc.fileUrl.toLowerCase().endsWith('.pdf')
                                    ? Icons.picture_as_pdf
                                    : Icons.image,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                doc.documentType,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                doc.fileName,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () => _viewDocument(doc),
                                tooltip: 'View Document',
                              ),
                            ),
                          )),
                    const SizedBox(height: 24),

                    // Action Buttons
                    FilledButton.icon(
                      onPressed: () {
                        context.read<AppSession>().signOut();
                        context.go('/auth/pre');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
