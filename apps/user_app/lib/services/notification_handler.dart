import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handler for navigation based on notification data
class NotificationHandler {
  final BuildContext context;

  NotificationHandler(this.context);

  /// Handle notification tap and navigate accordingly
  void handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (!context.mounted) return;

    switch (type) {
      case 'order_update':
      case 'order':
        final orderId = data['order_id'] as String?;
        if (orderId != null) {
          context.push('/app/orders');
          // Optionally navigate to specific order details
          // context.push('/app/orders/$orderId');
        }
        break;

      case 'payment':
        final orderId = data['order_id'] as String?;
        if (orderId != null) {
          context.push('/app/orders');
        }
        break;

      case 'support':
      case 'message':
        context.push('/app/profile');
        // Optionally navigate to support/chat screen
        break;

      case 'booking':
      case 'booking_reminder':
        final bookingId = data['booking_id'] as String?;
        if (bookingId != null) {
          context.push('/app/orders');
        }
        break;

      case 'transaction':
        context.push('/app/orders');
        break;

      default:
        // Navigate to home or show notification details
        context.push('/app');
        break;
    }
  }

  /// Show local notification (for foreground messages)
  static void showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    // Implement using flutter_local_notifications package
    // This is a placeholder
    debugPrint('📢 Local notification: $title - $body');
  }
}
