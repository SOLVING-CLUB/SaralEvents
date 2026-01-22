import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/faq_service.dart';

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
  String _issueType = 'vendor';
  File? _issueAttachment;
  bool _submittingIssue = false;
  String? _contactNumber;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    _loadUserContactNumber();
  }

  Future<void> _loadUserContactNumber() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final response = await Supabase.instance.client
            .from('user_profiles')
            .select('phone_number')
            .eq('user_id', userId)
            .maybeSingle();
        
        if (mounted && response != null && response['phone_number'] != null) {
          setState(() {
            _contactNumber = response['phone_number'] as String?;
            _contactNumberController.text = _contactNumber ?? '';
          });
        }
      }
    } catch (e) {
      // Silently fail - user can enter manually
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
    // Order ID is required for order-related issues: vendor, service, payment
    return _issueType == 'vendor' || _issueType == 'service' || _issueType == 'payment';
  }

  // Validate UUID format (8-4-4-4-12 hexadecimal characters)
  String? _validateOrderId(String? value) {
    final trimmed = value?.trim() ?? '';
    
    // Check if order ID is required for this issue type
    if (_isOrderIdRequired()) {
      if (trimmed.isEmpty) {
        return 'Order ID is required for ${_issueType == 'vendor' ? 'vendor' : _issueType == 'service' ? 'service' : 'payment'} related issues';
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
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Map issue type to category
      String category = 'General Inquiry';
      switch (_issueType) {
        case 'payment':
          category = 'Payment/Refund';
          break;
        case 'vendor':
        case 'service':
          category = 'Complaint';
          break;
        case 'other':
          category = 'Other';
          break;
      }

      // Prepare ticket data
      final ticketData = {
        'user_id': userId,
        'subject': 'Issue Report: ${_issueType}',
        'message': _issueDescriptionController.text.trim(),
        'category': category,
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

      // Create support ticket
      await Supabase.instance.client.from('support_tickets').insert(ticketData);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFaqSection(),
          const SizedBox(height: 24),
          _buildIssueSection(),
          const SizedBox(height: 32),
        ],
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
                  DropdownMenuItem(value: 'vendor', child: Text('Vendor misconduct')),
                  DropdownMenuItem(value: 'service', child: Text('Service issue')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment issue')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() => _issueType = value ?? 'vendor');
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
                      ? 'Enter Order ID (required for ${_issueType == 'vendor' ? 'vendor' : _issueType == 'service' ? 'service' : 'payment'} issues)'
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

