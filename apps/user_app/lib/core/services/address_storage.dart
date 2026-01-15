import 'dart:convert';
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

  static Future<void> setActive(AddressInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure the address is in the saved list
    final list = await loadSaved();
    final exists = list.any((e) => e.id == info.id);
    if (!exists) {
      list.add(info);
      await saveAll(list);
    }
    
    // Set as active
    await prefs.setString(_kActive, info.id);
    await prefs.setDouble('loc_lat', info.lat);
    await prefs.setDouble('loc_lng', info.lng);
    await prefs.setString('loc_address', info.address);
  }

  static Future<AddressInfo?> getActive() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kActive);
    
    // If we have an active ID, try to find it in saved addresses
    if (id != null) {
      final list = await loadSaved();
      try {
        return list.firstWhere((e) => e.id == id);
      } catch (_) {
        // Address not found in saved list, fallback to SharedPreferences
      }
    }
    
    // Fallback: check if location data exists in SharedPreferences
    final lat = prefs.getDouble('loc_lat');
    final lng = prefs.getDouble('loc_lng');
    final address = prefs.getString('loc_address');
    
    if (lat != null && lng != null && address != null) {
      // Create a temporary AddressInfo from SharedPreferences
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


