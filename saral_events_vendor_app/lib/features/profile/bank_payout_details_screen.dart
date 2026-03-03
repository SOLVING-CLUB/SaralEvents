import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';
import '../vendor_setup/vendor_service.dart';

class BankPayoutDetailsScreen extends StatefulWidget {
  const BankPayoutDetailsScreen({super.key});

  @override
  State<BankPayoutDetailsScreen> createState() => _BankPayoutDetailsScreenState();
}

class _BankPayoutDetailsScreenState extends State<BankPayoutDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _settlementCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppSession>().vendorProfile;
    if (profile != null) {
      _accountHolderCtrl.text = profile.accountHolderName ?? '';
      _accountNumberCtrl.text = profile.accountNumber ?? '';
      _upiCtrl.text = profile.upiId ?? '';
      _ifscCtrl.text = profile.ifscCode ?? '';
      _settlementCtrl.text = profile.settlementCycle ?? 'Monthly (First week)';
    }
  }

  @override
  void dispose() {
    _accountHolderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _upiCtrl.dispose();
    _ifscCtrl.dispose();
    _settlementCtrl.dispose();
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
        accountHolderName: _accountHolderCtrl.text.trim(),
        accountNumber: _accountNumberCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        settlementCycle: _settlementCtrl.text.trim(),
      );

      await VendorService().saveVendorProfile(updated);
      await session.reloadVendorProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details updated')),
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
        title: const Text('Bank & Payouts'),
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
            Text('Manage your settlement bank and UPI details.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _accountHolderCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Bank Account Number',
                hintText: 'e.g. 1234567890',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
             TextFormField(
              controller: _upiCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'e.g. name@upi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ifscCtrl,
              decoration: const InputDecoration(
                labelText: 'IFSC Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _settlementCtrl,
              decoration: const InputDecoration(
                labelText: 'Settlement Cycle Info',
                hintText: 'e.g. Monthly, Weekly',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
