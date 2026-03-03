import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';
import '../vendor_setup/vendor_service.dart';

class PricingPoliciesScreen extends StatefulWidget {
  const PricingPoliciesScreen({super.key});

  @override
  State<PricingPoliciesScreen> createState() => _PricingPoliciesScreenState();
}

class _PricingPoliciesScreenState extends State<PricingPoliciesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _advanceCtrl = TextEditingController();
  final _cancellationCtrl = TextEditingController();
  final _refundCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppSession>().vendorProfile;
    if (profile != null) {
      _advanceCtrl.text = profile.advancePaymentPercentage ?? '50%';
      _cancellationCtrl.text = profile.cancellationPolicy ?? 'Cancellation before 48 hours: Full refund minus service fee.';
      _refundCtrl.text = profile.refundRules ?? 'Processed within 7 business days.';
    }
  }

  @override
  void dispose() {
    _advanceCtrl.dispose();
    _cancellationCtrl.dispose();
    _refundCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final session = context.read<AppSession>();
      final profile = session.vendorProfile;
      if (profile == null) return;

      final updated = profile.copyWith(
        advancePaymentPercentage: _advanceCtrl.text.trim(),
        cancellationPolicy: _cancellationCtrl.text.trim(),
        refundRules: _refundCtrl.text.trim(),
      );

      await VendorService().saveVendorProfile(updated);
      await session.reloadVendorProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing & policies updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing & Policies'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Set clear booking and refund expectations.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _advanceCtrl,
              decoration: const InputDecoration(
                labelText: 'Advance Payment Percentage',
                hintText: 'e.g. 50%',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cancellationCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Cancellation Policy',
                hintText: 'Details about when and how to cancel...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refundCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Refund Rules',
                hintText: 'Details about processing time, etc.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
