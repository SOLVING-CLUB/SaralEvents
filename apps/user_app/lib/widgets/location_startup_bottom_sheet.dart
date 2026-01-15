import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/location_service.dart';
import '../core/services/permission_service.dart';
import '../core/services/address_storage.dart';
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

        // Save as active address
        final addressInfo = AddressInfo(
          id: 'current_location_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Current Location',
          address: address,
          lat: position.latitude,
          lng: position.longitude,
        );

        await AddressStorage.setActive(addressInfo);
        
        // Also ensure SharedPreferences is updated
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('loc_lat', position.latitude);
        await prefs.setDouble('loc_lng', position.longitude);
        await prefs.setString('loc_address', address);
        
        if (mounted) {
          Navigator.of(context).pop();
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
    // Save the selected address as active
    await AddressStorage.setActive(address);
    
    // Also save to SharedPreferences for app-wide access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('loc_lat', address.lat);
    await prefs.setDouble('loc_lng', address.lng);
    await prefs.setString('loc_address', address.address);
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location set to: ${address.label}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Trigger a rebuild of the app to reflect the new location
      // This will be handled by the home screen's _loadActiveAddress() callback
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
                color: Colors.grey[300],
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
                const Icon(
                  Icons.location_on,
                  color: Colors.black87,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Permission is Off',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFDBB42),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDBB42)),
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
                    const Text(
                      'Select Delivery Address',
                      style: TextStyle(
                        fontSize: 16,
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
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
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
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getAddressIcon(address.label),
                              color: const Color(0xFFFDBB42),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    address.address,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
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
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Enter Location Manually',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
