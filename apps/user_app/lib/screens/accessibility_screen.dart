import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/theme_notifier.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  static const _prefFontScale = 'pref_font_scale';

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
    await prefs.setString(_prefFontScale, _fontScale.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accessibility preferences saved.')),
    );
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
                Consumer<ThemeNotifier>(
                  builder: (context, themeNotifier, _) {
                    final isDark = themeNotifier.themeMode == ThemeMode.dark;
                    final isSystem = themeNotifier.themeMode == ThemeMode.system;
                    
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: const Text('Dark mode'),
                            subtitle: Text(
                              isSystem 
                                  ? 'Following system setting'
                                  : (isDark ? 'Enabled' : 'Disabled'),
                            ),
                            value: isDark,
                            onChanged: (value) {
                              themeNotifier.setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: const Text('Theme mode'),
                            subtitle: const Text('Choose how dark mode is applied'),
                            trailing: PopupMenuButton<ThemeMode>(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSystem 
                                        ? 'System Default'
                                        : (isDark ? 'Dark' : 'Light'),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down),
                                ],
                              ),
                              onSelected: (mode) => themeNotifier.setThemeMode(mode),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: ThemeMode.system,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.brightness_auto,
                                        size: 20,
                                        color: isSystem 
                                            ? Theme.of(context).colorScheme.primary 
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('System Default'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: ThemeMode.light,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.light_mode,
                                        size: 20,
                                        color: !isDark && !isSystem 
                                            ? Theme.of(context).colorScheme.primary 
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Light'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: ThemeMode.dark,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.dark_mode,
                                        size: 20,
                                        color: isDark 
                                            ? Theme.of(context).colorScheme.primary 
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Dark'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
