import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _categoryController = TextEditingController();
  final _orderIdController = TextEditingController();
  final _contactNumberController = TextEditingController();
  
  bool _isSubmitting = false;
  String? _selectedCategory;
  String? _contactNumber; // Will be loaded from user profile or can be entered manually

  final List<String> _categories = [
    'Booking Issue',
    'Payment/Refund',
    'Cancellation',
    'Technical Issue',
    'General Inquiry',
    'Complaint',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
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
    _subjectController.dispose();
    _messageController.dispose();
    _categoryController.dispose();
    _orderIdController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // Validate UUID format (8-4-4-4-12 hexadecimal characters)
  String? _validateOrderId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Order ID is optional
    }
    final trimmed = value.trim();
    // UUID format: 8-4-4-4-12 hexadecimal characters
    final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidPattern.hasMatch(trimmed)) {
      return 'Please enter a valid Order ID format (e.g., 550e8400-e29b-41d4-a716-446655440000)';
    }
    return null;
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Prepare ticket data
      final ticketData = {
        'user_id': userId,
        'category': _selectedCategory,
        'subject': _subjectController.text,
        'message': _messageController.text,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _subjectController.clear();
        _messageController.clear();
        _categoryController.clear();
        _orderIdController.clear();
        // Keep contact number as it's from profile
        setState(() {
          _selectedCategory = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _launchEmail() async {
    final email = 'support@saralevents.com';
    final subject = Uri.encodeComponent('Support Request - Saral Events');
    final body = Uri.encodeComponent('Hello,\n\nI need assistance with:\n\n');
    
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    
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

  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:+911234567890');
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

  Future<void> _launchWhatsApp() async {
    final phone = '911234567890';
    final message = Uri.encodeComponent('Hello, I need support for Saral Events');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Contact Cards
            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.phone,
                    title: 'Call Us',
                    subtitle: '+91 1234567890',
                    color: Colors.green,
                    onTap: _launchPhone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.email,
                    title: 'Email',
                    subtitle: 'support@saralevents.com',
                    color: Colors.blue,
                    onTap: _launchEmail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildContactCard(
                icon: Icons.chat,
                title: 'WhatsApp',
                subtitle: 'Chat with us',
                color: Colors.green.shade700,
                onTap: _launchWhatsApp,
              ),
            ),

            const SizedBox(height: 32),

            // Support Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit Support Request',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _categoryController.text = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Contact Number
                      TextFormField(
                        controller: _contactNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                          hintText: 'Your contact number for support',
                          border: OutlineInputBorder(),
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

                      const SizedBox(height: 16),

                      // Order ID
                      TextFormField(
                        controller: _orderIdController,
                        decoration: const InputDecoration(
                          labelText: 'Order ID (Optional)',
                          hintText: 'Enter Order ID if related to an order',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                        validator: _validateOrderId,
                      ),

                      const SizedBox(height: 16),

                      // Subject
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subject),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a subject';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Message
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.message),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your message';
                          }
                          if (value.length < 10) {
                            return 'Message must be at least 10 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitSupportRequest,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // FAQ Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequently Asked Questions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildFAQItem(
                      'How do I cancel a booking?',
                      'Go to Orders, select your booking, and tap Cancel. You\'ll see the refund preview before confirming.',
                    ),
                    const Divider(),
                    _buildFAQItem(
                      'When will I receive my refund?',
                      'Refunds are processed within 5-7 business days after cancellation approval.',
                    ),
                    const Divider(),
                    _buildFAQItem(
                      'What is the refund policy?',
                      'Refund policies vary by category. Check the refund preview when cancelling to see your specific refund amount.',
                    ),
                    const Divider(),
                    _buildFAQItem(
                      'How do I track my refund?',
                      'Go to Orders, select the cancelled booking, and tap View Refund Details.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            answer,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

