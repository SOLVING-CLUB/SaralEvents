import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'wishlist_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession extends ChangeNotifier {
  bool _isOnboardingComplete = false;
  bool _isAuthenticated = false;
  bool _isPasswordRecovery = false;
  String? _userRole;
  bool _isProfileSetupComplete = false;

  UserSession() {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      _isAuthenticated = event.session != null || Supabase.instance.client.auth.currentSession != null;
      if (event.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      if (_isAuthenticated) {
        await _checkUserRole();
        await checkProfileSetup();
        // Initialize wishlist when user logs in
        WishlistNotifier.instance.initialize();
        // Initialize cart when user logs in
        _initializeCart();
      } else {
        // Clear wishlist when user logs out
        WishlistNotifier.instance.reset();
        // Clear cart when user logs out
        _clearCart();
      }
      notifyListeners();
    });
    _init();
  }

  void _initializeCart() {
    // Get CheckoutState from context if available
    // This will be called after the widget tree is built
    Future.microtask(() async {
      try {
        // We'll initialize cart in main.dart after the provider is available
        // This is a placeholder that will be handled properly
      } catch (e) {
        print('Error initializing cart: $e');
      }
    });
  }

  void _clearCart() {
    // Cart clearing will be handled by CheckoutState itself
    // This is a placeholder
  }

  Future<void> _init() async {
    _isAuthenticated = Supabase.instance.client.auth.currentSession != null;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingComplete = prefs.getBool('onboarding_seen') ?? false;
    } catch (_) {
      _isOnboardingComplete = false;
    }
    if (_isAuthenticated) {
      await _checkUserRole();
      await checkProfileSetup();
    }
    notifyListeners();
  }

  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isAuthenticated => _isAuthenticated;
  bool get isPasswordRecovery => _isPasswordRecovery;
  String? get userRole => _userRole;
  bool get isUserRole => _userRole == 'user';
  bool get isVendorRole => _userRole == 'vendor';
  bool get isCompanyRole => _userRole == 'company';
  bool get isProfileSetupComplete => _isProfileSetupComplete;
  
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  Future<void> _checkUserRole() async {
    try {
      if (currentUser?.id == null) {
        print('No current user ID available');
        return;
      }
      
      print('Checking role for user: ${currentUser!.id}');
      final result = await Supabase.instance.client
          .from('user_roles')
          .select('role')
          .eq('user_id', currentUser!.id)
          .limit(1)
          .maybeSingle();
      
      print('Role check result: $result');
      _userRole = result?['role'] as String?;
      print('User role set to: $_userRole');
    } catch (e) {
      print('Error checking user role: $e');
      print('Error details: ${e.toString()}');
      _userRole = null;
    }
  }

  Future<void> completeOnboarding() async {
    _isOnboardingComplete = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen', true);
    } catch (_) {
      // Ignore persistence errors; in-memory flag still advances the flow
    }
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      print('Attempting login for: $email');
      
      // Try direct login with the email
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email, 
        password: password
      );
      
      _isAuthenticated = res.session != null;
      if (_isAuthenticated) {
        await _checkUserRole();
        await checkProfileSetup();
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signInWithGoogleNative() async {
		try {
			// Web client ID configured in Supabase Google provider
			const serverClientId = '460598868043-tk6pnifpvu24b8b5pm1h5vdoin6vqhr3.apps.googleusercontent.com';

			final signIn = GoogleSignIn(
				serverClientId: serverClientId,
				scopes: const ['email', 'profile'],
			);

			await signIn.signOut();
			final account = await signIn.signIn();
			if (account == null) {
				throw Exception('Sign-in cancelled');
			}

			final auth = await account.authentication;
			final idToken = auth.idToken;
			if (idToken == null) {
				throw Exception('No Google ID token received');
			}

			final res = await Supabase.instance.client.auth.signInWithIdToken(
				provider: OAuthProvider.google,
				idToken: idToken,
			);

			_isAuthenticated = res.session != null || Supabase.instance.client.auth.currentSession != null;
			if (_isAuthenticated) {
				await _checkUserRole();
        await checkProfileSetup();
			}
			notifyListeners();
		} catch (e) {
			print('Google Sign-In error: $e');
			rethrow;
		}
	}

  Future<bool> registerWithEmail(String email, String password, {
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    try {
      print('Starting registration for: $email');
      
      // First, check if this email already exists in auth
      try {
        // Try to sign up with the original email
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: kIsWeb
              ? null
              : 'saralevents://auth/confirm',
        );
        
        print('Auth signup result: ${res.user?.id}');
        
        if (res.user != null) {
          // Wait a moment to ensure user is created in auth.users
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Add user role
          print('Adding user role for: ${res.user!.id}');
          await Supabase.instance.client.from('user_roles').upsert({
            'user_id': res.user!.id,
            'role': 'user',
          });
          
          // Create legacy user profile placeholder (optional)
          print('Creating user profile placeholder (legacy table) for: ${res.user!.id}');
          await Supabase.instance.client.from('user_profiles').upsert({
            'user_id': res.user!.id,
            'first_name': firstName,
            'last_name': lastName,
            'phone_number': phoneNumber,
            'email': email,
          });
          
          _isAuthenticated = res.session != null;
          _userRole = 'user';
          await checkProfileSetup();
          print('New user registration successful!');
        }
        
        notifyListeners();
        return res.user?.emailConfirmedAt == null; // Returns true if email confirmation required
        
      } catch (authError) {
        // If auth signup fails because user already exists
        if (authError.toString().contains('already registered')) {
          print('User already exists in auth, checking for existing profile');
          
          // Try to find existing user profile by email
          final existingProfile = await Supabase.instance.client
              .from('user_profiles')
              .select('user_id')
              .eq('email', email)
              .maybeSingle();
          
                 if (existingProfile != null) {
            // Check existing roles
            final existingRoles = await Supabase.instance.client
                .from('user_roles')
                .select('role')
                .eq('user_id', existingProfile['user_id']);
            
            List<String> currentRoles = [];
            if (existingRoles.isNotEmpty) {
              currentRoles = existingRoles.map((r) => r['role'] as String).toList();
            }
            
            // Show appropriate message based on existing roles
            if (currentRoles.contains('user')) {
              throw Exception('Account already exists. Please login instead.');
            } else {
              final otherRoles = currentRoles.join(', ');
              throw Exception('This email is registered as $otherRoles. Please login with your existing credentials.');
            }
          } else {
            // If no profile found, just show the error
            throw Exception('Account already exists. Please login instead.');
          }
        }
        
        // Re-throw the original error
        rethrow;
      }
      
    } catch (e) {
      print('Registration error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _isAuthenticated = false;
    _userRole = null;
    _isProfileSetupComplete = false;
    // Clear wishlist on sign out
    WishlistNotifier.instance.reset();
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword)
    );
    _isPasswordRecovery = false;
    notifyListeners();
  }

  // Check if user has the correct role for this app
  // Allow any authenticated user to access the user app
  bool get hasCorrectRole => _isAuthenticated;
  
  // Get role mismatch message (only for registration warnings)
  String? get roleMismatchMessage {
    if (_userRole == null) return null;
    if (isUserRole) return null;
    
    // Don't block access, just provide info
    switch (_userRole) {
      case 'vendor':
        return 'This account is registered as a vendor. You can still use the user app.';
      case 'company':
        return 'This account is registered as a company. You can still use the user app.';
      default:
        return 'This account has an invalid role.';
    }
  }

  // Determine whether minimum profile info exists
  Future<void> checkProfileSetup() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _isProfileSetupComplete = false;
        return;
      }
      // Use 'user_profiles' table (current schema)
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('first_name, phone_number')
          .eq('user_id', user.id)
          .maybeSingle();

      final firstName = (profile?['first_name'] as String?)?.trim();
      final phone = (profile?['phone_number'] as String?)?.trim();

      // Require both first_name and phone_number to be present
      _isProfileSetupComplete =
          (firstName != null && firstName.isNotEmpty) && (phone != null && phone.isNotEmpty);
    } catch (_) {
      _isProfileSetupComplete = false;
    }
  }
}
