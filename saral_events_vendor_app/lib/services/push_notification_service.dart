import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

/// Service to manage Firebase Cloud Messaging (FCM) push notifications for Vendor App
class PushNotificationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _isInitialized = false;
  GoRouter? _router;
  // Track recent messages to avoid showing duplicates in quick succession
  final Map<String, DateTime> _recentMessageKeys = {};

  PushNotificationService(this._supabase)
      : _firebaseMessaging = FirebaseMessaging.instance;

  /// Set router for navigation
  void setRouter(GoRouter router) {
    _router = router;
  }

  /// Initialize FCM and register token
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ [Vendor] PushNotificationService: Already initialized');
      return;
    }

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📱 [Vendor] PushNotificationService: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        await _registerToken();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 [Vendor] PushNotificationService: Token refreshed');
          _registerTokenInDatabase(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        // Set up notification channel for Android
        if (Platform.isAndroid) {
          await _firebaseMessaging.setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        }

        _isInitialized = true;
        debugPrint('✅ [Vendor] PushNotificationService: Initialized successfully');
      } else {
        debugPrint('❌ [Vendor] PushNotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('❌ [Vendor] PushNotificationService: Initialization error: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        if (details.payload != null) {
          _handleNotificationPayload(details.payload!);
        }
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'vendor_notifications',
        'Vendor Notifications',
        description: 'Notifications for orders, payments, and updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Register FCM token with Supabase
  Future<void> _registerToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('📱 [Vendor] PushNotificationService: FCM Token: ${token.substring(0, 20)}...');
        await _registerTokenInDatabase(token);
      }
    } catch (e) {
      debugPrint('❌ [Vendor] PushNotificationService: Error getting token: $e');
    }
  }

  /// Register token in Supabase database
  Future<void> _registerTokenInDatabase(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [Vendor] PushNotificationService: No user logged in, skipping token registration');
        return;
      }

      // Get vendor ID
      final vendorResult = await _supabase
          .from('vendor_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (vendorResult == null) {
        debugPrint('⚠️ [Vendor] PushNotificationService: No vendor profile found');
        return;
      }

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceType = 'unknown';
      String? deviceId;

      if (Platform.isAndroid) {
        deviceType = 'android';
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      }

      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // Upsert token (update if exists, insert if new)
      await _supabase
          .from('fcm_tokens')
          .upsert(
        {
          'user_id': user.id,
          'token': token,
          'device_type': deviceType,
          'device_id': deviceId,
          'app_version': appVersion,
          'app_type': 'vendor_app',
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );

      debugPrint('✅ [Vendor] PushNotificationService: Token registered in database');
    } catch (e) {
      debugPrint('❌ [Vendor] PushNotificationService: Error registering token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 [Vendor] PushNotificationService: Foreground message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Drop duplicates that arrive within a short window
    if (_isDuplicateMessage(message)) {
      debugPrint('⚠️ [Vendor] PushNotificationService: Dropping duplicate notification');
      return;
    }

    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
      data: message.data,
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vendor_notifications',
      'Vendor Notifications',
      channelDescription: 'Notifications for orders, payments, and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap (when app is in background or terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📬 [Vendor] PushNotificationService: Notification tapped');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    _handleNotificationData(message.data);
  }

  /// Handle notification payload (from local notification tap)
  void _handleNotificationPayload(String payload) {
    // Parse payload if it's JSON
    try {
      // For now, payload is just a string representation of data
      // In a real implementation, you'd parse it properly
      debugPrint('📬 [Vendor] PushNotificationService: Local notification tapped');
    } catch (e) {
      debugPrint('❌ [Vendor] PushNotificationService: Error parsing payload: $e');
    }
  }

  /// Handle notification data and navigate
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final bookingId = data['booking_id'] as String?;
    final orderId = data['order_id'] as String?;

    if (_router == null) {
      debugPrint('⚠️ [Vendor] PushNotificationService: Router not set, cannot navigate');
      return;
    }

    // Ensure we're on the app route first
    _router!.go('/app');

    switch (type) {
      case 'booking_request':
      case 'booking_update':
      case 'order_update':
        if (bookingId != null) {
          debugPrint('   → Navigate to booking: $bookingId');
          // Navigate to order details page
          Future.delayed(const Duration(milliseconds: 800), () {
            _router!.push('/app/orders/$bookingId');
          });
        } else if (orderId != null) {
          debugPrint('   → Navigate to order: $orderId');
          Future.delayed(const Duration(milliseconds: 800), () {
            _router!.push('/app/orders/$orderId');
          });
        } else {
          // Navigate to orders tab (index 1)
          debugPrint('   → Navigate to orders tab');
        }
        break;

      case 'payment_milestone':
      case 'payment_released':
      case 'payment':
        debugPrint('   → Navigate to wallet');
        // Wallet is accessible via /app route, tab index 2
        // User will see the wallet tab when they open the app
        break;

      case 'withdrawal_approved':
      case 'withdrawal_rejected':
        debugPrint('   → Navigate to wallet');
        // Wallet tab will show withdrawal status
        break;

      case 'support':
      case 'chat':
        debugPrint('   → Navigate to support');
        // Support/chat functionality
        break;

      default:
        debugPrint('   → Unknown notification type: $type');
        // Stay on home
    }
  }

  /// Unregister token (call on logout)
  Future<void> unregisterToken() async {
    try {
      if (_currentToken != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase
              .from('fcm_tokens')
              .update({'is_active': false})
              .eq('token', _currentToken!)
              .eq('user_id', user.id);

          debugPrint('✅ [Vendor] PushNotificationService: Token unregistered');
        }
      }
      _currentToken = null;
      _isInitialized = false;
    } catch (e) {
      debugPrint('❌ [Vendor] PushNotificationService: Error unregistering token: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Check for duplicate notifications within a 30s window
  bool _isDuplicateMessage(RemoteMessage message) {
    final now = DateTime.now();
    // Build a stable key using messageId if present; otherwise title/body/data
    final key = message.messageId ??
        '${message.notification?.title ?? ''}|${message.notification?.body ?? ''}|${message.data}';

    // Prune old entries (>30s) to keep the map small
    _recentMessageKeys.removeWhere((_, ts) => now.difference(ts) > const Duration(seconds: 30));

    final lastSeen = _recentMessageKeys[key];
    final isDup = lastSeen != null && now.difference(lastSeen) < const Duration(seconds: 30);
    _recentMessageKeys[key] = now;
    return isDup;
  }
}

/// Top-level function to handle background messages
/// Must be top-level (not a class method) for Flutter
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 [Vendor] Background message handler: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');
  
  // Initialize Supabase if needed
  // Note: Supabase should already be initialized in main.dart
}
