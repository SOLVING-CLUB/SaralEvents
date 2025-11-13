import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/invitation_service.dart';
import '../models/invitation_models.dart';
import '../utils/deep_link_helper.dart';

class InvitationPreviewScreen extends StatefulWidget {
  final String slug;
  const InvitationPreviewScreen({super.key, required this.slug});

  @override
  State<InvitationPreviewScreen> createState() => _InvitationPreviewScreenState();
}

class _InvitationPreviewScreenState extends State<InvitationPreviewScreen> {
  final InvitationService _service = InvitationService(Supabase.instance.client);
  InvitationItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await _service.getBySlug(widget.slug);
    setState(() { _item = item; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_item == null)
              ? const Center(child: Text('Invitation not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_item!.coverImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_item!.coverImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 16),
                    Text(_item!.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_item!.description != null) Text(_item!.description!),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.event),
                      const SizedBox(width: 8),
                      Text([
                        if (_item!.eventDate != null) _item!.eventDate!.toLocal().toString().split(' ')[0],
                        if (_item!.eventTime != null) _item!.eventTime!
                      ].join(' • ')),
                    ]),
                    const SizedBox(height: 8),
                    if (_item!.venueName != null || _item!.address != null)
                      Row(children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 8),
                        Expanded(child: Text([_item!.venueName, _item!.address].whereType<String>().join(', '))),
                      ]),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _service.createRsvp(invitationId: _item!.id, status: 'yes');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RSVP sent')));
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('RSVP Yes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _shareInvitation(),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Invitation'),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Share Link:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    'saralevents://invite/${_item!.slug}',
                                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => _copyLink('saralevents://invite/${_item!.slug}'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Tap the link above to copy. Share it with friends to open the invitation directly in the app.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _shareInvitation() async {
    if (_item == null) return;
    final universalLink = DeepLinkHelper.invitationUniversalLink(_item!.slug);
    final deepLink = DeepLinkHelper.invitationLink(_item!.slug);
    
    final shareText = DeepLinkHelper.shareableText(
      title: 'You\'re invited to ${_item!.title}!',
      date: _item!.eventDate != null 
          ? DateFormat('EEE, dd MMM yyyy').format(_item!.eventDate!.toLocal())
          : null,
      time: _item!.eventTime,
      venue: _item!.venueName,
      universalLink: universalLink,
      deepLink: deepLink,
    );

    try {
      await Share.share(shareText, subject: 'Invitation: ${_item!.title}');
    } catch (e) {
      if (!mounted) return;
      await _copyLink(deepLink);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: $link')),
    );
  }
}


