import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _prefEmail = 'pref_notify_email';
  static const _prefSms = 'pref_notify_sms';
  static const _prefPush = 'pref_notify_push';
  static const _prefLanguage = 'pref_language';
  static const _prefCity = 'pref_default_city';
  static const _prefDataMobile = 'pref_data_mobile';
  static const _prefDataWifi = 'pref_data_wifi';

  bool _email = true;
  bool _sms = false;
  bool _push = true;
  bool _mediaMobile = true;
  bool _mediaWifi = true;
  String _language = 'en';
  final TextEditingController _cityController = TextEditingController();
  bool _loading = true;

  final List<Map<String, String>> _languages = const [
    {'code': 'en', 'label': 'English'},
    {'code': 'hi', 'label': 'Hindi'},
    {'code': 'te', 'label': 'Telugu'},
    {'code': 'ta', 'label': 'Tamil'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getBool(_prefEmail) ?? true;
      _sms = prefs.getBool(_prefSms) ?? false;
      _push = prefs.getBool(_prefPush) ?? true;
      _language = prefs.getString(_prefLanguage) ?? 'en';
      _cityController.text = prefs.getString(_prefCity) ?? '';
      _mediaMobile = prefs.getBool(_prefDataMobile) ?? true;
      _mediaWifi = prefs.getBool(_prefDataWifi) ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEmail, _email);
    await prefs.setBool(_prefSms, _sms);
    await prefs.setBool(_prefPush, _push);
    await prefs.setString(_prefLanguage, _language);
    await prefs.setString(_prefCity, _cityController.text.trim());
    await prefs.setBool(_prefDataMobile, _mediaMobile);
    await prefs.setBool(_prefDataWifi, _mediaWifi);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings updated successfully.')),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Email alerts'),
                        subtitle: const Text('Receive booking updates via email'),
                        value: _email,
                        onChanged: (value) => setState(() => _email = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('SMS updates'),
                        subtitle: const Text('Send SMS for time-sensitive changes'),
                        value: _sms,
                        onChanged: (value) => setState(() => _sms = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('App push notifications'),
                        subtitle: const Text('Instant alerts on new messages and offers'),
                        value: _push,
                        onChanged: (value) => setState(() => _push = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Language', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _language,
                      decoration: const InputDecoration(labelText: 'Preferred language'),
                      items: _languages
                          .map((lang) => DropdownMenuItem(
                                value: lang['code'],
                                child: Text(lang['label']!),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _language = value ?? 'en'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Location', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Default city'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This city will be used to personalise service recommendations and quick filters.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Data usage', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Preload media on mobile data'),
                        subtitle: const Text('Disable to reduce data usage on cellular networks'),
                        value: _mediaMobile,
                        onChanged: (value) => setState(() => _mediaMobile = value),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Preload media on Wi‑Fi'),
                        subtitle: const Text('Keep enabled for smooth browsing on Wi‑Fi'),
                        value: _mediaWifi,
                        onChanged: (value) => setState(() => _mediaWifi = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save changes'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tip: These settings sync locally for now. Multi-device sync is planned as part of the upcoming account preferences release.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
