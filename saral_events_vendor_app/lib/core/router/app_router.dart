import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/pre_auth_screen.dart';
import '../../features/vendor_setup/vendor_setup_flow.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/shell/main_navigation_scaffold.dart';
import '../../features/profile/business_details_screen.dart';
import '../../features/profile/documents_screen.dart';
import '../../features/wallet/wallet_screen.dart';

class AppRouter {
  static GoRouter create(AppSession session) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: session,
      routes: [
        GoRoute(
          path: '/',
          redirect: (ctx, state) {
            final s = Provider.of<AppSession>(ctx, listen: false);
            
            // Wait for session to be initialized
            if (!s.isInitialized) {
              print('Router: Session not initialized yet, staying on root');
              return null;
            }
            
            print('Router: Session initialized, checking state...');
            print('Router: isOnboardingComplete: ${s.isOnboardingComplete}');
            print('Router: isAuthenticated: ${s.isAuthenticated}');
            print('Router: isVendorSetupComplete: ${s.isVendorSetupComplete}');
            
            if (s.isPasswordRecovery) {
              print('Router: Redirecting to password reset');
              return '/auth/reset';
            }
            if (!s.isOnboardingComplete) {
              print('Router: Redirecting to onboarding');
              return '/onboarding';
            }
            if (!s.isAuthenticated) {
              print('Router: Redirecting to auth pre');
              return '/auth/pre';
            }
            if (!s.isVendorSetupComplete) {
              print('Router: Redirecting to vendor setup');
              return '/vendor/setup';
            }
            print('Router: Redirecting to app');
            return '/app';
          },
          builder: (ctx, st) {
            final s = Provider.of<AppSession>(ctx, listen: false);
            if (!s.isInitialized) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading...'),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: '/onboarding',
          redirect: (ctx, state) {
            final s = Provider.of<AppSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            return null;
          },
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/pre',
          builder: (_, __) => const PreAuthScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          redirect: (ctx, state) {
            final s = Provider.of<AppSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            return null;
          },
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          redirect: (ctx, state) {
            final s = Provider.of<AppSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            return null;
          },
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(path: '/auth/forgot', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/auth/reset', builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: '/vendor/setup', builder: (_, __) => const VendorSetupFlow()),
        GoRoute(path: '/app', builder: (_, __) => const MainNavigationScaffold()),
        GoRoute(path: '/app/business-details', builder: (_, __) => const BusinessDetailsScreen()),
        GoRoute(path: '/app/documents', builder: (_, __) => const DocumentsScreen()),
        GoRoute(path: '/app/wallet', builder: (_, __) => const WalletScreen()),
      ],
    );
  }
}


