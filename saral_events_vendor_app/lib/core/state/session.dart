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

  RealtimeChannel? _vendorRealtimeChannel;
  VendorProfile? _vendorProfile;
  VendorProfile? get vendorProfile => _vendorProfile;

  AppSession() {
    print('AppSession: Constructor called');
    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      print('AppSession: Auth state changed - ${event.event}');
      _isAuthenticated = event.session != null || Supabase.instance.client.auth.currentSession != null;
      print('AppSession: Authentication status: $_isAuthenticated');
      
      if (event.event == AuthChangeEvent.signedOut || event.event == AuthChangeEvent.userDeleted) {
        _cleanupRealtime();
        _isAuthenticated = false;
        _isVendorSetupComplete = false;
        _vendorProfile = null;
      }

      if (event.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      
      if (_isAuthenticated) {
        await _checkVendorSetup();
        _setupVendorRealtime();
      } else {
        _cleanupRealtime();
      }
      
      notifyListeners();
    });
    // Initialize vendor setup status on startup (e.g., hot restart, existing session)
    _init();
  }

  void _setupVendorRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _cleanupRealtime();

    print('AppSession: Setting up realtime listener for vendor_profiles deletion for user: ${user.id}');
    _vendorRealtimeChannel = Supabase.instance.client
        .channel('vendor-deletion-monitor') // Use a fixed name for simpler debugging
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'vendor_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) async {
            print('AppSession: RECEIVED DELETE EVENT via Realtime! Payload: $payload');
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('lastKnownVendorId');
            await signOut();
          },
        );

    _vendorRealtimeChannel!.subscribe((status, [error]) {
      print('AppSession: Realtime subscription status: $status');
      if (error != null) {
        print('AppSession: Realtime Error: $error');
      }
    });
  }

  void _cleanupRealtime() {
    if (_vendorRealtimeChannel != null) {
      print('AppSession: Cleaning up realtime channel');
      Supabase.instance.client.removeChannel(_vendorRealtimeChannel!);
      _vendorRealtimeChannel = null;
    }
  }

  Future<void> _init() async {
    print('AppSession: Starting initialization...');
    try {
      // Load onboarding/deletion status from SharedPreferences
      await _loadOnboardingStatus();
      
      // Check if user is already authenticated
      final currentSession = Supabase.instance.client.auth.currentSession;
      
      // If _isAuthenticated was set to false by _loadOnboardingStatus's signOut, don't override back to true immediately
      if (_isAuthenticated && currentSession != null) {
        await _checkVendorSetup();
        _setupVendorRealtime();
      } else {
        _isAuthenticated = currentSession != null;
        if (_isAuthenticated) {
          await _checkVendorSetup();
          _setupVendorRealtime();
        }
      }
      
      _isInitialized = true;
      print('AppSession: Initialization complete (Authenticated: $_isAuthenticated)');
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
      
      // Also check if they were a vendor before and were deleted
      final lastKnownVendorId = prefs.getString('lastKnownVendorId');
      final currentSession = Supabase.instance.client.auth.currentSession;
      
      if (currentSession != null && lastKnownVendorId != null) {
        print('AppSession: Checking for deleted vendor account (lastKnown: $lastKnownVendorId)');
        final user = currentSession.user;
        final service = VendorService();
        final profile = await service.getVendorProfile(user.id);
        
        if (profile == null) {
          print('AppSession: VENDOR ACCOUNT DELETED detected in _init. Forcing logout.');
          await prefs.remove('lastKnownVendorId');
          await signOut();
          return; // Stop initialization as we are logging out
        }
      }
      
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
      
      if (_vendorProfile != null) {
        await prefs.setString('lastKnownVendorId', _vendorProfile!.id!);
      } else {
        await prefs.remove('lastKnownVendorId');
      }
      
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
  bool get isVendorApproved =>
      _vendorProfile?.approvalStatus == 'approved';
  bool get isVendorPendingApproval =>
      _vendorProfile?.approvalStatus == 'pending';
  
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
      _vendorProfile = profile;
      _isVendorSetupComplete = profile != null;
      
      // Sync status to persist the "was vendor" flag
      await _saveOnboardingStatus();
    } catch (e) {
      _isVendorSetupComplete = false;
      _vendorProfile = null;
    }
  }

  void completeVendorSetup() {
    // After vendor submits setup, reload profile so UI can show latest status.
    // NOTE: kept for backward compatibility; prefer the async version below.
    completeVendorSetupAsync();
  }

  Future<void> completeVendorSetupAsync() async {
    // After vendor submits setup, reload profile so router redirects don't bounce back to setup
    // while the profile refresh is still in-flight.
    await _checkVendorSetup();
    notifyListeners();
  }

  Future<void> signOut() async {
    print('AppSession: Manual signOut called');
    try {
      _cleanupRealtime();
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('AppSession: Error during auth signOut: $e');
    } finally {
      _isAuthenticated = false;
      _isVendorSetupComplete = false;
      _isPasswordRecovery = false;
      _vendorProfile = null;
      print('AppSession: Session cleared, notifying listeners');
      notifyListeners();
    }
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
    if (_isAuthenticated) {
      await _checkVendorSetup();
      notifyListeners();
    }
  }
}


