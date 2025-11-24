import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';
import '../vendor_setup/vendor_service.dart';

class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _description = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vendor = context.read<AppSession>().vendorProfile;
    if (vendor != null) {
      _name.text = vendor.businessName;
      _category.text = vendor.category;
      _address.text = vendor.address;
      _contact.text = vendor.phoneNumber ?? '';
      _email.text = vendor.email ?? '';
      _description.text = vendor.description ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _address.dispose();
    _contact.dispose();
    _email.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<AppSession>();
    final vendor = session.vendorProfile;
    if (vendor == null) return;
    setState(() => _saving = true);
    try {
      final updated = vendor.copyWith(
        businessName: _name.text.trim(),
        category: _category.text.trim(),
        address: _address.text.trim(),
        phoneNumber: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      );
      await VendorService().saveVendorProfile(updated);
      await session.reloadVendorProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business details updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Business Name *', prefixIcon: Icon(Icons.business)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on)),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(labelText: 'Contact', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
