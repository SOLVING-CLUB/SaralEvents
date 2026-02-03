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
    // Convert event_code or notification type to camelCase for enum matching
    String snakeToCamel(String snake) {
      final parts = snake.split('_');
      if (parts.isEmpty) return snake;
      return parts[0] + parts.sublist(1).map((p) {
        if (p.isEmpty) return p;
        return p[0].toUpperCase() + p.substring(1);
      }).join();
    }

    // Support both old order_notifications table and new notifications table
    final notificationTypeStr = map['notification_type']?.toString() ?? 
                                map['metadata']?['type']?.toString() ?? 
                                'bookingCreated';
    final camelCaseType = snakeToCamel(notificationTypeStr);

    return OrderNotification(
      id: map['notification_id']?.toString() ?? map['id'].toString(),
      bookingId: map['booking_id']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      userId: map['recipient_user_id']?.toString() ?? map['user_id'].toString(),
      type: OrderNotificationType.values.firstWhere(
        (e) => e.name == camelCaseType,
        orElse: () => OrderNotificationType.bookingCreated,
      ),
      title: map['title'] as String,
      message: map['body'] as String? ?? map['message'] as String,
      isRead: map['read_at'] != null || (map['is_read'] as bool? ?? false),
      actionUrl: map['metadata']?['deep_link']?.toString() ?? map['action_url']?.toString(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class OrderNotificationService {
  final SupabaseClient _supabase;

  OrderNotificationService(this._supabase);


  /// Create a notification
  /// NOTE: This method is deprecated. Notifications are now created automatically by database triggers.
  /// This method is kept for backward compatibility but should not be used for new code.
  @Deprecated('Use database triggers or RPC functions instead. Notifications are now handled automatically.')
  Future<bool> createNotification({
    required String bookingId,
    required String userId,
    required OrderNotificationType type,
    required String title,
    required String message,
    String? orderId,
    String? actionUrl,
  }) async {
    // Notifications are now handled automatically by database triggers
    // This method is kept for backward compatibility only
    print('Warning: createNotification() is deprecated. Notifications are now handled automatically.');
    return true;
  }

  /// Get unread notifications for user
  Future<List<OrderNotification>> getUnreadNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Read from new notifications table
      final result = await _supabase
          .from('notifications')
          .select('*')
          .eq('recipient_role', 'USER')
          .eq('recipient_user_id', userId)
          .isFilter('read_at', null)
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

      // Read from new notifications table
      final result = await _supabase
          .from('notifications')
          .select('*')
          .eq('recipient_role', 'USER')
          .eq('recipient_user_id', userId)
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
      // Update new notifications table
      await _supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('notification_id', notificationId);
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

      // Update new notifications table
      await _supabase
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('recipient_role', 'USER')
          .eq('recipient_user_id', userId)
          .isFilter('read_at', null);
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get notification count (with 24-hour filtering)
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getFilteredNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      print('Error getting notification count: $e');
      return 0;
    }
  }

  /// Get filtered notifications based on 24-hour rule and special cases
  /// - Regular notifications expire after 24 hours
  /// - vendor_arrived and setup_completed stay active until user confirms
  Future<List<OrderNotification>> getFilteredNotifications({int limit = 50}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get all notifications from new notifications table
      final result = await _supabase
          .from('notifications')
          .select('*')
          .eq('recipient_role', 'USER')
          .eq('recipient_user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit * 2); // Get more to filter

      final allNotifications = (result as List<dynamic>)
          .map((row) => OrderNotification.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      // Filter notifications
      final now = DateTime.now();
      final filteredNotifications = <OrderNotification>[];

      for (final notification in allNotifications) {
        final hoursSinceCreation = now.difference(notification.createdAt).inHours;
        
        // Special handling for vendor_arrived and setup_completed
        if (notification.type == OrderNotificationType.vendorArrived ||
            notification.type == OrderNotificationType.setupCompleted) {
          // Check if user has confirmed (by checking booking milestone_status)
          final isConfirmed = await _isNotificationConfirmed(notification);
          
          if (isConfirmed) {
            // If confirmed, apply 24-hour rule
            if (hoursSinceCreation < 24) {
              filteredNotifications.add(notification);
            }
          } else {
            // If not confirmed, keep it active regardless of time
            filteredNotifications.add(notification);
          }
        } else {
          // Regular notifications: expire after 24 hours
          if (hoursSinceCreation < 24) {
            filteredNotifications.add(notification);
          }
        }

        // Limit results
        if (filteredNotifications.length >= limit) break;
      }

      return filteredNotifications;
    } catch (e) {
      print('Error fetching filtered notifications: $e');
      return [];
    }
  }

  /// Check if a vendor_arrived or setup_completed notification has been confirmed
  Future<bool> _isNotificationConfirmed(OrderNotification notification) async {
    try {
      final bookingResult = await _supabase
          .from('bookings')
          .select('milestone_status')
          .eq('id', notification.bookingId)
          .maybeSingle();

      if (bookingResult == null) return false;

      final milestoneStatus = bookingResult['milestone_status'] as String?;

      if (notification.type == OrderNotificationType.vendorArrived) {
        // Vendor arrived is confirmed when milestone_status is 'arrival_confirmed' or later
        return milestoneStatus == 'arrival_confirmed' ||
            milestoneStatus == 'setup_completed' ||
            milestoneStatus == 'setup_confirmed' ||
            milestoneStatus == 'completed';
      } else if (notification.type == OrderNotificationType.setupCompleted) {
        // Setup completed is confirmed when milestone_status is 'setup_confirmed' or later
        return milestoneStatus == 'setup_confirmed' ||
            milestoneStatus == 'completed';
      }

      return false;
    } catch (e) {
      print('Error checking notification confirmation: $e');
      return false;
    }
  }

  /// Create milestone-specific notifications
  /// NOTE: This method is deprecated. Notifications are now created automatically by database triggers.
  @Deprecated('Use database triggers or RPC functions instead. Notifications are now handled automatically.')
  Future<void> notifyMilestoneUpdate({
    required String bookingId,
    required String userId,
    required String milestoneStatus,
    String? orderId,
  }) async {
    // Notifications are now handled automatically by database triggers
    // This method is kept for backward compatibility only
    print('Warning: notifyMilestoneUpdate() is deprecated. Notifications are now handled automatically.');
  }
}


