import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressInfo {
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  AddressInfo({required this.id, required this.label, required this.address, required this.lat, required this.lng});
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'address': address, 'lat': lat, 'lng': lng};
  static AddressInfo fromJson(Map<String, dynamic> m) => AddressInfo(
        id: m['id'] as String,
        label: m['label'] as String,
        address: m['address'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
      );
}

class AddressStorage {
  static const _kSaved = 'saved_addresses_v1';
  static const _kActive = 'active_address_id_v1';

  static Future<List<AddressInfo>> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kSaved);
    if (data == null || data.isEmpty) return [];
    final list = (jsonDecode(data) as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(AddressInfo.fromJson).toList();
  }

  static Future<void> saveAll(List<AddressInfo> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSaved, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  /// Set an address as active (for saved addresses only)
  /// This will add the address to saved list if it doesn't exist
  static Future<void> setActive(AddressInfo info, {bool addToSaved = true}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Only add to saved list if explicitly requested (for manually saved addresses)
    if (addToSaved) {
      final list = await loadSaved();
      final exists = list.any((e) => e.id == info.id);
      if (!exists) {
        list.add(info);
        await saveAll(list);
      }
    }
    
    // Set as active (saved address)
    await prefs.setString(_kActive, info.id);
    await prefs.setDouble('loc_lat', info.lat);
    await prefs.setDouble('loc_lng', info.lng);
    await prefs.setString('loc_address', info.address);
    
    debugPrint('Setting active address: ${info.label} (ID: ${info.id}) - ${info.address}');
    debugPrint('Active ID saved: ${info.id}');
    
    // Clear temporary location when a saved address is set as active
    await clearTemporaryLocation();
    
    // Verify immediately
    final verifyId = prefs.getString(_kActive);
    debugPrint('Verification: Active ID = $verifyId');
  }

  /// Set a temporary location (session-only, not saved to address list)
  /// Used for automatically fetched locations or manually selected locations
  /// that should reset on next app start
  static Future<void> setTemporaryLocation(AddressInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear active saved address if one was set
    await prefs.remove(_kActive);
    
    // Store temporary location (session-only)
    await prefs.setDouble('temp_loc_lat', info.lat);
    await prefs.setDouble('temp_loc_lng', info.lng);
    await prefs.setString('temp_loc_address', info.address);
    
    // Also update main location keys for compatibility
    await prefs.setDouble('loc_lat', info.lat);
    await prefs.setDouble('loc_lng', info.lng);
    await prefs.setString('loc_address', info.address);
  }

  /// Clear temporary location (called on app start)
  static Future<void> clearTemporaryLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_loc_lat');
    await prefs.remove('temp_loc_lng');
    await prefs.remove('temp_loc_address');
  }

  static Future<AddressInfo?> getActive() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kActive);
    
    // Priority 1: If we have an active saved address ID, return it
    if (id != null && id.isNotEmpty) {
      debugPrint('Looking for saved address with ID: $id');
      final list = await loadSaved();
      debugPrint('Total saved addresses: ${list.length}');
      debugPrint('Saved address IDs: ${list.map((e) => '${e.id}(${e.label})').join(", ")}');
      
      try {
        final savedAddress = list.firstWhere((e) => e.id == id);
        debugPrint('✓ Found saved address: ${savedAddress.label} - ${savedAddress.address}');
        return savedAddress;
      } catch (e) {
        // Address not found in saved list - this might happen if address was deleted
        // but active ID still exists. Clear the invalid ID and continue.
        debugPrint('✗ Saved address with ID "$id" not found in list. Error: $e');
        debugPrint('Available saved address IDs: ${list.map((e) => e.id).join(", ")}');
        // Try to find by matching address text as fallback
        final addressText = prefs.getString('loc_address');
        if (addressText != null) {
          try {
            final matchByAddress = list.firstWhere((e) => e.address == addressText);
            debugPrint('Found address by text match: ${matchByAddress.label}');
            // Update the active ID to match
            await prefs.setString(_kActive, matchByAddress.id);
            return matchByAddress;
          } catch (_) {
            // No match by address either
          }
        }
        // Don't clear the ID here - let it fall through to check temporary/legacy
      }
    }
    
    // Priority 2: Check temporary location (session-only)
    final tempLat = prefs.getDouble('temp_loc_lat');
    final tempLng = prefs.getDouble('temp_loc_lng');
    final tempAddress = prefs.getString('temp_loc_address');
    
    if (tempLat != null && tempLng != null && tempAddress != null) {
      return AddressInfo(
        id: 'temp_location_${DateTime.now().millisecondsSinceEpoch}',
        label: 'Current Location',
        address: tempAddress,
        lat: tempLat,
        lng: tempLng,
      );
    }
    
    // Priority 3: Fallback to legacy location data (for backward compatibility)
    final lat = prefs.getDouble('loc_lat');
    final lng = prefs.getDouble('loc_lng');
    final address = prefs.getString('loc_address');
    
    if (lat != null && lng != null && address != null) {
      return AddressInfo(
        id: id ?? 'current_location_${DateTime.now().millisecondsSinceEpoch}',
        label: 'Current Location',
        address: address,
        lat: lat,
        lng: lng,
      );
    }
    
    return null;
  }

  static Future<String?> getActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActive);
  }

  static Future<void> delete(String id) async {
    final list = await loadSaved();
    list.removeWhere((e) => e.id == id);
    await saveAll(list);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kActive) == id) {
      prefs.remove(_kActive);
    }
  }
}


