import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/session.dart';
import '../../core/ui/app_icons.dart';
import '../vendor_setup/vendor_models.dart';
import 'business_details_screen.dart';
import 'documents_screen.dart';
import 'notification_preferences_screen.dart';
import 'settings_screen.dart';
import 'business_info_expanded_screen.dart';
import 'availability_settings_screen.dart';
import 'pricing_policies_screen.dart';
import 'bank_payout_details_screen.dart';
import 'reviews_screen.dart';
import 'public_profile_preview_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  double _calculateCompletion(VendorProfile? profile) {
    if (profile == null) return 0;
    int total = 14;
    int filled = 0;
    if (profile.profilePictureUrl != null) filled++;
    if (profile.businessName.isNotEmpty) filled++;
    if (profile.description != null && profile.description!.isNotEmpty) filled++;
    if (profile.address.isNotEmpty) filled++;
    if (profile.phoneNumber != null) filled++;
    if (profile.email != null) filled++;
    if (profile.yearsOfExperience != null) filled++;
    if (profile.teamSize != null) filled++;
    if (profile.serviceLocations != null && profile.serviceLocations!.isNotEmpty) filled++;
    if (profile.languagesSpoken != null && profile.languagesSpoken!.isNotEmpty) filled++;
    if (profile.accountNumber != null) filled++;
    if (profile.upiId != null) filled++;
    if (profile.advancePaymentPercentage != null) filled++;
    if (profile.documents.isNotEmpty) filled++;
    return filled / total;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final profile = session.vendorProfile;
    final completion = _calculateCompletion(profile);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 1. Profile Overview Section
          _buildProfileOverview(context, profile, completion),
          const SizedBox(height: 16),

          // 2. Public Profile Preview
          _buildActionButton(
            context,
            'Public Profile Preview',
            'View public profile',
            Icons.visibility_outlined,
            Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublicProfilePreviewScreen())),
          ),

          _buildSectionHeader(context, 'Business Management'),
          // 3. Ratings & Reviews
          _buildMenuTile(
            context,
            'Ratings & Reviews',
            '${profile?.rating ?? 4.8} (${profile?.totalReviews ?? 24} reviews)',
            Icons.star_outline,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
          ),
          
          // 4. Business Information
          _buildMenuTile(
            context,
            'Business Information',
            'Detailed bio, services, locations',
            Icons.info_outline,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessInformationExpandedScreen())),
          ),

          // 5. Availability Settings
          _buildMenuTile(
            context,
            'Availability Settings',
            'Weekly schedule & blocked dates',
            Icons.calendar_month_outlined,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailabilitySettingsScreen())),
          ),

          // 6. Pricing & Policies
          _buildMenuTile(
            context,
            'Pricing & Policies',
            'Payment terms & refund rules',
            Icons.policy_outlined,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PricingPoliciesScreen())),
          ),

          _buildSectionHeader(context, 'Finance & Verification'),
          // 7. Bank & Payout Details
          _buildMenuTile(
            context,
            'Bank & Payout Details',
            'Settlement account and history',
            Icons.account_balance_outlined,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankPayoutDetailsScreen())),
          ),

          // 8. Verification & Documents
          _buildMenuTile(
            context,
            'Verification & Documents',
            'Approval status: ${profile?.approvalStatus?.toUpperCase() ?? 'PENDING'}',
            Icons.verified_user_outlined,
            () => context.push('/app/documents'),
          ),

          _buildSectionHeader(context, 'Account Settings'),
          _buildMenuTile(
            context,
            'Notification Settings',
            'Manage alerts and sounds',
            Icons.notifications_outlined,
            () => context.push('/app/settings'),
          ),
          
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                context.read<AppSession>().signOut();
                context.go('/auth/pre');
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Saral Events Vendor App v1.0.2',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileOverview(BuildContext context, VendorProfile? profile, double completion) {
    if (profile == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: profile.profilePictureUrl != null ? NetworkImage(profile.profilePictureUrl!) : null,
                    child: profile.profilePictureUrl == null ? const Icon(Icons.business, size: 30) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        profile.approvalStatus == 'approved' ? Icons.verified : Icons.stars_outlined,
                        color: profile.approvalStatus == 'approved' ? Colors.blue : Colors.orange,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.category,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: profile.approvalStatus == 'approved' ? Colors.blue[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.approvalStatus == 'approved' ? 'Verified Partner' : 'Verification Pending',
                        style: TextStyle(
                          color: profile.approvalStatus == 'approved' ? Colors.blue : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile Completion', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${(completion * 100).toInt()}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completion,
            backgroundColor: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        tileColor: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        trailing: Icon(Icons.chevron_right, color: color),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.black87, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}



