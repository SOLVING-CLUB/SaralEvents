import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends push notifications via Supabase Edge Function `send-push-notification`.
///
/// Note: `userId` must be the receiver's `auth.users.id` (NOT vendor_profiles.id).
/// 
/// **IMPORTANT**: Always specify `appTypes` to ensure notifications go to the correct app:
/// - For customer notifications: `appTypes: ['user_app']`
/// - For vendor notifications: `appTypes: ['vendor_app']`
class NotificationSenderService {
  final SupabaseClient _supabase;

  NotificationSenderService(this._supabase);

  /// Send a push notification
  /// 
  /// [userId] - The receiver's auth.users.id (NOT vendor_profiles.id)
  /// [title] - Notification title
  /// [body] - Notification body
  /// [data] - Additional data payload (optional)
  /// [appTypes] - **REQUIRED**: Array of app types to target: ['user_app'] or ['vendor_app']
  ///              This ensures notifications only go to the intended app
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    required List<String> appTypes, // REQUIRED to prevent cross-app notifications
  }) async {
    // Validate appTypes is provided
    if (appTypes.isEmpty) {
      throw ArgumentError('appTypes is required and cannot be empty. Specify ["user_app"] or ["vendor_app"]');
    }

    // Validate appTypes values
    final validAppTypes = ['user_app', 'vendor_app'];
    for (final appType in appTypes) {
      if (!validAppTypes.contains(appType)) {
        throw ArgumentError('Invalid appType: $appType. Must be one of: ${validAppTypes.join(", ")}');
      }
    }

    final requestBody = {
      'userId': userId,
      'title': title,
      'body': body,
      'appTypes': appTypes, // CRITICAL: Filter tokens by app_type
      if (data != null) 'data': data,
    };

    if (kDebugMode) {
      debugPrint('📤 [Vendor] send-push-notification: $requestBody');
      debugPrint('   → Targeting app types: ${appTypes.join(", ")}');
    }

    final response = await _supabase.functions.invoke(
      'send-push-notification',
      body: requestBody,
    );

    if (response.status != 200) {
      throw Exception('Failed to send notification: ${response.status} - ${response.data}');
    }

    if (kDebugMode) {
      debugPrint('✅ [Vendor] Notification sent successfully to ${appTypes.join(", ")}');
    }
  }
}

