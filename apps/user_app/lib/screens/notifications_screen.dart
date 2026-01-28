import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/order_notification_service.dart';
import 'order_status_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final OrderNotificationService _notificationService =
      OrderNotificationService(Supabase.instance.client);
  List<OrderNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _notificationService.getFilteredNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(OrderNotification notification) async {
    if (notification.isRead) return;

    final success = await _notificationService.markAsRead(notification.id);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = OrderNotification(
            id: notification.id,
            bookingId: notification.bookingId,
            orderId: notification.orderId,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            isRead: true,
            actionUrl: notification.actionUrl,
            createdAt: notification.createdAt,
          );
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _notificationService.markAllAsRead();
    if (success) {
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    }
  }

  void _handleNotificationTap(OrderNotification notification) {
    // Mark as read
    _markAsRead(notification);

    // Navigate to order status screen
    if (notification.bookingId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderStatusScreen(
            bookingId: notification.bookingId,
            orderId: notification.orderId,
          ),
        ),
      );
    }
  }

  IconData _getNotificationIcon(OrderNotificationType type) {
    switch (type) {
      case OrderNotificationType.vendorArrived:
      case OrderNotificationType.setupCompleted:
        return Icons.notifications_active;
      case OrderNotificationType.bookingCreated:
      case OrderNotificationType.vendorAccepted:
        return Icons.check_circle;
      case OrderNotificationType.paymentDueArrival:
      case OrderNotificationType.paymentDueCompletion:
      case OrderNotificationType.paymentReleased:
        return Icons.payment;
      case OrderNotificationType.bookingCompleted:
        return Icons.celebration;
      case OrderNotificationType.bookingCancelled:
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(OrderNotificationType type) {
    switch (type) {
      case OrderNotificationType.vendorArrived:
      case OrderNotificationType.setupCompleted:
        return Colors.orange;
      case OrderNotificationType.bookingCreated:
      case OrderNotificationType.vendorAccepted:
        return Colors.green;
      case OrderNotificationType.paymentDueArrival:
      case OrderNotificationType.paymentDueCompletion:
        return Colors.blue;
      case OrderNotificationType.bookingCompleted:
        return Colors.purple;
      case OrderNotificationType.bookingCancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 20),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading notifications',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'re all caught up!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isUnread = !notification.isRead;
                          final iconColor = _getNotificationColor(notification.type);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isUnread ? 2 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isUnread
                                  ? BorderSide(
                                      color: iconColor.withOpacity(0.3), width: 1)
                                  : BorderSide.none,
                            ),
                            child: InkWell(
                              onTap: () => _handleNotificationTap(notification),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(notification.type),
                                        color: iconColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notification.title,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: isUnread
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              if (isUnread)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: iconColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notification.message,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _getTimeAgo(notification.createdAt),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
