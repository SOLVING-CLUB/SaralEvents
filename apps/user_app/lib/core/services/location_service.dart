import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/material.dart';
import 'permission_service.dart';

class LocationService {
  /// Ensure location permission is granted
  static Future<bool> ensurePermission({BuildContext? context}) async {
    final result = await PermissionService.requestLocationPermission(
      context: context,
      showRationale: context != null,
    );
    
    if (!result.isGranted && context != null) {
      await PermissionService.showPermissionDeniedDialog(context, result.status);
    }
    
    return result.isGranted;
  }

  /// Check if location permission is granted without requesting
  static Future<bool> hasPermission() async {
    final status = await PermissionService.getLocationPermissionStatus();
    return status == LocationPermissionStatus.granted;
  }

  static Future<Position> getCurrentPosition() async {
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Get a fresh, best-effort position by listening briefly to the live stream
  static Future<Position> getFreshPosition({Duration timeout = const Duration(seconds: 6)}) async {
    // Start with last known, then prefer the newest from stream within timeout
    Position? best = await Geolocator.getLastKnownPosition();
    late StreamSubscription<Position> sub;
    final completer = Completer<Position>();
    try {
      sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
      ).listen((pos) {
        best = pos;
      });
      // Wait for timeout then resolve with best available (or fall back to current)
      await Future.delayed(timeout);
      if (best != null) {
        completer.complete(best!);
      } else {
        final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
        completer.complete(current);
      }
    } finally {
      await sub.cancel();
    }
    return completer.future;
  }

  static Future<String?> reverseGeocode(double lat, double lng) async {
    final list = await geo.placemarkFromCoordinates(lat, lng);
    if (list.isEmpty) return null;
    final p = list.first;
    return [p.name, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
        .where((e) => e != null && e.isNotEmpty)
        .map((e) => e!)
        .join(', ');
  }
}


