import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _profilePicture;
  String? _profilePictureUrl;
  bool _uploadingPicture = false;

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
      _profilePictureUrl = vendor.profilePictureUrl;
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

  Future<void> _pickProfilePicture() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (result != null) {
      setState(() => _profilePicture = File(result.path));
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_profilePicture == null) return;
    
    final session = context.read<AppSession>();
    final vendor = session.vendorProfile;
    if (vendor?.id == null) return;
    
    setState(() => _uploadingPicture = true);
    try {
      final vendorService = VendorService();
      final url = await vendorService.uploadProfilePicture(_profilePicture!, vendor!.id!);
      setState(() {
        _profilePictureUrl = url;
        _profilePicture = null;
      });
      await session.reloadVendorProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload picture: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
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
        profilePictureUrl: _profilePictureUrl,
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
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _profilePicture != null
                            ? FileImage(_profilePicture!)
                            : (_profilePictureUrl != null
                                ? NetworkImage(_profilePictureUrl!)
                                : null) as ImageProvider?,
                        child: (_profilePicture == null && _profilePictureUrl == null)
                            ? Icon(Icons.business, size: 60, color: Colors.grey[600])
                            : null,
                      ),
                      if (_uploadingPicture)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _uploadingPicture ? null : _pickProfilePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Change Profile Picture'),
                  ),
                  if (_profilePicture != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _uploadingPicture ? null : _uploadProfilePicture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _uploadingPicture
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload Picture'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
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
