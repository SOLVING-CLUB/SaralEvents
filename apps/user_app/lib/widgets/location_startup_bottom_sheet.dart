import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_service.dart';
import '../core/services/address_storage.dart';
import '../core/services/location_session_manager.dart';
import 'package:go_router/go_router.dart';

/// Bottom sheet shown at app startup when user is logged in but location is off
class LocationStartupBottomSheet extends StatefulWidget {
  const LocationStartupBottomSheet({super.key});

  @override
  State<LocationStartupBottomSheet> createState() => _LocationStartupBottomSheetState();
}

class _LocationStartupBottomSheetState extends State<LocationStartupBottomSheet> {
  bool _isLoading = false;
  List<AddressInfo> _savedAddresses = [];
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await AddressStorage.loadSaved();
    if (mounted) {
      setState(() {
        _savedAddresses = addresses;
        _loadingAddresses = false;
      });
    }
  }

  Future<void> _enableLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Open location settings
        await Geolocator.openLocationSettings();
        // Wait a bit for user to enable location
        await Future.delayed(const Duration(seconds: 1));
        // Check again after returning from settings
        final newServiceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!newServiceEnabled) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable location services in device settings'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Request location permission (this will show the permission dialog)
      final hasPermission = await LocationService.ensurePermission(context: context);
      
      if (hasPermission) {
        // Get current location directly
        final position = await LocationService.getCurrentPosition();
        
        // Reverse geocode to get address
        final address = await LocationService.reverseGeocode(
          position.latitude,
          position.longitude,
        ) ?? 'Current Location';

        // Save as temporary location (session-only, not added to saved addresses)
        final addressInfo = AddressInfo(
          id: 'temp_location_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Current Location',
          address: address,
          lat: position.latitude,
          lng: position.longitude,
        );

        await AddressStorage.setTemporaryLocation(addressInfo);
        
        // Save last selected location ID
        await LocationSessionManager.saveLastSelectedLocationId(addressInfo.id);
        await LocationSessionManager.markLocationResolvedThisSession();
        
        // Verify the address was set correctly
        final verifyActive = await AddressStorage.getActive();
        debugPrint('Location enabled - saved address: ${addressInfo.address}');
        debugPrint('Verified active address: ${verifyActive?.label} - ${verifyActive?.address}');
        
        if (mounted) {
          Navigator.of(context).pop(addressInfo); // Pass address as result to trigger reload
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location enabled successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Permission denied, show message
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to find services near you'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enabling location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectFromSaved(AddressInfo address) async {
    // Save the selected saved address as active (persists across sessions)
    // This is a saved address, so it should persist
    await AddressStorage.setActive(address, addToSaved: true);
    
    // Save last selected location ID
    await LocationSessionManager.saveLastSelectedLocationId(address.id);
    await LocationSessionManager.markLocationResolvedThisSession();
    
    // Verify the address was set correctly
    final verifyActive = await AddressStorage.getActive();
    debugPrint('Address set active: ${address.label} - ${address.address}');
    debugPrint('Verified active address: ${verifyActive?.label} - ${verifyActive?.address}');
    
    if (mounted) {
      Navigator.of(context).pop(address); // Pass address as result to trigger reload
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location set to: ${address.label}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openLocationPicker() async {
    Navigator.of(context).pop();
    context.push('/location/select');
  }

  IconData _getAddressIcon(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('work') || lowerLabel.contains('office')) {
      return Icons.work;
    } else if (lowerLabel.contains('home')) {
      return Icons.home;
    } else {
      return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Yellow Location Permission Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFDBB42), // Yellow theme color
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Permission is Off',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Granting location permission will ensure accurate address and hassle free delivery',
                        style: TextStyle(
                          color: Colors.black87.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _enableLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : const Text(
                          'GRANT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),
          
          // Select Delivery Address Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Delivery Address',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_savedAddresses.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          // Could navigate to full address list if needed
                        },
                        child: const Text(
                          'VIEW ALL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Saved Addresses List
                if (_loadingAddresses)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_savedAddresses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No saved addresses',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  )
                else
                  ..._savedAddresses.take(2).map((address) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _selectFromSaved(address),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getAddressIcon(address.label),
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.label,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    address.address,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                
                const SizedBox(height: 12),
                
                // Enter Location Manually
                InkWell(
                  onTap: _openLocationPicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Enter Location Manually',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
