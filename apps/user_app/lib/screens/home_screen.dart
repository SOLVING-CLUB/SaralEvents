import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/session.dart';
import '../core/ui/image_utils.dart';
import '../core/services/address_storage.dart';
import '../core/utils/address_utils.dart';
import '../models/service_models.dart';
import 'catalog_screen.dart';
import 'profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';
import 'service_details_screen.dart';
import '../widgets/banner_widget.dart';
// import '../widgets/banner_debug_widget.dart'; // COMMENTED OUT
import '../widgets/featured_events_section.dart';
import '../widgets/events_section.dart';
// LocationPermissionBanner removed in favor of global transient banner
import '../services/banner_service.dart';
import '../services/featured_services_service.dart';
import '../core/services/location_service.dart';
import '../core/services/location_session_manager.dart';
import '../core/theme/color_tokens.dart';
import '../widgets/location_startup_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/order_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {

  // Static categories with asset mapping to match the provided UI
  final List<Map<String, String>> _categories = [
    {
      'name': 'Photography',
      'asset': 'assets/default_images/category_photoghraphy.jpg',
    },
    {
      'name': 'Decoration',
      'asset': 'assets/default_images/category_decoration.jpg',
    },
    {
      'name': 'Catering',
      'asset': 'assets/default_images/category_catering.jpg',
    },
    {
      'name': 'Venue',
      'asset': 'assets/default_images/category_venue.jpg',
    },
    {
      'name': 'Farmhouse',
      'asset': 'assets/default_images/category_farmhouse.jpeg',
    },
    {
      'name': 'Music/Dj',
      'asset': 'assets/default_images/category_musicDj.jpg',
    },
    {
      'name': 'Essentials',
      'asset': 'assets/default_images/category_essentials.jpg',
    },
  ];

  List<ServiceItem> _featuredServices = <ServiceItem>[];
  bool _isLoading = true;
  String? _error;
  String? _displayName;
  VoidCallback? _sessionListener;
  UserSession? _sessionRef;
  String? _avatarUrl;
  String? _activeAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // Precache category images to avoid flicker on first horizontal scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppImages.precacheAssets(
        context,
        _categories.map((c) => c['asset']!).toList(),
      );
      _attachSessionListenerAndLoadName();
      // Load address first, then check location (which will reload address if needed)
      _loadActiveAddress();
      // Check location and show bottom sheet if needed
      // This will also reload address after location is set
      _checkLocationAndShowBottomSheet();
    });
  }

  bool _hasAppBeenInBackground = false;
  bool _isInitialStartup = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Track if app has been in background
    // But ignore lifecycle changes during initial startup (first few seconds)
    if (_isInitialStartup) {
      // Wait a bit before tracking background state
      // This prevents false positives during app startup
      Future.delayed(const Duration(seconds: 2), () {
        _isInitialStartup = false;
      });
      return;
    }
    
    // Only track background state after initial startup is complete
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _hasAppBeenInBackground = true;
      debugPrint('App went to background');
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed from background');
    }
  }

  /// Check location status and show bottom sheet if needed
  /// Follows Swiggy Instamart-style location handling
  /// 
  /// LOGIC FLOW:
  /// 1️⃣ Check if user has valid last-selected location → Use it, don't show bottom sheet
  /// 2️⃣ If no location → Check if already resolved this session → Skip if yes
  /// 3️⃣ If not resolved → Check permission & GPS status
  /// 4️⃣ If permission granted AND GPS ON → Auto-fetch location (don't show bottom sheet)
  /// 5️⃣ If permission denied OR GPS OFF → Show bottom sheet (non-dismissible)
  /// 
  /// SESSION BEHAVIOR:
  /// - Only runs on cold start (app process created)
  /// - Skips on background/foreground transitions
  /// - Flags reset in main.dart on every app start
  Future<void> _checkLocationAndShowBottomSheet() async {
    // Skip if app was resumed from background (not a cold start)
    if (_hasAppBeenInBackground && !_isInitialStartup) {
      debugPrint('🔄 App resumed from background - skipping location check');
      return;
    }
    
    // Wait for UI to be ready
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    debugPrint('🚀 Starting location check (cold start)');
    
    // Step 1: Check if user has valid last-selected location
    final hasValidLocation = await LocationSessionManager.hasValidLastSelectedLocation();
    if (hasValidLocation) {
      debugPrint('✅ Valid last-selected location exists - using it, NOT showing bottom sheet');
      await LocationSessionManager.markLocationResolvedThisSession();
      // Load the address to display it
      _loadActiveAddress();
      return;
    }
    
    // Step 2: Check if location was already resolved this session
    final wasResolved = await LocationSessionManager.wasLocationResolvedThisSession();
    if (wasResolved) {
      debugPrint('✅ Location already resolved this session - NOT showing bottom sheet');
      _loadActiveAddress();
      return;
    }
    
    // Step 3: Get location state (permission + GPS)
    final state = await LocationSessionManager.getLocationState();
    debugPrint('📍 Location state: GPS=${state.isServiceEnabled}, Permission=${state.permissionStatus}');
    
    // Step 4: If permission granted AND GPS ON → Try auto-fetch
    if (state.canAutoFetch) {
      debugPrint('📍 Permission granted & GPS ON - attempting auto-fetch');
      await LocationSessionManager.markLocationResolvedThisSession();
      await _fetchLocationDirectly();
      return;
    }
    
    // Step 5: If permission denied OR GPS OFF → Show bottom sheet
    debugPrint('📍 Permission denied OR GPS OFF - showing bottom sheet');
    await LocationSessionManager.markLocationResolvedThisSession();
    await _showLocationBottomSheet();
  }
  
  /// Show location bottom sheet (non-dismissible)
  Future<void> _showLocationBottomSheet() async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Cannot dismiss by tapping outside
      enableDrag: false, // Cannot dismiss by swiping down
      builder: (context) => const LocationStartupBottomSheet(),
    ).then((result) async {
      // Bottom sheet closed - address was selected or location resolved
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        debugPrint('📍 Bottom sheet closed - reloading address');
        _loadActiveAddress();
        
        // Save last selected location ID
        final activeAddress = await AddressStorage.getActive();
        if (activeAddress != null) {
          await LocationSessionManager.saveLastSelectedLocationId(activeAddress.id);
        }
      }
    });
  }

  /// Fetch location directly when service is enabled and permission is granted
  /// Auto-detection attempt (only once per session)
  Future<void> _fetchLocationDirectly() async {
    try {
      debugPrint('📍 Auto-fetching location...');
      
      // Get current location
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
      
      // Small delay to ensure save operation completes
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Reload address to update UI
      if (mounted) {
        _loadActiveAddress();
      }
      
      debugPrint('✅ Location auto-fetched successfully: ${addressInfo.address}');
    } catch (e) {
      debugPrint('❌ Error auto-fetching location: $e');
      // If auto-fetch fails, show bottom sheet as fallback
      await _showLocationBottomSheet();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload address when returning from location screen
    // Use postFrameCallback to ensure this runs after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadActiveAddress();
      }
    });
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    // Use postFrameCallback to ensure this runs after navigation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadActiveAddress();
      }
    });
  }

  void _attachSessionListenerAndLoadName() {
    _sessionRef = Provider.of<UserSession>(context, listen: false);
    _sessionListener = () { _loadDisplayName(); };
    _sessionRef!.addListener(_sessionListener!);
    _loadDisplayName();
    // Also listen for address changes when page resumes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveAddress();
    });
  }

  Future<void> _loadDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    final emailPrefix = user?.email?.split('@').first;
    if (user == null) {
      if (!mounted) return;
      setState(() { _displayName = emailPrefix ?? 'User'; _avatarUrl = null; });
      return;
    }
    final profile = await ProfileService(Supabase.instance.client).getProfile(user.id);
    final first = (profile?['first_name'] as String?)?.trim();
    final last = (profile?['last_name'] as String?)?.trim();
    final full = [first, last].where((e) => e != null && e.isNotEmpty).join(' ').trim();
    final dynamicMeta = user.userMetadata;
    final Map<String, dynamic> authMeta =
        (dynamicMeta is Map<String, dynamic>) ? dynamicMeta : const <String, dynamic>{};
    final fallbackAvatar = (authMeta['avatar_url'] ?? authMeta['picture']) as String?;
    if (!mounted) return;
    setState(() {
      _displayName = (full.isNotEmpty) ? full : (emailPrefix ?? 'User');
      _avatarUrl = (profile?['image_url'] as String?) ?? fallbackAvatar;
    });
  }

  Future<void> _loadActiveAddress() async {
    try {
      final activeAddress = await AddressStorage.getActive();
      debugPrint('Loading active address: ${activeAddress?.label} - ${activeAddress?.address}');
      
      if (!mounted) return;
      final displayAddress = activeAddress != null 
          ? AddressUtils.extractAreaName(activeAddress.address)
          : 'Select location';
      
      debugPrint('Setting homepage address display to: $displayAddress');
      
      setState(() { 
        _activeAddress = displayAddress;
      });
    } catch (e) {
      debugPrint('Error loading active address: $e');
      // Fallback to SharedPreferences if AddressStorage fails
      try {
        final prefs = await SharedPreferences.getInstance();
        final addr = prefs.getString('loc_address');
        if (!mounted) return;
        final displayAddress = addr != null 
            ? AddressUtils.extractAreaName(addr)
            : 'Select location';
        debugPrint('Using fallback address: $displayAddress');
        setState(() { 
          _activeAddress = displayAddress;
        });
      } catch (e2) {
        debugPrint('Error in fallback address loading: $e2');
        if (!mounted) return;
        setState(() {
          _activeAddress = 'Select location';
        });
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      print('Starting to load data...');
      final client = Supabase.instance.client;
      final result = await client
          .from('services')
          .select('*')
          .eq('is_active', true)
          .eq('is_visible_to_users', true)
          .eq('is_featured', true)
          .order('updated_at', ascending: false)
          .limit(12);

      final services = (result as List<dynamic>).map((row) => ServiceItem(
        id: row['id'],
        categoryId: row['category_id'],
        name: row['name'],
        price: (row['price'] ?? 0).toDouble(),
        tags: List<String>.from(row['tags'] ?? []),
        description: row['description'] ?? '',
        media: (row['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url.toString(), type: MediaType.image))
                .toList() ?? [],
        vendorId: row['vendor_id'] ?? '',
        vendorName: '',
      )).toList();

      if (mounted) {
        setState(() { _featuredServices = services.take(6).toList(); });
        print('Loaded featured services: ${_featuredServices.length}');
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() { _error = e.toString(); });
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }


  void _onCategoryTapped(String categoryName) {
    print('Category tapped: $categoryName');
    
    // Navigate to catalog page with category filter
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CatalogScreen(selectedCategory: categoryName),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    try {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with profile and greeting
              _buildHeader(),
              const SizedBox(height: 20),
              
              // Location permission banner removed; global banner is shown by PermissionManager
              
              // Search bar
              _buildSearchBar(),
              const SizedBox(height: 20),
              
              // Hero banner
              _buildHeroBanner(),
              const SizedBox(height: 24),
              // Quick create invitation CTA moved just below banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => GoRouter.of(context).push('/invites'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDBB42).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.card_giftcard, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Create an E-Invitation for your event',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios, 
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Categories section
              _buildCategoriesSection(),
              const SizedBox(height: 24),
              
              // Events section
              const EventsSection(),
              const SizedBox(height: 24),
              
              // Enhanced Events section with real-time updates
              FeaturedEventsSection(
                onSeeAllTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CatalogScreen(),
                    ),
                  );
                },
                onServiceTap: (service) {
                  // Navigate to service details
                  debugPrint('Tapped on service: ${service.name}');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailsScreen(service: service),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error building home screen: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading home screen: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (mounted) setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Consumer<UserSession>(
      builder: (context, session, _) {
        final user = session.currentUser;
        print('User session: $session');
        print('Current user: $user');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Profile picture
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFFDBB42),
                  backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // Greeting and location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_displayName ?? user?.email?.split('@').first ?? 'User'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => GoRouter.of(context).push('/location/select'),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _activeAddress ?? 'Select location',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down, 
                            size: 16, 
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Debug button (only in debug mode) - COMMENTED OUT
              // if (kDebugMode)
              //   GestureDetector(
              //     onTap: () {
              //       Navigator.of(context).push(
              //         MaterialPageRoute(
              //           builder: (context) => const BannerDebugWidget(),
              //         ),
              //       );
              //     },
              //     child: Container(
              //       width: 40,
              //       height: 40,
              //       decoration: BoxDecoration(
              //         color: Colors.blue[100],
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //       child: Icon(
              //         Icons.bug_report,
              //         color: Colors.blue[700],
              //         size: 20,
              //       ),
              //     ),
              //   ),
              // 
              // const SizedBox(width: 8),
              
              // Notification bell
              GestureDetector(
                onTap: () {
                  context.push('/notifications');
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                      // Badge for unread notifications
                      FutureBuilder<int>(
                        future: _getUnreadNotificationCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              Icons.search, 
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            suffixIcon: Icon(
              Icons.tune, 
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onTap: () {
            // Navigate to catalog with search
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CatalogScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SmartBannerWidget(
        aspectRatio: 16 / 9,
        borderRadius: BorderRadius.circular(16),
        fit: BoxFit.cover,
        fallbackAsset: 'assets/onboarding/onboarding_1.jpg',
        autoPlay: true,
        autoPlayDuration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              GestureDetector(
                onTap: () => GoRouter.of(context).push('/categories'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ColorTokens.bgSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ColorTokens.borderDefault(context).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ColorTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.north_east,
                        size: 18,
                        color: ColorTokens.iconPrimary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            cacheExtent: 1200, // keep multiple items decoded in cache
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final item = _categories[index];
              return _buildImageCategoryCard(item['name']!, item['asset']!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageCategoryCard(String categoryName, String assetPath) {
    return GestureDetector(
      onTap: () => _onCategoryTapped(categoryName),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Builder(builder: (context) {
                  return AppImages.asset(
                    assetPath,
                    targetLogicalWidth: 220,
                    aspectRatio: 16 / 10,
                    fit: BoxFit.cover,
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                categoryName,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(ServiceItem service) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event image
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            child: Container(
              height: 100,
              width: double.infinity,
              color: theme.colorScheme.primary.withOpacity(0.1),
              child: service.media.isNotEmpty
                  ? Image.network(service.media.first.url, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        _getServiceIcon(service.name),
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
          ),
          
          // Event details
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${service.price.toStringAsFixed(0)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('photography') || name.contains('photo') || name.contains('camera')) {
      return Icons.camera_alt;
    } else if (name.contains('catering') || name.contains('food') || name.contains('meal')) {
      return Icons.restaurant;
    } else if (name.contains('decoration') || name.contains('decor') || name.contains('flower')) {
      return Icons.local_florist;
    } else if (name.contains('music') || name.contains('dj') || name.contains('sound')) {
      return Icons.music_note;
    } else if (name.contains('venue') || name.contains('hall') || name.contains('place')) {
      return Icons.location_on;
    } else if (name.contains('transport') || name.contains('car') || name.contains('vehicle')) {
      return Icons.directions_car;
    } else if (name.contains('makeup') || name.contains('beauty') || name.contains('salon')) {
      return Icons.face;
    } else if (name.contains('dress') || name.contains('clothing') || name.contains('suit')) {
      return Icons.checkroom;
    } else {
      return Icons.miscellaneous_services;
    }
  }

  Future<int> _getUnreadNotificationCount() async {
    try {
      final service = OrderNotificationService(Supabase.instance.client);
      return await service.getUnreadCount();
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_sessionListener != null) {
      _sessionRef?.removeListener(_sessionListener!);
    }
    // Clean up subscriptions when leaving home screen
    BannerService.stopBannerSubscription();
    FeaturedServicesService.stopFeaturedServicesSubscription();
    super.dispose();
  }
}
