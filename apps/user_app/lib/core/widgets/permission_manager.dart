import 'dart:async';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// Widget that manages app-level permissions
class PermissionManager extends StatefulWidget {
  final Widget child;
  final bool requestLocationOnStart;

  const PermissionManager({
    super.key,
    required this.child,
    this.requestLocationOnStart = true,
  });

  @override
  State<PermissionManager> createState() => _PermissionManagerState();
}

class _PermissionManagerState extends State<PermissionManager> 
    with WidgetsBindingObserver {
  bool _permissionsInitialized = false;
  bool _serviceBannerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    if (widget.requestLocationOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializePermissions();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes back from background, check if permissions changed
    if (state == AppLifecycleState.resumed && _permissionsInitialized) {
      _checkPermissionChanges();
    }
  }

  Future<void> _initializePermissions() async {
    if (!mounted) return;
    
    try {
      await PermissionService.initializePermissions(context);
      _permissionsInitialized = true;
      await _maybeShowServiceDisabledBanner();
    } catch (e) {
      debugPrint('Error initializing permissions: $e');
    }
  }

  Future<void> _checkPermissionChanges() async {
    if (!mounted) return;
    
    try {
      final status = await PermissionService.getLocationPermissionStatus();
      
      // If permission was granted after being denied, clear the denial flag
      if (status == LocationPermissionStatus.granted) {
        await PermissionService.clearLocationPermissionDenied();
      }
      await _maybeShowServiceDisabledBanner();
    } catch (e) {
      debugPrint('Error checking permission changes: $e');
    }
  }

  Future<void> _maybeShowServiceDisabledBanner() async {
    if (!mounted) return;
    try {
      final status = await PermissionService.getLocationPermissionStatus();
      // Don't show MaterialBanner when location is off - the bottom sheet handles it at startup
      // The bottom sheet is shown by HomeScreen when location is off
      if (status == LocationPermissionStatus.serviceDisabled && !_serviceBannerShown) {
        _serviceBannerShown = true;
        // Banner disabled - bottom sheet handles location prompts at startup
        // No need to show MaterialBanner since the bottom sheet provides better UX
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin for widgets that need location permission
mixin LocationPermissionMixin<T extends StatefulWidget> on State<T> {
  /// Request location permission with proper UI flow
  Future<bool> requestLocationPermission({
    bool showRationale = true,
  }) async {
    final result = await PermissionService.requestLocationPermission(
      context: context,
      showRationale: showRationale,
    );
    
    if (!result.isGranted) {
      await PermissionService.showPermissionDeniedDialog(context, result.status);
    }
    
    return result.isGranted;
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    final status = await PermissionService.getLocationPermissionStatus();
    return status == LocationPermissionStatus.granted;
  }

  /// Show permission rationale and request permission
  Future<bool> requestLocationWithRationale({
    String? title,
    String? message,
  }) async {
    final hasPermission = await hasLocationPermission();
    if (hasPermission) return true;

    // Show custom rationale if provided
    if (title != null && message != null) {
      final shouldProceed = await _showCustomRationale(title, message);
      if (!shouldProceed) return false;
    }

    return await requestLocationPermission();
  }

  Future<bool> _showCustomRationale(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    ) ?? false;
  }
}

/// Widget that shows permission status
class PermissionStatusWidget extends StatefulWidget {
  final Widget Function(BuildContext context, LocationPermissionStatus status) builder;
  final Duration refreshInterval;

  const PermissionStatusWidget({
    super.key,
    required this.builder,
    this.refreshInterval = const Duration(seconds: 5),
  });

  @override
  State<PermissionStatusWidget> createState() => _PermissionStatusWidgetState();
}

class _PermissionStatusWidgetState extends State<PermissionStatusWidget> {
  LocationPermissionStatus _status = LocationPermissionStatus.notRequested;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _checkStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    
    final status = await PermissionService.getLocationPermissionStatus();
    if (mounted && status != _status) {
      setState(() {
        _status = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _status);
  }
}

/// Utility class for permission-related operations
class PermissionUtils {
  /// Check if location features should be available
  static Future<bool> canUseLocationFeatures() async {
    final status = await PermissionService.getLocationPermissionStatus();
    return status == LocationPermissionStatus.granted;
  }

  /// Get user-friendly permission status message
  static String getPermissionStatusMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return 'Location access granted';
      case LocationPermissionStatus.denied:
        return 'Location access denied';
      case LocationPermissionStatus.permanentlyDenied:
        return 'Location access permanently denied';
      case LocationPermissionStatus.serviceDisabled:
        return 'Location services disabled';
      case LocationPermissionStatus.restricted:
        return 'Location access restricted';
      case LocationPermissionStatus.limited:
        return 'Location access limited';
      case LocationPermissionStatus.provisional:
        return 'Location access provisional';
      case LocationPermissionStatus.notRequested:
        return 'Location permission not requested';
    }
  }

  /// Get icon for permission status
  static IconData getPermissionStatusIcon(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Icons.location_on;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.permanentlyDenied:
        return Icons.location_off;
      case LocationPermissionStatus.serviceDisabled:
        return Icons.location_disabled;
      case LocationPermissionStatus.restricted:
      case LocationPermissionStatus.limited:
        return Icons.location_searching;
      case LocationPermissionStatus.provisional:
      case LocationPermissionStatus.notRequested:
        return Icons.location_searching;
    }
  }

  /// Get color for permission status
  static Color getPermissionStatusColor(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.granted:
        return Colors.green;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.permanentlyDenied:
        return Colors.red;
      case LocationPermissionStatus.serviceDisabled:
        return Colors.orange;
      case LocationPermissionStatus.restricted:
      case LocationPermissionStatus.limited:
      case LocationPermissionStatus.provisional:
      case LocationPermissionStatus.notRequested:
        return Colors.grey;
    }
  }
}