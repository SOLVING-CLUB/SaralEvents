import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/service_models.dart';
import '../services/service_service.dart';
import 'service_details_screen.dart';
import '../widgets/wishlist_button.dart';
import '../core/wishlist_notifier.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> 
    with AutomaticKeepAliveClientMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final ServiceService _serviceService;

  bool _loading = false;
  String? _error;
  List<ServiceItem> _services = <ServiceItem>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _serviceService = ServiceService(_supabase);
    
    // Initialize wishlist and load services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWishlist();
    });
    
    // Listen to wishlist changes
    WishlistNotifier.instance.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    WishlistNotifier.instance.removeListener(_onWishlistChanged);
    super.dispose();
  }

  Future<void> _initializeWishlist() async {
    if (WishlistNotifier.instance.wishlistIds.isEmpty && 
        !WishlistNotifier.instance.isLoading) {
      await WishlistNotifier.instance.initialize();
    }
    _loadServices();
  }

  void _onWishlistChanged() {
    if (mounted) {
      _loadServices();
    }
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    
    setState(() { 
      _loading = true; 
      _error = null; 
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() { _services = <ServiceItem>[]; });
        return;
      }

      final wishlistIds = WishlistNotifier.instance.wishlistIds.toList();
      if (wishlistIds.isEmpty) {
        setState(() { _services = <ServiceItem>[]; });
        return;
      }

      final items = await _serviceService.getServicesByIds(wishlistIds);
      
      if (mounted) {
        setState(() { 
          _services = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _error = e.toString();
          _services = <ServiceItem>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  Future<void> _onRefresh() async {
    await WishlistNotifier.instance.initialize();
    await _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite, 
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Wish List', 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: WishlistNotifier.instance,
                    builder: (context, _) {
                      final count = WishlistNotifier.instance.wishlistIds.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count items',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Your favorite services',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Content
            Expanded(
              child: ListenableBuilder(
                listenable: WishlistNotifier.instance,
                builder: (context, _) {
                  final isWishlistLoading = WishlistNotifier.instance.isLoading;
                  final wishlistError = WishlistNotifier.instance.error;
                  
                  if (isWishlistLoading || _loading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading your wishlist...'),
                        ],
                      ),
                    );
                  }
                  
                  if (wishlistError != null || _error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${wishlistError ?? _error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _onRefresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (_services.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [
                          const SizedBox(height: 120),
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'No items in your wishlist',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Start adding services you love!',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        final service = _services[index];
                        return _WishlistCard(
                          service: service,
                          onRemoved: () => _loadServices(),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback? onRemoved;

  const _WishlistCard({
    required this.service,
    this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceDetailsScreen(service: service),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 12,
                      child: service.media.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: Uri.encodeFull(service.media.first.url),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.vendorName,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '₹ ${service.price.toStringAsFixed(0)}/-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (service.ratingAvg != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Color(0xFFFFC107),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      service.ratingAvg!.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Wishlist button
        Positioned(
          top: 10,
          right: 10,
          child: WishlistButton(
            serviceId: service.id,
            size: 38,
            onToggle: onRemoved,
          ),
        ),
      ],
    );
  }
}
