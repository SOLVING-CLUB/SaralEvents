import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session.dart';
import '../services/profile_service.dart';
import 'profile_details_screen.dart';
import 'invitations_list_screen.dart';
import 'wallet_payments_screen.dart';
import 'help_support_screen.dart';
import 'accessibility_screen.dart';
import 'settings_screen.dart';
import 'refer_earn_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Form key unused in this screen
  late final ProfileService _profileService;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    final user = context.read<UserSession>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final p = await _profileService.getProfile(user.id);
    _profile = p;
    _firstNameController.text = (p?['first_name'] ?? '') as String;
    _lastNameController.text = (p?['last_name'] ?? '') as String;
    _phoneController.text = (p?['phone_number'] ?? '') as String;
    if (mounted) setState(() => _loading = false);
  }

  // Save handled in ProfileDetailsScreen

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFDBB42)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final user = session.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (user == null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 64),
                      const SizedBox(height: 12),
                      Text('You are not logged in', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Please log in to view and edit your profile.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => GoRouter.of(context).go('/auth/pre'),
                        child: const Text('Log in'),
                      )
                    ],
                  ),
                ))
              
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Builder(builder: (context) {
                    final authMeta = user.userMetadata ?? {};
                    final fallbackAvatar = (authMeta['avatar_url'] ?? authMeta['picture']) as String?;
                    final imageUrl = (_profile?['image_url'] as String?) ?? fallbackAvatar;
                    return CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                      child: (imageUrl == null || imageUrl.isEmpty)
                          ? const Icon(Icons.person, size: 40, color: Colors.black87)
                          : null,
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    (_profile != null && ((_profile?['first_name'] ?? '').toString().isNotEmpty || (_profile?['last_name'] ?? '').toString().isNotEmpty))
                        ? '${_profile?['first_name'] ?? ''} ${_profile?['last_name'] ?? ''}'.trim()
                        : (user.email ?? 'User'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        context,
                        icon: Icons.card_giftcard,
                        title: 'My Invitations',
                        subtitle: 'Track active and past invites',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvitationsListScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.badge_outlined,
                        title: 'Profile Details',
                        subtitle: 'Update personal information',
                        onTap: () async {
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()),
                          );
                          if (changed == true) {
                            _load();
                          }
                        },
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet & Payments',
                        subtitle: 'Payment methods and transactions',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WalletPaymentsScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.support_agent,
                        title: 'Help & Support',
                        subtitle: 'FAQs, issues, feedback, about',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.visibility_outlined,
                        title: 'Accessibility',
                        subtitle: 'Theme and font preferences',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AccessibilityScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Notifications, language, location',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMenuTile(
                        context,
                        icon: Icons.card_giftcard_outlined,
                        title: 'Refer & Earn',
                        subtitle: 'Share and earn rewards',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReferEarnScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                        ],
                      ),
                    );
                    if (shouldLogout == true) {
                      await context.read<UserSession>().signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    }
                  },
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Log out'),
                ),
              ],
            )),
    );
  }
}
