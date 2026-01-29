import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'core/supabase/supabase_config.dart';
import 'core/session.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/widgets/permission_manager.dart';
import 'screens/app_link_handler.dart';
import 'checkout/checkout_state.dart';
import 'core/services/address_storage.dart';
import 'core/services/location_session_manager.dart';
import 'services/push_notification_service.dart';
import 'screens/order_status_screen.dart';

// Top-level background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message handler: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
    debugPrint('   Push notifications may not work. Check google-services.json configuration.');
  }
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Reset location session flags on app startup (cold start)
  // This ensures proper location handling on each app launch
  await LocationSessionManager.resetSessionFlags();
  
  // Clear temporary location on app start (session-only locations reset)
  // Saved addresses remain intact
  await AddressStorage.clearTemporaryLocation();

  runApp(const UserApp());
}

class _AppWithNotifications extends StatefulWidget {
  const _AppWithNotifications();

  @override
  State<_AppWithNotifications> createState() => _AppWithNotificationsState();
}

class _AppWithNotificationsState extends State<_AppWithNotifications> {
  PushNotificationService? _pushNotificationService;
  bool _navigationCallbackSet = false;
  GoRouter? _currentRouter;

  @override
  void initState() {
    super.initState();
    // Initialize push notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Provider.of<UserSession>(context, listen: false);
      if (session.isAuthenticated) {
        _initializePushNotifications();
      }
    });
  }

  void _initializePushNotifications() {
    try {
      _pushNotificationService = PushNotificationService(Supabase.instance.client);
      _pushNotificationService?.initialize();
    } catch (e) {
      debugPrint('⚠️ Error initializing push notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<UserSession, ThemeNotifier, CheckoutState>(
      builder: (context, session, themeNotifier, checkoutState, _) {
        // Initialize push notifications when user logs in
        if (session.isAuthenticated && _pushNotificationService == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializePushNotifications();
          });
        } else if (!session.isAuthenticated && _pushNotificationService != null) {
          // Unregister token when user logs out
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pushNotificationService?.unregisterToken();
            _pushNotificationService = null;
          });
        }

        // Initialize cart when user is authenticated
        if (session.isAuthenticated && !checkoutState.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkoutState.initialize();
          });
        } else if (!session.isAuthenticated && checkoutState.isInitialized) {
          // Clear cart when user logs out
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkoutState.clearAndDispose();
          });
        }

        // Create router instance once (reuse if session hasn't changed)
        final router = AppRouter.create(session);
        _currentRouter = router;

        // Set navigation callback for push notification service (only once)
        if (_pushNotificationService != null && !_navigationCallbackSet) {
          _navigationCallbackSet = true;
          debugPrint('✅ Setting navigation callback for push notifications');
          
          _pushNotificationService!.setNavigationCallback((data) {
            // Handle navigation based on notification data
            debugPrint('🔗 Notification navigation callback called');
            debugPrint('   Data: $data');
            
            // Use a delayed callback to ensure the widget tree is built
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Use the current router instance
              final navRouter = _currentRouter ?? router;
              final navContext = navRouter.routerDelegate.navigatorKey.currentContext;
              
              if (navContext == null) {
                debugPrint('⚠️ Cannot navigate: Context not available, retrying...');
                // Retry after a short delay
                Future.delayed(const Duration(milliseconds: 500), () {
                  final retryContext = navRouter.routerDelegate.navigatorKey.currentContext;
                  if (retryContext != null) {
                    _performNavigation(retryContext, data);
                  } else {
                    debugPrint('❌ Cannot navigate: Context still not available after retry');
                    // One more retry with longer delay
                    Future.delayed(const Duration(milliseconds: 1000), () {
                      final finalContext = navRouter.routerDelegate.navigatorKey.currentContext;
                      if (finalContext != null) {
                        _performNavigation(finalContext, data);
                      } else {
                        debugPrint('❌ Cannot navigate: Context not available after multiple retries');
                      }
                    });
                  }
                });
                return;
              }

              _performNavigation(navContext, data);
            });
          });
        }

        return MaterialApp.router(
          title: 'Saral Events',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          routerConfig: router,
          builder: (context, child) => PermissionManager(
            child: AppLinkHandler(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }

  /// Perform navigation based on notification data
  void _performNavigation(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    debugPrint('🔗 Handling notification navigation: type=$type');
    debugPrint('   Full data: $data');

    // Extract booking_id and order_id (check multiple possible field names)
    final bookingId = data['booking_id'] as String? ?? 
                     data['bookingId'] as String?;
    final orderId = data['order_id'] as String? ?? 
                   data['orderId'] as String?;
    final milestoneStatus = data['milestone_status'] as String?;

    debugPrint('   Extracted: bookingId=$bookingId, orderId=$orderId, milestoneStatus=$milestoneStatus');

    // Handle booking_update type (from vendor app)
    if (type == 'booking_update') {
      if (bookingId != null) {
        debugPrint('   → Navigating to Order Status (booking_update): bookingId=$bookingId, milestoneStatus=$milestoneStatus');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => OrderStatusScreen(bookingId: bookingId),
          ),
        );
        return;
      } else {
        debugPrint('   ❌ booking_update type but no bookingId found');
      }
    }

    switch (type) {
      // Order-related notifications
      case 'order_placed':
      case 'order_update':
      case 'booking_confirmation':
        if (bookingId != null || orderId != null) {
          debugPrint('   → Navigating to Order Status: bookingId=$bookingId, orderId=$orderId');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderStatusScreen(
                bookingId: bookingId,
                orderId: orderId,
              ),
            ),
          );
        } else {
          debugPrint('   ❌ No bookingId or orderId found for $type');
        }
        break;

      // Payment notifications
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
      case 'milestone_payment_success':
      case 'milestone_payment_failed':
        if (bookingId != null || orderId != null) {
          debugPrint('   → Navigating to Order Status (payment): bookingId=$bookingId, orderId=$orderId');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderStatusScreen(
                bookingId: bookingId,
                orderId: orderId,
              ),
            ),
          );
        } else {
          debugPrint('   ❌ No bookingId or orderId found for payment notification');
        }
        break;

      // Vendor action notifications (explicit types)
      case 'vendor_accepted':
      case 'vendor_arrived':
      case 'setup_completed':
      case 'booking_cancelled':
      case 'vendor_cancelled':
        if (bookingId != null) {
          debugPrint('   → Navigating to Order Status (vendor action): bookingId=$bookingId');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderStatusScreen(bookingId: bookingId),
            ),
          );
        } else {
          debugPrint('   ❌ No bookingId found for vendor action: $type');
        }
        break;

      // Support notifications
      case 'support':
        debugPrint('   → Navigating to Support');
        context.go('/support');
        break;

      // Refund notifications
      case 'refund_processed':
      case 'refund_completed':
        if (bookingId != null) {
          debugPrint('   → Navigating to Refund Details: bookingId=$bookingId');
          context.go('/orders/refund/$bookingId');
        } else {
          debugPrint('   ❌ No bookingId found for refund notification');
        }
        break;

      default:
        debugPrint('   → Unknown notification type: $type');
        // Fallback: Try to navigate to order status if booking_id exists
        if (bookingId != null || orderId != null) {
          debugPrint('   → Fallback navigation to Order Status: bookingId=$bookingId, orderId=$orderId');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderStatusScreen(
                bookingId: bookingId,
                orderId: orderId,
              ),
            ),
          );
        } else {
          debugPrint('   ❌ Cannot navigate: No booking_id or order_id found in notification data');
          debugPrint('   Available keys: ${data.keys.toList()}');
        }
    }
  }
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserSession()),
        // Global checkout/cart state available throughout the app
        ChangeNotifierProvider(create: (_) => CheckoutState()),
        // Theme notifier for dark mode
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: const _AppWithNotifications(),
    );
  }
}
