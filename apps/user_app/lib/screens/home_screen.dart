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
import '../widgets/wishlist_button.dart';
import 'service_details_screen.dart';
import '../widgets/banner_widget.dart';
// import '../widgets/banner_debug_widget.dart'; // COMMENTED OUT
import '../widgets/featured_events_section.dart';
import '../widgets/events_section.dart';
// LocationPermissionBanner removed in favor of global transient banner
import '../services/banner_service.dart';
import '../services/featured_services_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {

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
    _loadData();
    // Precache category images to avoid flicker on first horizontal scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppImages.precacheAssets(
        context,
        _categories.map((c) => c['asset']!).toList(),
      );
      _attachSessionListenerAndLoadName();
      _loadActiveAddress();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload address when returning from location screen
    _loadActiveAddress();
  }

  @override
  void didPopNext() {
    // Called when returning to this screen from another screen
    _loadActiveAddress();
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
      if (!mounted) return;
      setState(() { 
        _activeAddress = activeAddress != null 
            ? AddressUtils.extractAreaName(activeAddress.address)
            : 'Select location';
      });
    } catch (_) {
      // Fallback to SharedPreferences if AddressStorage fails
      final prefs = await SharedPreferences.getInstance();
      final addr = prefs.getString('loc_address');
      if (!mounted) return;
      setState(() { 
        _activeAddress = addr != null 
            ? AddressUtils.extractAreaName(addr)
            : 'Select location';
      });
    }
  }

  Future<void> _loadData() async {
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

      setState(() { _featuredServices = services.take(6).toList(); });
      print('Loaded featured services: ${_featuredServices.length}');
    } catch (e) {
      print('Error loading data: $e');
      setState(() { _error = e.toString(); });
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
                      children: const [
                        Icon(Icons.card_giftcard, color: Color(0xFFFDBB42)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Create an E-Invitation for your event',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14),
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
                  setState(() {});
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _activeAddress ?? 'Select location',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey[700],
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon: Icon(Icons.tune, color: Colors.grey[500]),
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
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              GestureDetector(
                onTap: () => GoRouter.of(context).push('/categories'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.north_east,
                        size: 18,
                        color: Colors.black87,
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Events',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => GoRouter.of(context).push('/events'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey[600],
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
          height: 160,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.grey[400], size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading services',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDBB42),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _featuredServices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, color: Colors.grey[400], size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'No services available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _featuredServices.length,
                          itemBuilder: (context, index) {
                            final service = _featuredServices[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Stack(
                                children: [
                                  _buildEventCard(service),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: WishlistButton(serviceId: service.id, size: 34),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildEventCard(ServiceItem service) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: const Color(0xFFFDBB42).withOpacity(0.1),
              child: service.media.isNotEmpty
                  ? Image.network(service.media.first.url, fit: BoxFit.cover)
                  : Center(
                      child: Icon(
                        _getServiceIcon(service.name),
                        size: 32,
                        color: const Color(0xFFFDBB42),
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${service.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
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

  @override
  void dispose() {
    if (_sessionListener != null) {
      _sessionRef?.removeListener(_sessionListener!);
    }
    // Clean up subscriptions when leaving home screen
    BannerService.stopBannerSubscription();
    FeaturedServicesService.stopFeaturedServicesSubscription();
    super.dispose();
  }
}
