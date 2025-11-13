import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../services/invitation_service.dart';
import '../models/invitation_models.dart';
import '../utils/deep_link_helper.dart';

class InvitationsListScreen extends StatefulWidget {
  const InvitationsListScreen({super.key});

  @override
  State<InvitationsListScreen> createState() => _InvitationsListScreenState();
}

class _InvitationsListScreenState extends State<InvitationsListScreen> {
  final InvitationService _service = InvitationService(Supabase.instance.client);
  List<InvitationItem> _active = <InvitationItem>[];
  List<InvitationItem> _past = <InvitationItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final rows = await _service.listMyInvitations();
    final active = <InvitationItem>[];
    final past = <InvitationItem>[];
    for (final item in rows) {
      if (_isActive(item)) {
        active.add(item);
      } else {
        past.add(item);
      }
    }
    setState(() { _active = active; _past = past; _loading = false; });
  }

  void _createNew() async {
    final created = await context.push('/invites/new');
    if (created == true) {
      _load();
    }
  }

  void _openPreview(InvitationItem item) {
    context.push('/invites/${item.slug}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My E-Invitations')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNew,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_active.isNotEmpty) ...[
                  _buildSectionHeader('Active invitations'),
                  const SizedBox(height: 12),
                  ..._active.map(_buildInvitationCard),
                  const SizedBox(height: 24),
                ],
                _buildSectionHeader('Past invitations'),
                const SizedBox(height: 12),
                if (_past.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No past invitations yet.'),
                    ),
                  )
                else
                  ..._past.map(_buildInvitationCard),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _buildInvitationCard(InvitationItem item) {
    final deepLink = 'saralevents://invite/${item.slug}';
    final dateText = item.eventDate != null
        ? DateFormat('EEE, dd MMM yyyy').format(item.eventDate!.toLocal())
        : 'Draft';
    final timeText = item.eventTime != null && item.eventTime!.isNotEmpty ? ' • ${item.eventTime}' : '';
    final locationText = item.address ?? item.venueName ?? 'Location to be announced';
    final statusLabel = _isActive(item) ? 'Upcoming' : 'Completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFDBB42).withOpacity(0.2),
                  child: const Icon(Icons.event, color: Color(0xFFFDBB42)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('$dateText$timeText', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: _isActive(item) ? const Color(0xFFE8F5E9) : const Color(0xFFE0E0E0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(locationText)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showRsvpSheet(item),
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('RSVP'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openPreview(item),
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _shareInvitation(item, deepLink),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showQrDialog(deepLink),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('QR code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isActive(InvitationItem item) {
    if (item.eventDate == null) return true;
    return item.eventDate!.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied: $url')));
  }

  Future<void> _shareInvitation(InvitationItem item, String deepLink) async {
    final universalLink = DeepLinkHelper.invitationUniversalLink(item.slug);
    
    final shareText = DeepLinkHelper.shareableText(
      title: 'You\'re invited to ${item.title}!',
      date: item.eventDate != null 
          ? DateFormat('EEE, dd MMM yyyy').format(item.eventDate!.toLocal())
          : null,
      time: item.eventTime,
      venue: item.venueName,
      universalLink: universalLink,
      deepLink: deepLink,
    );

    try {
      await Share.share(shareText, subject: 'Invitation: ${item.title}');
    } catch (e) {
      if (!mounted) return;
      await _copyLink(deepLink);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  void _showQrDialog(String deepLink) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invitation QR & Links'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.qr_code_2, size: 120),
            const SizedBox(height: 12),
            const Text('Invitation Link:', style: TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(deepLink, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 8),
            const Text('Share this link or show QR code at the venue for quick entry.', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(onPressed: () => _copyLink(deepLink), child: const Text('Copy link')),
        ],
      ),
    );
  }

  void _showRsvpSheet(InvitationItem item) {
    String status = 'yes';
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
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
                    Text('RSVP for ${item.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Your response'),
                      items: const [
                        DropdownMenuItem(value: 'yes', child: Text('Yes, I will attend')),
                        DropdownMenuItem(value: 'maybe', child: Text('Maybe')),
                        DropdownMenuItem(value: 'no', child: Text('No')),
                      ],
                      onChanged: (value) => setSheetState(() => status = value ?? 'yes'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Message (optional)'),
                      maxLines: 3,
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
                                  await _service.createRsvp(
                                    invitationId: item.id,
                                    name: nameController.text.trim(),
                                    status: status,
                                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(content: Text('RSVP recorded successfully.')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text('Failed to submit RSVP: $e')),
                                  );
                                } finally {
                                  setSheetState(() => submitting = false);
                                }
                              },
                        child: submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Submit RSVP'),
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
}


