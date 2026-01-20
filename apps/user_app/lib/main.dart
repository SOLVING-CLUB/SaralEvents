import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/supabase/supabase_config.dart';
import 'core/session.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'core/widgets/permission_manager.dart';
import 'screens/app_link_handler.dart';
import 'checkout/checkout_state.dart';
import 'core/services/address_storage.dart';
import 'services/push_notification_service.dart';

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

  // Reset location check flag on app startup
  // This ensures the bottom sheet only shows once per app session
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('location_checked_this_session', false);
  
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

        return MaterialApp.router(
          title: 'Saral Events',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          routerConfig: AppRouter.create(session),
          builder: (context, child) => PermissionManager(
            child: AppLinkHandler(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
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
