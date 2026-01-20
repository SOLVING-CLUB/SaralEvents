import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// Service to manage Firebase Cloud Messaging (FCM) push notifications
class PushNotificationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  String? _currentToken;
  bool _isInitialized = false;

  PushNotificationService(this._supabase)
      : _firebaseMessaging = FirebaseMessaging.instance,
        _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize FCM and register token
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ PushNotificationService: Already initialized');
      return;
    }

    try {
      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📱 PushNotificationService: Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        await _registerToken();

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 PushNotificationService: Token refreshed');
          _registerTokenInDatabase(newToken);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background messages (when app is in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleBackgroundMessage(initialMessage);
        }

        _isInitialized = true;
        debugPrint('✅ PushNotificationService: Initialized successfully');
      } else {
        debugPrint('❌ PushNotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('❌ PushNotificationService: Initialization error: $e');
    }
  }

  /// Initialize local notifications plugin
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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📬 Local notification tapped: ${response.payload}');
        // Handle notification tap if needed
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // name
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    debugPrint('✅ Local notifications initialized');
  }

  /// Register FCM token with Supabase
  Future<void> _registerToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('📱 PushNotificationService: FCM Token: ${token.substring(0, 20)}...');
        await _registerTokenInDatabase(token);
      }
    } catch (e) {
      debugPrint('❌ PushNotificationService: Error getting token: $e');
    }
  }

  /// Register token in Supabase database
  Future<void> _registerTokenInDatabase(String token) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ PushNotificationService: No user logged in, skipping token registration');
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
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      ).select();

      debugPrint('✅ PushNotificationService: Token registered in database');
    } catch (e) {
      debugPrint('❌ PushNotificationService: Error registering token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 PushNotificationService: Foreground message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Show local notification when app is in foreground
    // FCM doesn't automatically show notifications when app is open
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: data?.toString(),
    );

    debugPrint('✅ Local notification displayed: $title');
  }

  /// Handle background messages (when app is in background or terminated)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📬 PushNotificationService: Background message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Handle navigation based on notification data
    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'order_update':
        // Navigate to order details
        debugPrint('   → Navigate to order: ${data['order_id']}');
        break;
      case 'payment':
        // Navigate to payment/order
        debugPrint('   → Navigate to payment: ${data['order_id']}');
        break;
      case 'support':
        // Navigate to support/chat
        debugPrint('   → Navigate to support');
        break;
      default:
        debugPrint('   → Unknown notification type: $type');
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

          debugPrint('✅ PushNotificationService: Token unregistered');
        }
      }
      _currentToken = null;
    } catch (e) {
      debugPrint('❌ PushNotificationService: Error unregistering token: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;
}

/// Top-level function to handle background messages
/// Must be top-level (not a class method) for Flutter
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message handler: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');
  
  // Initialize Supabase if needed
  // Note: Supabase should already be initialized in main.dart
}
