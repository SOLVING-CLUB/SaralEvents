import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

class AppLinkHandler extends StatefulWidget {
  final Widget child;

  const AppLinkHandler({super.key, required this.child});

  @override
  State<AppLinkHandler> createState() => _AppLinkHandlerState();
}

class _AppLinkHandlerState extends State<AppLinkHandler> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  void _initAppLinks() {
    _appLinks = AppLinks();
    
    // Handle initial link (when app is opened from a link - cold start)
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        print('🔗 Initial link (cold start): $uri');
        // Wait longer for cold start to ensure router is ready
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _handleLink(uri);
                }
              });
            });
          }
        });
      }
    });

    // Listen to incoming app links (when app is already running - warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('🔗 Incoming link (warm start): $uri');
        _handleLink(uri);
      },
      onError: (err) {
        print('❌ App link error: $err');
      },
    );
  }

  void _handleLink(Uri uri) {
    if (!mounted) return;
    
    print('🔗 Processing: ${uri.toString()}');
    print('   Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}, Segments: ${uri.pathSegments}');

    // Wait for router to be ready, then navigate
    void navigateAfterDelay(String route) {
      print('🔗 Preparing to navigate to: $route');
      // Use multiple callbacks to ensure router is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) {
            print('⚠️ Widget not mounted, skipping navigation');
            return;
          }
          try {
            print('🔗 Navigating to: $route');
            // Ensure we're navigating to a valid path (starts with /)
            final path = route.startsWith('/') ? route : '/$route';
            context.go(path);
            print('✅ Navigation successful to: $path');
          } catch (e, stackTrace) {
            print('❌ Navigation error: $e');
            print('Stack trace: $stackTrace');
            // Fallback: try again after delay
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                try {
                  final path = route.startsWith('/') ? route : '/$route';
                  print('🔗 Retrying navigation to: $path');
                  context.go(path);
                } catch (e2) {
                  print('❌ Fallback navigation also failed: $e2');
                  // Last resort: try to go to app home
                  try {
                    context.go('/app');
                  } catch (e3) {
                    print('❌ Even home navigation failed: $e3');
                  }
                }
              }
            });
          }
        });
      });
    }

    // Email confirmation
    if (uri.path.contains('/auth/confirm') || (uri.scheme == 'saralevents' && uri.host == 'auth')) {
      navigateAfterDelay('/auth/setup');
      return;
    }

    // Invitation links: https://saralevents.vercel.app/invite/:slug or saralevents://invite/:slug
    String? invitationSlug;
    
    // Handle https://saralevents.vercel.app/invite/:slug (universal link)
    if (uri.scheme == 'https' && uri.host.contains('saralevents') && uri.path.contains('/invite/')) {
      final segments = uri.pathSegments;
      final slugIndex = segments.indexOf('invite');
      if (slugIndex >= 0 && slugIndex < segments.length - 1) {
        invitationSlug = segments[slugIndex + 1];
      } else if (segments.isNotEmpty && segments.last != 'invite') {
        invitationSlug = segments.last;
      }
    }
    // Handle saralevents://invite/:slug (custom scheme - format 1: host is 'invite')
    else if (uri.scheme == 'saralevents' && uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
      invitationSlug = uri.pathSegments.first;
    }
    // Handle saralevents://invite/:slug (custom scheme - format 2: path contains '/invite/')
    else if (uri.scheme == 'saralevents' && uri.path.contains('/invite/')) {
      final segments = uri.pathSegments;
      final slugIndex = segments.indexOf('invite');
      if (slugIndex >= 0 && slugIndex < segments.length - 1) {
        invitationSlug = segments[slugIndex + 1];
      } else if (segments.isNotEmpty && segments.last != 'invite') {
        invitationSlug = segments.last;
      }
    }
    // Handle saralevents://invite/:slug (custom scheme - format 3: host empty, path starts with /invite/)
    else if (uri.scheme == 'saralevents' && (uri.host.isEmpty || uri.host == '') && uri.path.startsWith('/invite/')) {
      final pathParts = uri.path.split('/').where((p) => p.isNotEmpty).toList();
      if (pathParts.length >= 2 && pathParts[0] == 'invite') {
        invitationSlug = pathParts[1];
      }
    }
    // Handle saralevents://invite/:slug (custom scheme - format 4: try parsing from full string)
    else if (uri.scheme == 'saralevents' && uri.toString().contains('/invite/')) {
      final match = RegExp(r'/invite/([^/?#]+)').firstMatch(uri.toString());
      if (match != null && match.groupCount >= 1) {
        invitationSlug = match.group(1);
      }
    }
    // Handle intent://invite/:slug#Intent... (for Android intent URLs)
    else if (uri.scheme == 'intent' && uri.path.contains('/invite/')) {
      final segments = uri.pathSegments;
      final slugIndex = segments.indexOf('invite');
      if (slugIndex >= 0 && slugIndex < segments.length - 1) {
        invitationSlug = segments[slugIndex + 1];
      }
    }
    
    if (invitationSlug != null && invitationSlug.isNotEmpty) {
      print('🔗 Invitation slug: $invitationSlug');
      navigateAfterDelay('/invite/$invitationSlug');
      return;
    }

    // Referral links: https://saralevents.vercel.app/refer?code=XXX or saralevents://refer/:code
    if ((uri.scheme == 'https' && uri.host.contains('saralevents') && uri.path.contains('/refer')) ||
        (uri.scheme == 'saralevents' && uri.host == 'refer') ||
        (uri.scheme == 'intent' && uri.path.contains('/refer'))) {
      String? code;
      if (uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code'];
      } else if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        if (lastSegment != 'refer' && lastSegment.isNotEmpty) {
          code = lastSegment;
        }
      }
      
      print('🔗 Referral code: $code');
      if (code != null && code.isNotEmpty) {
        navigateAfterDelay('/profile/refer?code=$code');
      } else {
        navigateAfterDelay('/profile/refer');
      }
      return;
    }

    // Service links: https://saralevents.vercel.app/service/:id or saralevents://service/:id
    if ((uri.scheme == 'https' && uri.host.contains('saralevents') && uri.path.contains('/service/')) ||
        (uri.scheme == 'saralevents' && uri.host == 'service' && uri.pathSegments.isNotEmpty)) {
      String? serviceId;
      if (uri.scheme == 'https') {
        final segments = uri.pathSegments;
        final serviceIndex = segments.indexOf('service');
        if (serviceIndex >= 0 && serviceIndex < segments.length - 1) {
          serviceId = segments[serviceIndex + 1];
        }
      } else if (uri.scheme == 'saralevents') {
        serviceId = uri.pathSegments.first;
      }
      
      if (serviceId != null && serviceId.isNotEmpty) {
        print('🔗 Service ID: $serviceId');
        // Navigate to service details - you'll need to add this route or handle it
        // For now, navigate to home and show service
        navigateAfterDelay('/app');
        return;
      }
    }

    print('⚠️ Unhandled link: $uri');
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}