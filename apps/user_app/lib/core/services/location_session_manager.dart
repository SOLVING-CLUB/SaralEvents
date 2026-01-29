import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'address_storage.dart';
import 'permission_service.dart';

/// Manages location session state and logic
/// Follows Swiggy Instamart-style location handling
class LocationSessionManager {
  // Session flags (reset on app start)
  static const String _kLocationResolvedThisSession = 'location_resolved_this_session';
  static const String _kPermissionAskedThisSession = 'permission_asked_this_session';
  
  // Persistent state (survives app restarts)
  static const String _kLastSelectedLocationId = 'last_selected_location_id';
  
  /// Reset all session flags (called in main.dart on app start)
  static Future<void> resetSessionFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationResolvedThisSession, false);
    await prefs.setBool(_kPermissionAskedThisSession, false);
    debugPrint('🔄 Session flags reset');
  }
  
  /// Check if location was resolved this session
  static Future<bool> wasLocationResolvedThisSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLocationResolvedThisSession) ?? false;
  }
  
  /// Mark location as resolved this session
  static Future<void> markLocationResolvedThisSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationResolvedThisSession, true);
    debugPrint('✅ Location resolved this session');
  }
  
  /// Check if permission was asked this session
  static Future<bool> wasPermissionAskedThisSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPermissionAskedThisSession) ?? false;
  }
  
  /// Mark permission as asked this session
  static Future<void> markPermissionAskedThisSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPermissionAskedThisSession, true);
    debugPrint('✅ Permission asked this session');
  }
  
  /// Save last selected location ID (persists across sessions)
  static Future<void> saveLastSelectedLocationId(String? locationId) async {
    final prefs = await SharedPreferences.getInstance();
    if (locationId != null) {
      await prefs.setString(_kLastSelectedLocationId, locationId);
      debugPrint('💾 Saved last selected location ID: $locationId');
    } else {
      await prefs.remove(_kLastSelectedLocationId);
      debugPrint('🗑️ Cleared last selected location ID');
    }
  }
  
  /// Get last selected location ID
  static Future<String?> getLastSelectedLocationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSelectedLocationId);
  }
  
  /// Check if user has a valid last-selected location
  static Future<bool> hasValidLastSelectedLocation() async {
    final locationId = await getLastSelectedLocationId();
    if (locationId == null || locationId.isEmpty) {
      return false;
    }
    
    // Check if this location still exists in saved addresses
    final activeAddress = await AddressStorage.getActive();
    if (activeAddress != null && activeAddress.id == locationId) {
      debugPrint('✓ Valid last selected location found: ${activeAddress.label}');
      return true;
    }
    
    // Also check if there's any active address (saved or temporary)
    if (activeAddress != null) {
      debugPrint('✓ Active address found: ${activeAddress.label}');
      await saveLastSelectedLocationId(activeAddress.id);
      return true;
    }
    
    return false;
  }
  
  /// Get current location state
  static Future<LocationState> getLocationState() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    final permissionStatus = await PermissionService.getLocationPermissionStatus();
    
    return LocationState(
      isServiceEnabled: isServiceEnabled,
      permissionStatus: permissionStatus,
    );
  }
  
  /// Determine if bottom sheet should be shown
  /// Returns true if bottom sheet should be shown, false otherwise
  static Future<bool> shouldShowBottomSheet() async {
    // Step 1: Check if user has valid last-selected location
    final hasValidLocation = await hasValidLastSelectedLocation();
    if (hasValidLocation) {
      debugPrint('📍 Valid location exists - bottom sheet NOT needed');
      await markLocationResolvedThisSession();
      return false;
    }
    
    // Step 2: Check if location was already resolved this session
    final wasResolved = await wasLocationResolvedThisSession();
    if (wasResolved) {
      debugPrint('📍 Location already resolved this session - bottom sheet NOT needed');
      return false;
    }
    
    // Step 3: Get location state
    final state = await getLocationState();
    
    // Step 4: If permission granted AND GPS ON → try auto-fetch
    if (state.isServiceEnabled && state.permissionStatus == LocationPermissionStatus.granted) {
      debugPrint('📍 Permission granted & GPS ON - attempting auto-fetch');
      // Don't show bottom sheet yet - let auto-fetch try first
      return false;
    }
    
    // Step 5: If permission denied OR GPS OFF → show bottom sheet
    debugPrint('📍 Permission denied OR GPS OFF - bottom sheet NEEDED');
    return true;
  }
}

/// Location state snapshot
class LocationState {
  final bool isServiceEnabled;
  final LocationPermissionStatus permissionStatus;
  
  LocationState({
    required this.isServiceEnabled,
    required this.permissionStatus,
  });
  
  bool get canAutoFetch => isServiceEnabled && permissionStatus == LocationPermissionStatus.granted;
  bool get needsBottomSheet => !isServiceEnabled || permissionStatus != LocationPermissionStatus.granted;
}
