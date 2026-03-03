import 'package:flutter/material.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  // Notification States
  final Map<String, bool> _preferences = {
    'new_booking': true,
    'booking_status': true,
    'new_inquiry': true,
    'payments': true,
    'new_message': true,
    'read_receipts': true,
    'mentions': true,
    'event_reminder': true,
    'event_updates': true,
    'task_reminders': true,
    'venue_updates': true,
    'promotions': false,
    'platform_updates': true,
    'performance_summary': true,
    'vendor_tips': true,
    'account_security': true,
    'profile_status': true,
    'subscription': true,
    'maintenance': true,
  };

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPreferenceTile(String title, String key, {String? subtitle}) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: _preferences[key] ?? false,
      onChanged: (bool value) {
        setState(() {
          _preferences[key] = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('BOOKING & INQUIRY'),
          _buildPreferenceTile('New booking received', 'new_booking'),
          _buildPreferenceTile('Booking confirmation or cancellation', 'booking_status'),
          _buildPreferenceTile('New client inquiry', 'new_inquiry'),
          _buildPreferenceTile('Payment received or refund processed', 'payments'),
          
          const Divider(),
          _buildSectionHeader('CHAT & COMMUNICATION'),
          _buildPreferenceTile('New message from client', 'new_message'),
          _buildPreferenceTile('Message read receipts', 'read_receipts'),
          _buildPreferenceTile('Mentions or tagged in chat/group', 'mentions'),
          
          const Divider(),
          _buildSectionHeader('EVENT & SCHEDULE'),
          _buildPreferenceTile('Upcoming event reminder', 'event_reminder'),
          _buildPreferenceTile('Event rescheduled or cancelled', 'event_updates'),
          _buildPreferenceTile('Task or checklist reminders', 'task_reminders'),
          _buildPreferenceTile('Venue or timing updates', 'venue_updates'),
          
          const Divider(),
          _buildSectionHeader('MARKETING & INSIGHTS'),
          _buildPreferenceTile('Promotions and offers from Saral Events', 'promotions'),
          _buildPreferenceTile('Platform updates & new features', 'platform_updates'),
          _buildPreferenceTile('Monthly performance summary', 'performance_summary'),
          _buildPreferenceTile('Tips & best practices for vendors', 'vendor_tips'),
          
          const Divider(),
          _buildSectionHeader('SYSTEM & ACCOUNT'),
          _buildPreferenceTile('Password changes or login alerts', 'account_security'),
          _buildPreferenceTile('Profile verification status', 'profile_status'),
          _buildPreferenceTile('Subscription or plan renewal reminders', 'subscription'),
          _buildPreferenceTile('System maintenance or downtime alerts', 'maintenance'),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
