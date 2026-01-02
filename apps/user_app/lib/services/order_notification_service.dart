import 'package:supabase_flutter/supabase_flutter.dart';

enum OrderNotificationType {
  bookingCreated,
  vendorAccepted,
  vendorTraveling,
  vendorArrived,
  paymentDueArrival,
  arrivalConfirmed,
  setupCompleted,
  paymentDueCompletion,
  setupConfirmed,
  paymentReleased,
  bookingCompleted,
  bookingCancelled,
}

class OrderNotification {
  final String id;
  final String bookingId;
  final String? orderId;
  final String userId;
  final OrderNotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final String? actionUrl;
  final DateTime createdAt;

  OrderNotification({
    required this.id,
    required this.bookingId,
    this.orderId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.actionUrl,
    required this.createdAt,
  });

  factory OrderNotification.fromMap(Map<String, dynamic> map) {
    return OrderNotification(
      id: map['id'].toString(),
      bookingId: map['booking_id'].toString(),
      orderId: map['order_id']?.toString(),
      userId: map['user_id'].toString(),
      type: OrderNotificationType.values.firstWhere(
        (e) => e.name == map['notification_type'].toString().replaceAll('_', ''),
        orElse: () => OrderNotificationType.bookingCreated,
      ),
      title: map['title'] as String,
      message: map['message'] as String,
      isRead: map['is_read'] as bool? ?? false,
      actionUrl: map['action_url']?.toString(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class OrderNotificationService {
  final SupabaseClient _supabase;

  OrderNotificationService(this._supabase);

  /// Create a notification
  Future<bool> createNotification({
    required String bookingId,
    required String userId,
    required OrderNotificationType type,
    required String title,
    required String message,
    String? orderId,
    String? actionUrl,
  }) async {
    try {
      await _supabase.from('order_notifications').insert({
        'booking_id': bookingId,
        'order_id': orderId,
        'user_id': userId,
        'notification_type': type.name,
        'title': title,
        'message': message,
        'action_url': actionUrl,
        'is_read': false,
      });
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  /// Get unread notifications for user
  Future<List<OrderNotification>> getUnreadNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase
          .from('order_notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return (result as List<dynamic>)
          .map((row) => OrderNotification.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Get all notifications for user
  Future<List<OrderNotification>> getAllNotifications({int limit = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase
          .from('order_notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (result as List<dynamic>)
          .map((row) => OrderNotification.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('order_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('order_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get notification count
  Future<int> getUnreadCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final result = await _supabase
          .from('order_notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', userId)
          .eq('is_read', false);

      return result.count ?? 0;
    } catch (e) {
      print('Error getting notification count: $e');
      return 0;
    }
  }

  /// Create milestone-specific notifications
  Future<void> notifyMilestoneUpdate({
    required String bookingId,
    required String userId,
    required String milestoneStatus,
    String? orderId,
  }) async {
    String title;
    String message;
    OrderNotificationType type;

    switch (milestoneStatus) {
      case 'accepted':
        title = 'Vendor Accepted Your Booking';
        message = 'Great news! The vendor has accepted your booking request.';
        type = OrderNotificationType.vendorAccepted;
        break;
      case 'vendor_traveling':
        title = 'Vendor is On the Way';
        message = 'The vendor has started traveling to your location.';
        type = OrderNotificationType.vendorTraveling;
        break;
      case 'vendor_arrived':
        title = 'Vendor Has Arrived';
        message = 'The vendor has arrived at your location. Please confirm their arrival.';
        type = OrderNotificationType.vendorArrived;
        break;
      case 'arrival_confirmed':
        title = 'Arrival Confirmed';
        message = 'You confirmed the vendor\'s arrival. Payment for 50% milestone is now due.';
        type = OrderNotificationType.arrivalConfirmed;
        break;
      case 'setup_completed':
        title = 'Setup Completed';
        message = 'The vendor has completed the setup. Please confirm to proceed with final payment.';
        type = OrderNotificationType.setupCompleted;
        break;
      case 'setup_confirmed':
        title = 'Setup Confirmed';
        message = 'You confirmed the setup completion. Final payment milestone will be processed.';
        type = OrderNotificationType.setupConfirmed;
        break;
      case 'completed':
        title = 'Order Completed';
        message = 'Congratulations! Your order has been completed successfully.';
        type = OrderNotificationType.bookingCompleted;
        break;
      default:
        return;
    }

    await createNotification(
      bookingId: bookingId,
      userId: userId,
      type: type,
      title: title,
      message: message,
      orderId: orderId,
      actionUrl: '/order-tracking/$bookingId',
    );
  }
}

