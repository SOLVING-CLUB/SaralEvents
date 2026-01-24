import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/faq_service.dart';
import '../../core/state/session.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final FAQService _faqService = FAQService(Supabase.instance.client);
  List<FAQ> _faqs = [];
  bool _loadingFAQs = true;
  String? _faqError;
  int? _expandedFaqIndex;

  final GlobalKey<FormState> _issueFormKey = GlobalKey<FormState>();
  final TextEditingController _issueDescriptionController = TextEditingController();
  final TextEditingController _orderIdController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  String _issueType = 'general';
  File? _issueAttachment;
  bool _submittingIssue = false;
  String? _contactNumber;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    _loadVendorContactNumber();
  }

  Future<void> _loadVendorContactNumber() async {
    try {
      final vendorProfile = Provider.of<AppSession>(context, listen: false).vendorProfile;
      if (vendorProfile != null && vendorProfile.phoneNumber != null) {
        setState(() {
          _contactNumber = vendorProfile.phoneNumber;
          _contactNumberController.text = _contactNumber ?? '';
        });
      }
    } catch (e) {
      // Silently fail - vendor can enter manually
    }
  }

  @override
  void dispose() {
    _issueDescriptionController.dispose();
    _orderIdController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // Check if order ID is required based on issue type
  bool _isOrderIdRequired() {
    // Order ID is required for order-related issues: payment, booking
    return _issueType == 'payment' || _issueType == 'booking';
  }

  // Validate UUID format (8-4-4-4-12 hexadecimal characters)
  String? _validateOrderId(String? value) {
    final trimmed = value?.trim() ?? '';
    
    // Check if order ID is required for this issue type
    if (_isOrderIdRequired()) {
      if (trimmed.isEmpty) {
        return 'Order ID is required for ${_issueType == 'payment' ? 'payment' : 'booking'} related issues';
      }
    } else {
      // If not required, allow empty
      if (trimmed.isEmpty) {
        return null;
      }
    }
    
    // Validate UUID format if provided
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidPattern.hasMatch(trimmed)) {
      return 'Please enter a valid Order ID format (e.g., 550e8400-e29b-41d4-a716-446655440000)';
    }
    return null;
  }

  Future<void> _loadFAQs() async {
    setState(() {
      _loadingFAQs = true;
      _faqError = null;
    });

    try {
      final faqs = await _faqService.getFAQs();
      if (mounted) {
        setState(() {
          _faqs = faqs;
          _loadingFAQs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _faqError = e.toString();
          _loadingFAQs = false;
        });
      }
    }
  }

  Future<void> _pickIssueImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
    if (result != null) {
      setState(() => _issueAttachment = File(result.path));
    }
  }

  Future<void> _submitIssue() async {
    if (!_issueFormKey.currentState!.validate()) return;
    setState(() => _submittingIssue = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final vendorProfile = Provider.of<AppSession>(context, listen: false).vendorProfile;
      final vendorId = vendorProfile?.id;
      
      // Prepare ticket data
      final ticketData = {
        'user_id': userId,
        'vendor_id': vendorId,
        'subject': 'Vendor Support Request: ${_issueType}',
        'message': _issueDescriptionController.text.trim(),
        'category': _issueType == 'payment' ? 'Payment/Refund' : 
                   _issueType == 'booking' ? 'Booking Issue' :
                   _issueType == 'technical' ? 'Technical Issue' : 'General Inquiry',
        'status': 'open',
        'priority': 'medium',
      };

      // Add order_id if provided
      final orderId = _orderIdController.text.trim();
      if (orderId.isNotEmpty) {
        ticketData['order_id'] = orderId;
      }

      // Add contact_number if provided
      final contactNumber = _contactNumberController.text.trim();
      if (contactNumber.isNotEmpty) {
        ticketData['contact_number'] = contactNumber;
      }

      await Supabase.instance.client
          .from('support_tickets')
          .insert(ticketData);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue submitted. Our support team will contact you soon.')),
      );
      _issueFormKey.currentState!.reset();
      _issueDescriptionController.clear();
      _orderIdController.clear();
      // Keep contact number as it's from profile
      setState(() => _issueAttachment = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit issue: $e')),
      );
    } finally {
      if (mounted) setState(() => _submittingIssue = false);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:+917731842453');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  Future<void> _launchEmail() async {
    final email = 'eventssaral@gmail.com';
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
    }
  }

  Future<void> _launchWebsite() async {
    final uri = Uri.parse('https://saralevents.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open website')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildContactSection(),
          const SizedBox(height: 24),
          _buildFaqSection(),
          const SizedBox(height: 24),
          _buildIssueSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              icon: Icons.phone,
              title: 'Phone',
              subtitle: '+91 77318 42453',
              onTap: _launchPhone,
              color: Colors.green,
            ),
            const Divider(height: 24),
            _buildContactItem(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'eventssaral@gmail.com',
              onTap: _launchEmail,
              color: Colors.blue,
            ),
            const Divider(height: 24),
            _buildContactItem(
              icon: Icons.language,
              title: 'Website',
              subtitle: 'saralevents.com',
              onTap: _launchWebsite,
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    if (_loadingFAQs) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_faqError != null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load FAQs: $_faqError'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFAQs,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_faqs.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No FAQs available at the moment.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionPanelList.radio(
        expandedHeaderPadding: EdgeInsets.zero,
        children: _faqs
            .asMap()
            .entries
            .map((entry) {
              final faq = entry.value;
              final index = entry.key;
              return ExpansionPanelRadio(
                value: index,
                headerBuilder: (context, isExpanded) {
                  if (isExpanded && _expandedFaqIndex != index) {
                    // Increment view count when FAQ is expanded
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _faqService.incrementViewCount(faq.id);
                      setState(() => _expandedFaqIndex = index);
                    });
                  }
                  return ListTile(
                    title: Text(
                      faq.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: faq.category != 'General'
                        ? Text(
                            faq.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(faq.answer),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await _faqService.markAsHelpful(faq.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Thank you for your feedback!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  _loadFAQs(); // Refresh to update counts
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to submit feedback: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.thumb_up, size: 18),
                            label: const Text('Helpful'),
                            style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await _faqService.markAsNotHelpful(faq.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Thank you for your feedback!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  _loadFAQs(); // Refresh to update counts
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to submit feedback: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.thumb_down, size: 18),
                            label: const Text('Not helpful'),
                            style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildIssueSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _issueFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Report an issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _issueType,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General inquiry')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment issue')),
                  DropdownMenuItem(value: 'booking', child: Text('Booking issue')),
                  DropdownMenuItem(value: 'technical', child: Text('Technical issue')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => _issueType = value ?? 'general');
                  // Re-validate order ID field when issue type changes
                  _issueFormKey.currentState?.validate();
                },
              ),
              const SizedBox(height: 12),
              // Contact Number
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  hintText: 'Your contact number for support',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return 'Please enter a valid phone number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Order ID
              TextFormField(
                controller: _orderIdController,
                decoration: InputDecoration(
                  labelText: _isOrderIdRequired() ? 'Order ID *' : 'Order ID (Optional)',
                  hintText: _isOrderIdRequired()
                      ? 'Enter Order ID (required for ${_issueType == 'payment' ? 'payment' : 'booking'} issues)'
                      : 'Enter Order ID if related to an order',
                  prefixIcon: const Icon(Icons.receipt_long),
                ),
                validator: _validateOrderId,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _issueDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickIssueImage,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_issueAttachment == null ? 'Attach screenshot (optional)' : 'Change attachment'),
                  ),
                  const SizedBox(width: 12),
                  if (_issueAttachment != null)
                    Expanded(
                      child: Text(
                        _issueAttachment!.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submittingIssue ? null : _submitIssue,
                  child: _submittingIssue
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit issue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
