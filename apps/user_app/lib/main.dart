import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/supabase/supabase_config.dart';
import 'core/session.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/permission_manager.dart';
import 'screens/app_link_handler.dart';
//test

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserSession(),
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
