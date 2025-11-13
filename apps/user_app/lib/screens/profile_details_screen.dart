import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session.dart';
import '../services/profile_service.dart';
import 'package:image_picker/image_picker.dart' as img;
import 'dart:io';
import '../core/input_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/address_storage.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  static const _prefCity = 'pref_default_city';
  final _formKey = GlobalKey<FormState>();
  late final ProfileService _profileService;
  bool _loading = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  String? _imageUrl;
  bool _uploadingImage = false;
  String? _email;
  bool _emailVerified = false;
  List<AddressInfo> _addresses = <AddressInfo>[];
  String? _activeAddressId;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(Supabase.instance.client);
    _load();
    _loadCityPreference();
    _loadAddresses();
  }

  Future<void> _load() async {
    final user = context.read<UserSession>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    final p = await _profileService.getProfile(user.id);
    _firstNameController.text = (p?['first_name'] ?? '') as String;
    _lastNameController.text = (p?['last_name'] ?? '') as String;
    _phoneController.text = (p?['phone_number'] ?? '') as String;
    _imageUrl = p?['image_url'] as String?;
    _email = user.email;
    _emailVerified = user.emailConfirmedAt != null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<UserSession>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    await _profileService.upsertProfile(
      userId: user.id,
      email: user.email ?? '',
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      imageUrl: _imageUrl,
    );
    await _saveCityPreference();
    if (mounted) {
      setState(() => _loading = false);
      Navigator.maybePop(context, true);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = context.read<UserSession>().currentUser;
    if (user == null) return;
    final picker = img.ImagePicker();
    img.XFile? result;
    try {
      result = await picker.pickImage(source: img.ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    } on PlatformException catch (e) {
      // Some devices/plugins fail to init gallery channel on hot-restart. Fall back to camera.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery unavailable (${e.code}). Opening camera...')),
        );
      }
      result = await picker.pickImage(source: img.ImageSource.camera, maxWidth: 1024, imageQuality: 85);
    }
    if (result == null) return;
    if (!mounted) return;
    setState(() => _uploadingImage = true);
    try {
      final file = File(result.path);
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}${result.name.substring(result.name.lastIndexOf('.'))}';
      final publicUrl = await _profileService.uploadProfileImage(
        userId: user.id,
        file: file,
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() => _imageUrl = publicUrl);
      // Auto-save image_url so DB reflects the latest avatar without requiring Save button
      await _profileService.upsertProfile(
        userId: user.id,
        email: user.email ?? '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        imageUrl: publicUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _loadCityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString(_prefCity) ?? '';
    if (mounted) setState(() => _cityController.text = city);
  }

  Future<void> _saveCityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCity, _cityController.text.trim());
  }

  Future<void> _loadAddresses() async {
    final addresses = await AddressStorage.loadSaved();
    final active = await AddressStorage.getActiveId();
    if (mounted) {
      setState(() {
        _addresses = addresses;
        _activeAddressId = active;
      });
    }
  }

  Future<void> _setActiveAddress(AddressInfo info) async {
    await AddressStorage.setActive(info);
    await _loadAddresses();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${info.label} set as default address.')),
      );
    }
  }

  Future<void> _deleteAddress(AddressInfo info) async {
    await AddressStorage.delete(info.id);
    await _loadAddresses();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${info.label}')),
      );
    }
  }

  Future<void> _addAddress() async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add address'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label (Home, Work, etc.)'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter a label' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter address details' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final list = List<AddressInfo>.from(_addresses)
                ..add(AddressInfo(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  label: labelController.text.trim(),
                  address: addressController.text.trim(),
                  lat: 0,
                  lng: 0,
                ));
              await AddressStorage.saveAll(list);
              Navigator.pop(context);
              if (!mounted) return;
              await _loadAddresses();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFDBB42).withOpacity(0.2),
        child: const Icon(Icons.email_outlined, color: Color(0xFFFDBB42)),
      ),
      title: Text(_email ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_emailVerified ? 'Email verified' : 'Email not verified'),
      trailing: _emailVerified
          ? const Chip(label: Text('Verified'), backgroundColor: Color(0xFFE8F5E9))
          : const Icon(Icons.warning_amber_outlined, color: Colors.orange),
    );
  }

  Widget _buildAddressTile(AddressInfo info) {
    final bool isActive = info.id == _activeAddressId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(info.address),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'default') {
              _setActiveAddress(info);
            } else if (value == 'remove') {
              _deleteAddress(info);
            }
          },
          itemBuilder: (context) => [
            if (!isActive)
              const PopupMenuItem(value: 'default', child: Text('Set as default')),
            const PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        ),
        leading: Icon(
          isActive ? Icons.location_on : Icons.place_outlined,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'New password'),
                      obscureText: true,
                      validator: (value) => value != null && value.length >= 8 ? null : 'Minimum 8 characters',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      decoration: const InputDecoration(labelText: 'Confirm password'),
                      obscureText: true,
                      validator: (value) => value == passwordController.text ? null : 'Passwords do not match',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => submitting = true);
                                try {
                                  await context.read<UserSession>().updatePassword(passwordController.text.trim());
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(content: Text('Password updated successfully.')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text('Failed to update password: $e')),
                                  );
                                } finally {
                                  setSheetState(() => submitting = false);
                                }
                              },
                        child: submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Update password'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('Deleting your account removes your profile, invitations and preferences. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client.functions.invoke('user-delete-account');
      if (!mounted) return;
      await context.read<UserSession>().signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _uploadingImage ? null : () async {
                              try {
                                await _pickAndUploadImage();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to pick image: $e')),
                                  );
                                }
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.grey[100],
                                  backgroundImage: (_imageUrl != null && _imageUrl!.isNotEmpty)
                                      ? NetworkImage(_imageUrl!)
                                      : null,
                                  child: (_imageUrl == null || _imageUrl!.isEmpty)
                                      ? const Icon(Icons.person, size: 44, color: Colors.black54)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _uploadingImage ? null : _pickAndUploadImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Change profile photo'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_email != null) ...[
                          _buildEmailTile(),
                          const SizedBox(height: 12),
                        ],
                        const Text('Edit your details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'First name'),
                          inputFormatters: [LettersSpacesTextInputFormatter()],
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.name,
                          validator: Validators.personNameLettersSpaces,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Last name'),
                          inputFormatters: [LettersSpacesTextInputFormatter()],
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.name,
                          validator: Validators.personNameLettersSpaces,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone number'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [E164PhoneInputFormatter(maxLength: 15)],
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City preference'),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _save,
                            child: const Text('Save changes'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saved addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            TextButton.icon(
                              onPressed: _addAddress,
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_addresses.isEmpty)
                          const Text('No saved addresses yet. Add frequently used locations for faster bookings.', style: TextStyle(color: Colors.grey))
                        else
                          ..._addresses.map(_buildAddressTile),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text('Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _showChangePasswordSheet,
                          child: const Text('Change password'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _confirmDeleteAccount,
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
