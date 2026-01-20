import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to send push notifications via Supabase Edge Function
class NotificationSenderService {
  final SupabaseClient _supabase;

  NotificationSenderService(this._supabase);

  /// Send a push notification to a user
  /// 
  /// [userId] - The user ID to send notification to (optional if tokens provided)
  /// [tokens] - Specific FCM tokens to send to (optional, will fetch from DB if not provided)
  /// [title] - Notification title
  /// [body] - Notification body
  /// [data] - Additional data payload (optional)
  /// [imageUrl] - Image URL for notification (optional)
  Future<Map<String, dynamic>> sendNotification({
    String? userId,
    List<String>? tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    try {
      if (userId == null && (tokens == null || tokens.isEmpty)) {
        throw ArgumentError('Either userId or tokens must be provided');
      }

      final requestBody = {
        if (userId != null) 'userId': userId,
        if (tokens != null && tokens.isNotEmpty) 'tokens': tokens,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
      
      debugPrint('📤 NotificationSenderService: Invoking Edge Function');
      debugPrint('   Function: send-push-notification');
      debugPrint('   Body: $requestBody');
      
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: requestBody,
      );

      debugPrint('📥 NotificationSenderService: Edge Function response');
      debugPrint('   Status: ${response.status}');
      debugPrint('   Data: ${response.data}');

      if (response.status == 200) {
        debugPrint('✅ Notification sent successfully');
        return response.data as Map<String, dynamic>;
      } else {
        final errorMsg = 'Failed to send notification: ${response.status} - ${response.data}';
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending notification: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Send order update notification
  Future<void> sendOrderUpdate({
    required String userId,
    required String orderId,
    required String status,
    String? message,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'Order Update',
      body: message ?? 'Your order status has been updated to $status',
      data: {
        'type': 'order_update',
        'order_id': orderId,
        'status': status,
      },
    );
  }

  /// Send payment notification
  Future<void> sendPaymentNotification({
    required String userId,
    required String orderId,
    required double amount,
    required bool isSuccess,
  }) async {
    await sendNotification(
      userId: userId,
      title: isSuccess ? 'Payment Successful' : 'Payment Failed',
      body: isSuccess
          ? 'Your payment of ₹${amount.toStringAsFixed(2)} has been processed'
          : 'Payment of ₹${amount.toStringAsFixed(2)} failed. Please try again.',
      data: {
        'type': 'payment',
        'order_id': orderId,
        'amount': amount.toString(),
        'success': isSuccess.toString(),
      },
    );
  }

  /// Send booking confirmation notification
  Future<void> sendBookingConfirmation({
    required String userId,
    required String bookingId,
    required String serviceName,
    required DateTime bookingDate,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'Booking Confirmed',
      body: 'Your booking for $serviceName on ${bookingDate.toString().split(' ')[0]} has been confirmed',
      data: {
        'type': 'booking_confirmation',
        'booking_id': bookingId,
        'service_name': serviceName,
        'booking_date': bookingDate.toIso8601String(),
      },
    );
  }

  /// Send support message notification
  Future<void> sendSupportMessage({
    required String userId,
    required String ticketId,
    required String message,
  }) async {
    await sendNotification(
      userId: userId,
      title: 'New Support Message',
      body: message,
      data: {
        'type': 'support',
        'ticket_id': ticketId,
      },
    );
  }

  /// Send reminder notification
  Future<void> sendReminder({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      data: data ?? {'type': 'reminder'},
    );
  }
}
