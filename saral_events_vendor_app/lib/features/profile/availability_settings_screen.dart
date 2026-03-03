import 'package:flutter/material.dart';

class AvailabilitySettingsScreen extends StatefulWidget {
  const AvailabilitySettingsScreen({super.key});

  @override
  State<AvailabilitySettingsScreen> createState() => _AvailabilitySettingsScreenState();
}

class _AvailabilitySettingsScreenState extends State<AvailabilitySettingsScreen> {
  final List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Map<String, bool> _availability = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': false,
    'Sunday': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Availability Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Set your recurring weekly availability here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ..._weekdays.map((day) => SwitchListTile(
            title: Text(day),
            value: _availability[day] ?? false,
            onChanged: (val) {
              setState(() {
                _availability[day] = val;
              });
            },
          )),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.event_busy),
            title: const Text('Block Dates'),
            subtitle: const Text('Specific dates when you are unavailable'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Future: Block specific dates
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Time Slots'),
            subtitle: const Text('Define morning, evening, or custom slots'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Future: Manage specific time slots
            },
          ),
        ],
      ),
    );
  }
}
