// Temporary Debug Screen - Add this to your app to see current user ID
// Add this route to your router and navigate to it to see your user ID

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShowCurrentUserIdScreen extends StatelessWidget {
  const ShowCurrentUserIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final email = user?.email;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Current User Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User Information:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('User ID: ${userId ?? "NULL"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Email: ${email ?? "NULL"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            const Text('Expected User ID (from bookings):', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('62a201d9-ec45-4532-ace0-825152934451', style: TextStyle(fontSize: 16, fontFamily: 'monospace')),
            const SizedBox(height: 24),
            if (userId != '62a201d9-ec45-4532-ace0-825152934451')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ USER ID MISMATCH!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    SizedBox(height: 8),
                    Text('Your current user ID does not match the bookings user ID.'),
                    SizedBox(height: 8),
                    Text('Solution: Update bookings to use your current user ID, or log in with the account that owns those bookings.'),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ USER ID MATCHES!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    SizedBox(height: 8),
                    Text('Your user ID matches the bookings. If bookings still don\'t show, check RLS policies.'),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // Test query bookings
                try {
                  final result = await Supabase.instance.client
                      .from('bookings')
                      .select('id, user_id, booking_date, status')
                      .eq('user_id', userId ?? '')
                      .limit(5);
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Test Query Result'),
                      content: Text('Found ${result.length} bookings\n\n${result.map((b) => 'ID: ${b['id']}\nStatus: ${b['status']}').join('\n\n')}'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Error'),
                      content: Text('Error: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Test Query Bookings'),
            ),
          ],
        ),
      ),
    );
  }
}

