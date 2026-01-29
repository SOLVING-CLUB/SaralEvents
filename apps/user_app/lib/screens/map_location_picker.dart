import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import '../core/services/location_service.dart';
import '../core/services/address_storage.dart';
import '../core/widgets/permission_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> 
    with LocationPermissionMixin {
  
  maps.GoogleMapController? _mapController;
  maps.LatLng _centerPosition = const maps.LatLng(17.3850, 78.4867); // Hyderabad default
  String _address = 'Move the map to select location';
  String _mainLocation = 'Ramanthapur';
  String _fullAddress = 'Amberpet, Chenna Reddy Nagar, Hyderabad';
  bool _loading = true;
  late final FlutterGooglePlacesSdk _places;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isUpdatingAddress = false;
  Timer? _debounceTimer;
  List<AutocompletePrediction> _searchSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk('AIzaSyCmeZeTE1pOuawQecON6AOfhMvNYEl3NKs');
    _init();
  }

  Future<void> _init() async {
    try {
      final hasPermission = await requestLocationWithRationale(
        title: 'Location Access Required',
        message: 'We need access to your location to show you on the map and help you select your address.',
      );
      
      if (hasPermission) {
        final pos = await LocationService.getCurrentPosition();
        _centerPosition = maps.LatLng(pos.latitude, pos.longitude);
        await _updateAddressFromCenter();
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateAddressFromCenter() async {
    if (_isUpdatingAddress || !mounted) return;
    
    setState(() {
      _isUpdatingAddress = true;
      _address = 'Getting address...';
    });

    try {
      final address = await LocationService.reverseGeocode(_centerPosition.latitude, _centerPosition.longitude);
      if (mounted) {
        setState(() {
          _address = address ?? '(${_centerPosition.latitude.toStringAsFixed(5)}, ${_centerPosition.longitude.toStringAsFixed(5)})';
          _parseAddress(address ?? '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAddress = false);
      }
    }
  }

  void _onCameraMove(maps.CameraPosition position) {
    // Only update center position, no setState to avoid lag
    _centerPosition = position.target;
  }

  void _onCameraIdle() {
    // Debounce address updates to avoid excessive API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateAddressFromCenter();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Getting your location...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final position = await LocationService.getCurrentPosition();
      _centerPosition = maps.LatLng(position.latitude, position.longitude);
      
      // Smooth camera animation with zoom
      _mapController?.animateCamera(
        maps.CameraUpdate.newCameraPosition(
          maps.CameraPosition(
            target: _centerPosition,
            zoom: 17, // Closer zoom for current location
          ),
        ),
      );
      
      // Update address after animation
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _updateAddressFromCenter();
      });
      
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to get current location. Please check permissions.'),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                // Could open app settings here
              },
            ),
          ),
        );
      }
    }
  }


  void _parseAddress(String address) {
    // Parse address to extract main location and full address
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      _mainLocation = parts[0].trim();
      _fullAddress = parts.length > 1 ? parts.sublist(1).join(',').trim() : address;
    } else {
      _mainLocation = address;
      _fullAddress = address;
    }
  }

  void _searchLocation(String query) {
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _showSuggestions = false;
        _searchSuggestions.clear();
      });
      return;
    }
    
    // Debounce search to avoid excessive API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchSearchSuggestions(query);
    });
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    if (!mounted) return;
    
    setState(() => _isSearching = true);
    try {
      final predictions = await _places.findAutocompletePredictions(
        query, 
        countries: const ['IN'],
      );
      
      if (mounted) {
        setState(() {
          _searchSuggestions = predictions.predictions.take(5).toList();
          _showSuggestions = _searchSuggestions.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _selectSearchSuggestion(AutocompletePrediction prediction) async {
    setState(() {
      _showSuggestions = false;
      _searchController.text = prediction.primaryText;
      _isSearching = true;
    });

    try {
      final place = await _places.fetchPlace(
        prediction.placeId,
        fields: [PlaceField.Location, PlaceField.Address],
      );
      
      if (place.place?.latLng != null && mounted) {
        final latLng = place.place!.latLng!;
        _centerPosition = maps.LatLng(latLng.lat, latLng.lng);
        
        // Smooth camera animation
        _mapController?.animateCamera(
          maps.CameraUpdate.newCameraPosition(
            maps.CameraPosition(
              target: _centerPosition,
              zoom: 16,
            ),
          ),
        );
        
        final address = place.place?.address ?? prediction.fullText;
        if (mounted) {
          setState(() {
            _address = address;
            _parseAddress(address);
          });
        }
      }
    } catch (e) {
      debugPrint('Place selection error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirm() async {
    // Create new address
    final newAddress = AddressInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: 'Selected Location',
      address: _address,
      lat: _centerPosition.latitude,
      lng: _centerPosition.longitude,
    );
    
    // Add to saved addresses list
    final savedAddresses = await AddressStorage.loadSaved();
    savedAddresses.add(newAddress);
    await AddressStorage.saveAll(savedAddresses);
    
    // Set as active address
    await AddressStorage.setActive(newAddress);
    
    if (!mounted) return;
    context.go('/app');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Hide suggestions when tapping outside
                if (_showSuggestions) {
                  setState(() => _showSuggestions = false);
                }
                // Hide keyboard
                FocusScope.of(context).unfocus();
              },
              child: Stack(
              children: [
                // Map
                maps.GoogleMap(
                  initialCameraPosition: maps.CameraPosition(target: _centerPosition, zoom: 16),
                  myLocationEnabled: false, // Disable to avoid conflicts with custom pointer
                  myLocationButtonEnabled: false, // We'll create a custom button
                  onMapCreated: (c) => _mapController = c,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  mapType: maps.MapType.normal,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                
                // Status bar area
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).padding.top,
                    color: Colors.white,
                  ),
                ),
                
                // Header with back button and title
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Select Your Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Custom My Location Button (Aligned with search bar)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60, // Same level as search bar
                  right: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _getCurrentLocation,
                        icon: Icon(
                          Icons.my_location,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        tooltip: 'Get current location',
                      ),
                    ),
                  ),
                ),
                
                // Search bar with suggestions
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 16,
                  right: 76, // Leave space for location button
                  child: Column(
                    children: [
                      // Search input
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchLocation,
                            onTap: () {
                              if (_searchSuggestions.isNotEmpty) {
                                setState(() => _showSuggestions = true);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Search for apartment, street name...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                              suffixIcon: _isSearching
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _showSuggestions = false;
                                              _searchSuggestions.clear();
                                            });
                                          },
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Search suggestions dropdown
                      if (_showSuggestions && _searchSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _searchSuggestions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion.primaryText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: suggestion.secondaryText.isNotEmpty
                                    ? Text(
                                        suggestion.secondaryText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                    : null,
                                onTap: () => _selectSearchSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Static SVG Pointer Overlay (No Lag - Always Centered)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Custom SVG Pointer with Animation (Smaller Size)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.9 + (0.1 * value),
                            child: SvgPicture.asset(
                              'assets/map/pointer.svg',
                              width: 32,
                              height: 50,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                      // Enhanced shadow/ground indicator (Smaller)
                      Container(
                        width: 16,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Location details at bottom
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mainLocation,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fullAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (_isUpdatingAddress)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Confirm button at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}


