import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/location_service.dart';
import '../core/services/address_storage.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:go_router/go_router.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  bool _checking = false;
  late final FlutterGooglePlacesSdk _places;
  final List<AddressInfo> _saved = <AddressInfo>[];
  final ScrollController _scroll = ScrollController();
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk('AIzaSyBdMMV-ceWqcoVKE_8bzMS50VARGEqT5zI');
    _loadSaved();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final permission = await geolocator.Geolocator.checkPermission();
    setState(() {
      _locationEnabled = permission == geolocator.LocationPermission.always || 
                        permission == geolocator.LocationPermission.whileInUse;
    });
  }

  Future<void> _loadSaved() async {
    _saved
      ..clear()
      ..addAll(await AddressStorage.loadSaved());
    setState(() {});
  }

  Future<void> _persistSaved() async {
    await AddressStorage.saveAll(_saved);
  }

  Future<void> _editAddress(AddressInfo address, int index) async {
    final controller = TextEditingController(text: address.label);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter address label',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final updatedAddress = AddressInfo(
        id: address.id,
        label: result,
        address: address.address,
        lat: address.lat,
        lng: address.lng,
      );
      _saved[index] = updatedAddress;
      await _persistSaved();
      setState(() {});
    }
  }

  Future<void> _deleteAddress(AddressInfo address, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _saved.removeAt(index);
      await _persistSaved();
      await AddressStorage.delete(address.id);
      setState(() {});
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _checking = true);
    try {
      // Check if permission is already granted
      if (!_locationEnabled) {
        final ok = await LocationService.ensurePermission();
        if (!ok) {
          if (!mounted) return;
          final snack = SnackBar(
            action: SnackBarAction(
              label: 'Settings',
              onPressed: geolocator.Geolocator.openAppSettings,
            ),
            content: const Text('Location permission is required. Enable it in Settings.'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snack);
          return;
        }
        // Update permission status
        setState(() => _locationEnabled = true);
      }
      
      final pos = await LocationService.getFreshPosition();
      final address = await LocationService.reverseGeocode(pos.latitude, pos.longitude) ??
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('loc_lat', pos.latitude);
      await prefs.setDouble('loc_lng', pos.longitude);
      await prefs.setString('loc_address', address);
      // Save/update Home entry
      final existingHomeIndex = _saved.indexWhere((e) => e.label.toLowerCase() == 'home');
      final home = AddressInfo(id: 'home', label: 'Home', address: address, lat: pos.latitude, lng: pos.longitude);
      if (existingHomeIndex >= 0) {
        _saved[existingHomeIndex] = home;
      } else {
        _saved.insert(0, home);
      }
      await _persistSaved();
      await AddressStorage.setActive(home, addToSaved: true);
      
      // Verify the address was set correctly
      final verifyActive = await AddressStorage.getActive();
      debugPrint('Set current location as Home: ${home.address}');
      debugPrint('Verified active address: ${verifyActive?.label} - ${verifyActive?.address}');
      
      if (!mounted) return;
      context.go('/app');
      // Small delay to ensure navigation completes
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlacesSearchField(
              places: _places,
              onSelected: (fullText, lat, lng) async {
                // Create new address
                final newAddress = AddressInfo(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  label: 'Other',
                  address: fullText,
                  lat: lat,
                  lng: lng,
                );
                
                // Add to saved addresses if not duplicate
                if (_saved.indexWhere((e) => e.address == fullText) < 0) {
                  _saved.add(newAddress);
                  await _persistSaved();
                }
                
                // Set as active address
                await AddressStorage.setActive(newAddress, addToSaved: true);
                
                // Verify the address was set correctly
                final verifyActive = await AddressStorage.getActive();
                debugPrint('Selected new address: ${newAddress.label} - ${newAddress.address}');
                debugPrint('Verified active address: ${verifyActive?.label} - ${verifyActive?.address}');
                
                if (!mounted) return;
                context.go('/app');
                // Small delay to ensure navigation completes before potential reload
                await Future.delayed(const Duration(milliseconds: 300));
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locationEnabled ? Icons.location_on : Icons.my_location, 
                    color: _locationEnabled 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationEnabled ? 'Use my Current Location' : 'Use my Current Location',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _locationEnabled 
                            ? 'Location is enabled. Tap to get current address'
                            : 'Enable your current location for better services',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_locationEnabled)
                    ElevatedButton(
                      onPressed: _checking ? null : _useCurrentLocation,
                      child: _checking
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enable'),
                    )
                  else
                    TextButton(
                      onPressed: _checking ? null : _useCurrentLocation,
                      child: _checking
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Get Location'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add New Address'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/location/map'),
            ),
            const SizedBox(height: 16),
            const Text('Saved Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_saved.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  'No saved addresses yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ListView.separated(
                controller: _scroll,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) {
                  final item = _saved[i];
                  return InkWell(
                    onTap: () async {
                      // Set the saved address as active
                      await AddressStorage.setActive(item, addToSaved: true);
                      
                      // Verify the address was set correctly
                      final verifyActive = await AddressStorage.getActive();
                      debugPrint('Selected saved address: ${item.label} - ${item.address}');
                      debugPrint('Verified active address: ${verifyActive?.label} - ${verifyActive?.address}');
                      
                      if (!mounted) return;
                      
                      // Navigate to app and ensure homepage reloads
                      // Using pushReplacement or go with a small delay to ensure state updates
                      context.go('/app');
                      
                      // Give the navigation a moment, then trigger reload if homepage is visible
                      await Future.delayed(const Duration(milliseconds: 300));
                    },
                    child: _SavedAddressCard(
                      label: item.label,
                      address: item.address,
                      selected: false,
                      onEdit: () => _editAddress(item, i),
                      onDelete: () => _deleteAddress(item, i),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _saved.length,
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final String label;
  final String address;
  final bool selected;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _SavedAddressCard({
    required this.label, 
    required this.address, 
    required this.selected,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(selected ? Icons.home : Icons.place_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE7F6ED), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Selected', style: TextStyle(color: Color(0xFF1B5E20))),
                    ),
                  ]
                ]),
                const SizedBox(height: 6),
                Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete, 
                      size: 20, 
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete', 
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlacesSearchField extends StatefulWidget {
  final FlutterGooglePlacesSdk places;
  final void Function(String fullText, double lat, double lng) onSelected;
  const _PlacesSearchField({required this.places, required this.onSelected});

  @override
  State<_PlacesSearchField> createState() => _PlacesSearchFieldState();
}

class _PlacesSearchFieldState extends State<_PlacesSearchField> {
  final TextEditingController _controller = TextEditingController();
  List<AutocompletePrediction> _predictions = [];
  bool _loading = false;

  Future<void> _onChanged(String value) async {
    if (value.length < 3) {
      setState(() => _predictions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await widget.places.findAutocompletePredictions(value,
          countries: const ['IN']);
      if (!mounted) return;
      setState(() => _predictions = res.predictions);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search Address',
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              Icons.search, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            suffixIcon: _loading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ) 
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predictions.length,
              itemBuilder: (_, i) {
                final p = _predictions[i];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.primaryText),
                  subtitle: Text(p.secondaryText),
                  onTap: () async {
                    setState(() => _loading = true);
                    try {
                      final res = await widget.places.fetchPlace(
                        p.placeId,
                        fields: [PlaceField.Location, PlaceField.Address],
                      );
                      final place = res.place;
                      final loc = place?.latLng;
                      final full = place?.address ?? p.fullText;
                      _controller.text = full;
                      setState(() => _predictions = []);
                      if (loc != null) {
                        widget.onSelected(full, loc.lat, loc.lng);
                      }
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
