import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  static const _prefDarkMode = 'pref_dark_mode';
  static const _prefFontScale = 'pref_font_scale';

  bool _darkMode = false;
  _FontScale _fontScale = _FontScale.medium;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool(_prefDarkMode) ?? false;
      final storedScale = prefs.getString(_prefFontScale);
      _fontScale = _FontScale.values.firstWhere(
        (scale) => scale.name == storedScale,
        orElse: () => _FontScale.medium,
      );
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkMode, _darkMode);
    await prefs.setString(_prefFontScale, _fontScale.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accessibility preferences saved.')),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Dark mode'),
                    subtitle: const Text('Reduce glare and use a darker theme across the app'),
                    value: _darkMode,
                    onChanged: (value) => setState(() => _darkMode = value),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Font size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        SegmentedButton<_FontScale>(
                          segments: const [
                            ButtonSegment(value: _FontScale.small, label: Text('Small')),
                            ButtonSegment(value: _FontScale.medium, label: Text('Medium')),
                            ButtonSegment(value: _FontScale.large, label: Text('Large')),
                          ],
                          selected: {_fontScale},
                          onSelectionChanged: (selection) => setState(() => _fontScale = selection.first),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preview text',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(fontSize: _fontScale.previewSize, height: 1.4),
                          child: const Text(
                            'Great accessibility ensures everyone can enjoy Saral Events. Choose a comfortable reading size that works best for you.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Additional options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        Text('Upcoming updates will let you adjust colour contrast, reduce motion and enable high-contrast map pins for better visibility.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save preferences'),
                ),
              ],
            ),
    );
  }
}

enum _FontScale { small, medium, large }

extension on _FontScale {
  double get previewSize {
    switch (this) {
      case _FontScale.small:
        return 14;
      case _FontScale.medium:
        return 16;
      case _FontScale.large:
        return 18;
    }
  }
}
