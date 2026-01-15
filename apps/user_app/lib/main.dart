import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase/supabase_config.dart';
import 'core/session.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/permission_manager.dart';
import 'screens/app_link_handler.dart';
import 'checkout/checkout_state.dart';
import 'core/services/address_storage.dart';
//test

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserSession()),
        // Global checkout/cart state available throughout the app
        ChangeNotifierProvider(create: (_) => CheckoutState()),
      ],
      child: Consumer<UserSession>(
        builder: (context, session, _) {
          return MaterialApp.router(
            title: 'Saral Events',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.create(session),
            builder: (context, child) => PermissionManager(
              child: AppLinkHandler(child: child ?? const SizedBox.shrink()),
            ),
          );
        },
      ),
    );
  }
}
