import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../utils/deep_link_helper.dart';

class ReferEarnScreen extends StatefulWidget {
  final String? initialReferralCode;

  const ReferEarnScreen({super.key, this.initialReferralCode});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  bool _loading = true;
  String? _referralCode;
  String? _deepLink;
  List<_RewardEntry> _rewards = const <_RewardEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _referralCode = widget.initialReferralCode;
        _deepLink = widget.initialReferralCode != null
            ? 'saralevents://refer/${widget.initialReferralCode}'
            : null;
        _rewards = const [];
      });
      return;
    }

    String code = user.userMetadata?['referral_code'] as String? ?? user.id.substring(0, 6).toUpperCase();
    final deepLink = 'saralevents://refer/$code';
    List<_RewardEntry> rewards;
    try {
      final rows = await client
          .from('referral_rewards')
          .select('id, amount, status, created_at, referred_email')
          .eq('user_id', user.id)
          .order('created_at', ascending: false) as List<dynamic>;
      rewards = rows
          .map((dynamic row) => _RewardEntry.fromMap(Map<String, dynamic>.from(row as Map<String, dynamic>)))
          .toList();
    } catch (e) {
      rewards = _RewardEntry.sample();
    }

    if (!mounted) return;
    setState(() {
      _referralCode = code;
      _deepLink = deepLink;
      _rewards = rewards;
      _loading = false;
    });
  }

  void _copyReferral() {
    final link = _deepLink ?? (widget.initialReferralCode != null
        ? 'saralevents://refer/${widget.initialReferralCode}'
        : (_referralCode != null ? 'saralevents://refer/$_referralCode' : null));
    if (link == null) return;
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral link copied to clipboard!')),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final deep = _deepLink ?? (widget.initialReferralCode != null ? 'saralevents://refer/${widget.initialReferralCode}' : (_referralCode != null ? 'saralevents://refer/$_referralCode' : null));
    if (deep == null) return;
    
    final shareText = 'Plan unforgettable events with Saral! Use my referral code: ${_referralCode ?? widget.initialReferralCode ?? ''}\n\nOpen in app: $deep\n\nSign up and earn rewards! 🎉';
    final message = Uri.encodeComponent(shareText);
    final uri = Uri.parse('https://wa.me/?text=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp. Link copied instead.')),
      );
      _copyReferral();
    }
  }

  Future<void> _shareToInstagram() async {
    final deep = _deepLink ?? (widget.initialReferralCode != null ? 'saralevents://refer/${widget.initialReferralCode}' : (_referralCode != null ? 'saralevents://refer/$_referralCode' : null));
    if (deep == null) return;
    
    final text = 'Join Saral Events with my code ${_referralCode ?? widget.initialReferralCode ?? ''} and unlock booking rewards!\n\nOpen in app: $deep';
    final message = Uri.encodeComponent(text);
    final uri = Uri.parse('https://www.instagram.com/?url=$message');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram share isn\'t available. Link copied.')),
      );
      _copyReferral();
    }
  }

  Future<void> _shareReferral() async {
    final code = _referralCode ?? widget.initialReferralCode ?? '';
    if (code.isEmpty) return;
    
    final universalLink = DeepLinkHelper.referralUniversalLink(code);
    final deepLink = DeepLinkHelper.referralLink(code);
    
    final shareText = '''🎁 Join Saral Events and earn rewards!

Use my referral code: $code

Open in app:
$universalLink

Or use custom link:
$deepLink

When you book your first service, we both get wallet credits! 🎉''';

    try {
      await Share.share(shareText, subject: 'Join Saral Events - Referral Code: $code');
    } catch (e) {
      if (!mounted) return;
      _copyReferral();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Invite friends. Earn rewards.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('Share your unique code. When friends book their first service, both of you receive wallet credits.'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDBB42).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, color: Color(0xFFFDBB42)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _referralCode ?? 'Unavailable',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: 'Copy',
                                onPressed: _copyReferral,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareToWhatsApp,
                                icon: const Icon(Icons.sms_outlined),
                                label: const Text('WhatsApp'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareToInstagram,
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Instagram'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _shareReferral,
                            icon: const Icon(Icons.share),
                            label: const Text('Share via...'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Reward history', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_rewards.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Invite friends to start unlocking rewards. Successful referrals will appear here.'),
                    ),
                  )
                else
                  ..._rewards.map((reward) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: reward.statusColor.withOpacity(0.12),
                            child: Icon(reward.statusIcon, color: reward.statusColor),
                          ),
                          title: Text(reward.referredEmail ?? 'Referral'),
                          subtitle: Text('${reward.statusLabel} • ${reward.formattedDate}'),
                          trailing: Text(reward.formattedAmount, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      )),
                const SizedBox(height: 24),
                const Text(
                  'How it works',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '''1. Share your referral link with friends.
2. They sign up and complete their first booking.
3. You both receive wallet credits after the booking is confirmed.''',
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _RewardEntry {
  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? referredEmail;

  _RewardEntry({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.referredEmail,
  });

  factory _RewardEntry.fromMap(Map<String, dynamic> map) {
    return _RewardEntry(
      id: map['id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      referredEmail: map['referred_email'] as String?,
    );
  }

  static List<_RewardEntry> sample() {
    final now = DateTime.now();
    return [
      _RewardEntry(
        id: 'sample-1',
        amount: 250,
        status: 'approved',
        createdAt: now.subtract(const Duration(days: 4)),
        referredEmail: 'friend@example.com',
      ),
      _RewardEntry(
        id: 'sample-2',
        amount: 250,
        status: 'pending',
        createdAt: now.subtract(const Duration(days: 10)),
        referredEmail: 'guest@example.com',
      ),
    ];
  }

  String get formattedAmount => NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount);

  String get formattedDate => DateFormat('dd MMM yyyy').format(createdAt.toLocal());

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Reward added';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_bottom;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade600;
      case 'pending':
        return Colors.orange.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.blueGrey;
    }
  }
}
