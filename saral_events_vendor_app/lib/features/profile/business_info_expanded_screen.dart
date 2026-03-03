import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';
import '../vendor_setup/vendor_service.dart';

class BusinessInformationExpandedScreen extends StatefulWidget {
  const BusinessInformationExpandedScreen({super.key});

  @override
  State<BusinessInformationExpandedScreen> createState() => _BusinessInformationExpandedScreenState();
}

class _BusinessInformationExpandedScreenState extends State<BusinessInformationExpandedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _teamSizeCtrl = TextEditingController();
  final _locationsCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppSession>().vendorProfile;
    if (profile != null) {
      _descriptionCtrl.text = profile.description ?? '';
      _experienceCtrl.text = profile.yearsOfExperience ?? '';
      _teamSizeCtrl.text = profile.teamSize ?? '';
      _locationsCtrl.text = profile.serviceLocations?.join(', ') ?? '';
      _languagesCtrl.text = profile.languagesSpoken?.join(', ') ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _experienceCtrl.dispose();
    _teamSizeCtrl.dispose();
    _locationsCtrl.dispose();
    _languagesCtrl.dispose();
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
        description: _descriptionCtrl.text.trim(),
        yearsOfExperience: _experienceCtrl.text.trim(),
        teamSize: _teamSizeCtrl.text.trim(),
        serviceLocations: _locationsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        languagesSpoken: _languagesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );

      await VendorService().saveVendorProfile(updated);
      await session.reloadVendorProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business information updated')),
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
        title: const Text('Business Information'),
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
            Text(
              'Tell your customers more about your business to build trust.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Business Description',
                hintText: 'Describe what you do, your USP, etc.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _experienceCtrl,
              decoration: const InputDecoration(
                labelText: 'Years of Experience',
                hintText: 'e.g. 5+ years',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teamSizeCtrl,
              decoration: const InputDecoration(
                labelText: 'Team Size',
                hintText: 'e.g. 10 members',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationsCtrl,
              decoration: const InputDecoration(
                labelText: 'Service Locations',
                hintText: 'City 1, City 2 (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _languagesCtrl,
              decoration: const InputDecoration(
                labelText: 'Languages Spoken',
                hintText: 'Hindi, English, etc. (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
