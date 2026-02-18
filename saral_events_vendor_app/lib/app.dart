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
  late final AppSession _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Important: keep a single AppSession + GoRouter instance for the lifetime of the app.
    // Recreating GoRouter on every rebuild can reset navigation to the initial location ('/'),
    // which looks like "redirecting back to the first page".
    _session = AppSession();
    _router = AppRouter.create(_session);
  }

  @override
  void dispose() {
    _pushNotificationService?.unregisterToken();
    _pushNotificationService = null;
    _session.dispose();
    super.dispose();
  }

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
    return ChangeNotifierProvider.value(
      value: _session,
      child: Builder(
        builder: (context) {
          final session = context.watch<AppSession>();

          // Initialize push notifications when authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializePushNotifications(session, _router);
          });

          return DeepLinkListener(
            child: MaterialApp.router(
              title: 'SaralEvents Vendor App',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}


