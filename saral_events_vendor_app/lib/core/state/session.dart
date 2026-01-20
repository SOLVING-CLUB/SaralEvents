import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/vendor_setup/vendor_service.dart';
import '../../features/vendor_setup/vendor_models.dart';

class AppSession extends ChangeNotifier {
  bool _isOnboardingComplete = false;
  bool _isAuthenticated = false;
  bool _isVendorSetupComplete = false;
  bool _isPasswordRecovery = false;
  bool _isInitialized = false;

  VendorProfile? _vendorProfile;
  VendorProfile? get vendorProfile => _vendorProfile;

  AppSession() {
    print('AppSession: Constructor called');
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      print('AppSession: Auth state changed - ${event.event}');
      _isAuthenticated = event.session != null || Supabase.instance.client.auth.currentSession != null;
      print('AppSession: Authentication status: $_isAuthenticated');
      if (event.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      await _checkVendorSetup();
      notifyListeners();
    });
    // Initialize vendor setup status on startup (e.g., hot restart, existing session)
    _init();
  }

  Future<void> _init() async {
    print('AppSession: Starting initialization...');
    try {
      // Load onboarding completion status from SharedPreferences
      await _loadOnboardingStatus();
      
      // Check if user is already authenticated (for app restarts)
      final currentSession = Supabase.instance.client.auth.currentSession;
      _isAuthenticated = currentSession != null;
      print('AppSession: Initial auth check: $_isAuthenticated');
      if (currentSession != null) {
        print('AppSession: Current user: ${currentSession.user.email}');
      }
      
      await _checkVendorSetup();
      _isInitialized = true;
      print('AppSession: Initialization complete');
      notifyListeners();
    } catch (e) {
      print('AppSession: Error during initialization: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingComplete = prefs.getBool('isOnboardingComplete') ?? false;
      print('AppSession: Loaded onboarding status: $_isOnboardingComplete');
    } catch (e) {
      print('AppSession: Error loading onboarding status: $e');
      _isOnboardingComplete = false;
    }
  }

  Future<void> _saveOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOnboardingComplete', _isOnboardingComplete);
      print('AppSession: Saved onboarding status: $_isOnboardingComplete');
    } catch (e) {
      print('AppSession: Error saving onboarding status: $e');
    }
  }

  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isAuthenticated => _isAuthenticated;
  bool get isVendorSetupComplete => _isVendorSetupComplete;
  bool get isPasswordRecovery => _isPasswordRecovery;
  bool get isInitialized => _isInitialized;
  
  // Add currentUser getter to access the authenticated user
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  void completeOnboarding() {
    print('AppSession: Completing onboarding');
    _isOnboardingComplete = true;
    _saveOnboardingStatus(); // Save to SharedPreferences
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      _isAuthenticated = res.session != null || Supabase.instance.client.auth.currentSession != null;
      await _checkVendorSetup();
    } finally {
      notifyListeners();
    }
  }

  Future<bool> registerWithEmail(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signUp(email: email, password: password);
      final hasSession = res.session != null || Supabase.instance.client.auth.currentSession != null;
      _isAuthenticated = hasSession;
      await _checkVendorSetup();
      return !hasSession; // true if email confirmation likely required
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
      await _checkVendorSetup();
      notifyListeners();
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> _checkVendorSetup() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _isVendorSetupComplete = false;
      _vendorProfile = null;
      return;
    }
    try {
      final service = VendorService();
      final profile = await service.getVendorProfile(user.id);
      _isVendorSetupComplete = profile != null;
      _vendorProfile = profile;
    } catch (e) {
      _isVendorSetupComplete = false;
      _vendorProfile = null;
    }
  }

  void completeVendorSetup() {
    _isVendorSetupComplete = true;
    // Proactively reload vendor profile after setup to refresh UI immediately
    _checkVendorSetup();
    notifyListeners();
  }

  void signOut() {
    Supabase.instance.client.auth.signOut();
    _isAuthenticated = false;
    _isVendorSetupComplete = false;
    _isPasswordRecovery = false;
    _vendorProfile = null;
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
    _isPasswordRecovery = false;
    notifyListeners();
  }

  void markPasswordRecovery() {
    _isPasswordRecovery = true;
    notifyListeners();
  }

  Future<void> reloadVendorProfile() async {
    await _checkVendorSetup();
    notifyListeners();
  }
}


