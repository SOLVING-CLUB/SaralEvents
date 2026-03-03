import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/invitation_service.dart';
import '../models/invitation_models.dart';

class InvitationEditorScreen extends StatefulWidget {
  const InvitationEditorScreen({super.key});

  @override
  State<InvitationEditorScreen> createState() => _InvitationEditorScreenState();
}

class _InvitationEditorScreenState extends State<InvitationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final InvitationService _service = InvitationService(Supabase.instance.client);

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  final _venueCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _coverLocalPath;
  InvitationVisibility _visibility = InvitationVisibility.unlisted;

  bool _saving = false;

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() { _coverLocalPath = file.path; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    try {
      final String? timeStr = _eventTime != null
          ? '${_eventTime!.hour.toString().padLeft(2, '0')}:${_eventTime!.minute.toString().padLeft(2, '0')}'
          : null;
      final item = await _service.createInvitation(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        eventDate: _eventDate,
        eventTime: timeStr,
        venueName: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        coverImagePath: _coverLocalPath,
        visibility: _visibility,
      );
      if (!mounted) return;
      if (item != null) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create invitation')));
      }
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create E-Invitation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Event Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 5),
                        initialDate: _eventDate ?? now,
                      );
                      if (picked != null) setState(() { _eventDate = picked; });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(_eventDate != null ? _eventDate!.toLocal().toString().split(' ')[0] : 'Pick date'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _eventTime ?? TimeOfDay.now());
                      if (picked != null) setState(() { _eventTime = picked; });
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Time'),
                      child: Text(_eventTime != null ? _eventTime!.format(context) : 'Pick time'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueCtrl,
              decoration: const InputDecoration(labelText: 'Venue name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickCover,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick cover'),
                ),
                const SizedBox(width: 12),
                if (_coverLocalPath != null)
                  Expanded(
                    child: Text(
                      _coverLocalPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<InvitationVisibility>(
              initialValue: _visibility,
              items: const [
                DropdownMenuItem(value: InvitationVisibility.public, child: Text('Public (discoverable)')),
                DropdownMenuItem(value: InvitationVisibility.unlisted, child: Text('Unlisted (shareable link)')),
                DropdownMenuItem(value: InvitationVisibility.private, child: Text('Private (owner only)')),
              ],
              onChanged: (v) => setState(() { _visibility = v ?? InvitationVisibility.unlisted; }),
              decoration: const InputDecoration(labelText: 'Visibility'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


