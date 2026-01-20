import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/state/session.dart';
import 'core/router/app_router.dart';
import 'core/deeplink/deeplink_listener.dart';
import 'services/push_notification_service.dart';

class SaralEventsApp extends StatefulWidget {
  const SaralEventsApp({super.key});

  @override
  State<SaralEventsApp> createState() => _SaralEventsAppState();
}

class _SaralEventsAppState extends State<SaralEventsApp> {
  PushNotificationService? _pushNotificationService;

  void _initializePushNotifications(AppSession session, GoRouter router) {
    if (session.isAuthenticated && _pushNotificationService == null) {
      try {
        _pushNotificationService = PushNotificationService(Supabase.instance.client);
        _pushNotificationService?.setRouter(router);
        _pushNotificationService?.initialize();
      } catch (e) {
        debugPrint('⚠️ [Vendor] Error initializing push notifications: $e');
      }
    } else if (!session.isAuthenticated && _pushNotificationService != null) {
      // Unregister token when user logs out
      _pushNotificationService?.unregisterToken();
      _pushNotificationService = null;
    } else if (session.isAuthenticated && _pushNotificationService != null) {
      // Update router reference if it changed
      _pushNotificationService?.setRouter(router);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppSession(),
      builder: (context, _) {
        final session = context.watch<AppSession>();
        final router = AppRouter.create(session);
        
        // Initialize push notifications when authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializePushNotifications(session, router);
        });
        
        return DeepLinkListener(
          child: MaterialApp.router(
            title: 'SaralEvents Vendor App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        );
      },
    );
  }
}


