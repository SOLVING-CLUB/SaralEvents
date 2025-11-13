import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'session.dart';
import '../screens/onboarding_screen.dart';
import '../screens/pre_auth_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/role_mismatch_screen.dart';
import '../screens/account_setup_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/main_navigation_scaffold.dart';
import '../screens/invitations_list_screen.dart';
import '../screens/invitation_editor_screen.dart';
import '../screens/invitation_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/select_location_screen.dart';
import '../screens/map_location_picker.dart';
import '../screens/all_categories_screen.dart';
import '../screens/all_events_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_details_screen.dart';
import '../screens/wallet_payments_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/accessibility_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/refer_earn_screen.dart';


class AppRouter {
  static GoRouter create(UserSession session) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: session,
      // Deep links are handled by AppLinkHandler, router just needs to support the routes
      redirect: (ctx, state) {
        final uri = state.uri;
        
        // Ignore custom scheme URIs - let AppLinkHandler handle them
        if (uri.scheme == 'saralevents' || uri.scheme == 'intent') {
          // AppLinkHandler will process these and navigate using context.go()
          return null;
        }
        
        // Handle auth redirects
        if (uri.scheme == 'saralevents' && uri.host == 'auth' && uri.path.contains('/confirm')) {
          final s = Provider.of<UserSession>(ctx, listen: false);
          return s.isAuthenticated ? '/auth/setup' : '/auth/login?verified=1';
        }
        return null;
      },
      errorBuilder: (context, state) {
        // Handle 404 errors gracefully
        return Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.toString() ?? 'The requested page could not be found.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => context.go('/app'),
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                ),
              ],
            ),
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (ctx, state) {
            final s = Provider.of<UserSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            // If authenticated, check setup then location
            if (s.isAuthenticated) {
              if (!s.isProfileSetupComplete) return '/auth/setup';
              return '/location/check';
            }
            // Only show onboarding for unauthenticated users who haven't completed it
            if (!s.isOnboardingComplete) return '/onboarding';
            return '/auth/pre';
          },
          builder: (ctx, st) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/location/check',
          redirect: (ctx, st) async {
            final prefs = await SharedPreferences.getInstance();
            final has = prefs.containsKey('loc_lat') && prefs.containsKey('loc_lng');
            return has ? '/app' : '/location/select';
          },
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/location/select',
          builder: (_, __) => const SelectLocationScreen(),
        ),
        GoRoute(
          path: '/location/map',
          builder: (_, __) => const MapLocationPicker(),
        ),
        GoRoute(
          path: '/onboarding',
          redirect: (ctx, state) {
            final s = Provider.of<UserSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            // If onboarding already completed, go to pre-auth
            if (s.isOnboardingComplete) return '/auth/pre';
            // Authenticated users should go to app
            if (s.isAuthenticated) return '/app';
            return null;
          },
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth/pre',
          builder: (_, __) => const PreAuthScreen(),
        ),
        GoRoute(
          path: '/auth/setup',
          builder: (_, __) => const AccountSetupScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          redirect: (ctx, state) {
            final s = Provider.of<UserSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            return null;
          },
          builder: (_, st) => LoginScreen(
            showVerifiedPrompt: st.uri.queryParameters['verified'] == '1' ||
                st.uri.queryParameters['from'] == 'verify',
          ),
        ),
        GoRoute(
          path: '/auth/register',
          redirect: (ctx, state) {
            final s = Provider.of<UserSession>(ctx, listen: false);
            if (s.isPasswordRecovery) return '/auth/reset';
            return null;
          },
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(path: '/auth/forgot', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/auth/reset', builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(path: '/auth/role-mismatch', builder: (_, __) => const RoleMismatchScreen()),
        GoRoute(path: '/debug', builder: (_, __) => const DebugScreen()),
        GoRoute(path: '/app', builder: (_, __) => const MainNavigationScaffold()),
        GoRoute(path: '/invites', builder: (_, __) => const InvitationsListScreen()),
        GoRoute(path: '/invites/new', builder: (_, __) => const InvitationEditorScreen()),
        GoRoute(
          path: '/invites/:slug',
          builder: (ctx, st) => InvitationPreviewScreen(slug: st.pathParameters['slug']!),
        ),
        // Support app-links from web path `/invite/:slug`
        GoRoute(
          path: '/invite/:slug',
          builder: (ctx, st) => InvitationPreviewScreen(slug: st.pathParameters['slug']!),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/profile/details', builder: (_, __) => const ProfileDetailsScreen()),
        GoRoute(path: '/profile/wallet', builder: (_, __) => const WalletPaymentsScreen()),
        GoRoute(path: '/profile/help', builder: (_, __) => const HelpSupportScreen()),
        GoRoute(path: '/profile/accessibility', builder: (_, __) => const AccessibilityScreen()),
        GoRoute(path: '/profile/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
          path: '/profile/refer',
          builder: (_, state) => ReferEarnScreen(initialReferralCode: state.uri.queryParameters['code']),
        ),
        GoRoute(
          path: '/categories',
          builder: (_, __) => const AllCategoriesScreen(),
        ),
        GoRoute(
          path: '/events',
          builder: (_, __) => const AllEventsScreen(),
        ),
      ],
    );
  }
}
