import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<_FaqItem> _faqs = const [
    _FaqItem('How do I book a vendor?', 'Browse categories, open a service and tap “Book Now”. Complete the checkout flow to confirm.'),
    _FaqItem('Can I reschedule a booking?', 'Yes. Open your booking in Orders and choose reschedule. The vendor will confirm the new slot.'),
    _FaqItem('Where can I download my invoice?', 'Invoices are available inside each order detail screen once payment is confirmed.'),
  ];

  final GlobalKey<FormState> _issueFormKey = GlobalKey<FormState>();
  final TextEditingController _issueDescriptionController = TextEditingController();
  String _issueType = 'vendor';
  File? _issueAttachment;
  bool _submittingIssue = false;

  final GlobalKey<FormState> _feedbackFormKey = GlobalKey<FormState>();
  final TextEditingController _feedbackCommentController = TextEditingController();
  double _feedbackRating = 4;
  bool _submittingFeedback = false;

  @override
  void dispose() {
    _issueDescriptionController.dispose();
    _feedbackCommentController.dispose();
    super.dispose();
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
      await Supabase.instance.client.functions.invoke('user-report-issue', body: {
        'type': _issueType,
        'description': _issueDescriptionController.text.trim(),
        if (_issueAttachment != null) 'hasAttachment': true,
        if (userId != null) 'user_id': userId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue submitted. Our support team will contact you soon.')),
      );
      _issueFormKey.currentState!.reset();
      _issueDescriptionController.clear();
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

  Future<void> _submitFeedback() async {
    if (!_feedbackFormKey.currentState!.validate()) return;
    setState(() => _submittingFeedback = true);
    try {
      await Supabase.instance.client.functions.invoke('user-feedback', body: {
        'rating': _feedbackRating,
        'comment': _feedbackCommentController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for sharing your feedback!')),
      );
      _feedbackFormKey.currentState!.reset();
      _feedbackCommentController.clear();
      setState(() => _feedbackRating = 4);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
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
          const SizedBox(height: 24),
          _buildFeedbackSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionPanelList.radio(
        initialOpenPanelValue: 0,
        expandedHeaderPadding: EdgeInsets.zero,
        children: _faqs
            .asMap()
            .entries
            .map((entry) => ExpansionPanelRadio(
                  value: entry.key,
                  headerBuilder: (context, isExpanded) => ListTile(
                    title: Text(entry.value.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(entry.value.answer),
                  ),
                ))
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
                onChanged: (value) => setState(() => _issueType = value ?? 'vendor'),
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

  Widget _buildFeedbackSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _feedbackFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Rate your experience:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _feedbackRating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _feedbackRating.toStringAsFixed(1),
                      onChanged: (value) => setState(() => _feedbackRating = value),
                    ),
                  ),
                  Text(_feedbackRating.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feedbackCommentController,
                decoration: const InputDecoration(
                  labelText: 'Tell us more',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please add a short comment';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submittingFeedback ? null : _submitFeedback,
                  child: _submittingFeedback
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('About Saral Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'Saral Events connects you with trusted vendors to plan weddings, celebrations and corporate events seamlessly. Discover curated services, manage invitations and track bookings in one place.',
            ),
            SizedBox(height: 16),
            Text('Support contacts', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Email: support@saralevents.com'),
            Text('Phone: +91 98765 43210'),
            Text('Address: Plot 10, Hitech City, Hyderabad, Telangana'),
            SizedBox(height: 16),
            Text('Policies', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('• Terms of Service'),
            Text('• Privacy Policy'),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}
