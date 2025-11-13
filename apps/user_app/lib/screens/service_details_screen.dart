import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/service_models.dart';
import '../services/service_service.dart';
import '../widgets/location_aware_widget.dart';
import '../widgets/wishlist_button.dart';
import '../utils/deep_link_helper.dart';
import 'booking_screen.dart';


class ServiceDetailsScreen extends StatefulWidget {
  final ServiceItem service;
  const ServiceDetailsScreen({super.key, required this.service});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> 
    with TickerProviderStateMixin {
  late final ServiceService _serviceService;
  late final TabController _tabController;
  late final PageController _imagePageController;
  
  List<ServiceItem> _similarServices = <ServiceItem>[];
  VendorProfile? _vendorProfile;
  bool _isLoading = true;
  String? _error;
  int _currentImageIndex = 0;
  bool _showFullDescription = false;

  @override
  void initState() {
    super.initState();
    _serviceService = ServiceService(Supabase.instance.client);
    _tabController = TabController(length: 4, vsync: this);
    _imagePageController = PageController();
    _loadServiceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadServiceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load similar services
      final allServices = await _serviceService.getAllServices();
      final similarServices = allServices
          .where((s) => 
            s.id != widget.service.id && 
            s.categoryId == widget.service.categoryId)
          .take(10)
          .toList();

      // Load vendor profile (if needed - for now using existing data)
      final vendorProfile = VendorProfile(
        id: widget.service.vendorId,
        businessName: widget.service.vendorName,
        address: 'Hyderabad, Telangana', // This should come from database
        category: 'Event Services',
      );

      if (mounted) {
        setState(() {
          _similarServices = similarServices;
          _vendorProfile = vendorProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Service Details'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Service Details'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading service details: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadServiceData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with Image Gallery
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: Colors.black,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareService(service),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: WishlistButton(serviceId: service.id, size: 40),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageGallery(service),
            ),
          ),
          // Main Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Service Header Information
                _buildServiceHeader(service),
                
                // Price and Action Buttons
                _buildPriceAndActions(service),
                
                // Tab Navigation
                _buildTabNavigation(),
                
                // Tab Content
                _buildTabContent(service),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button for Quick Booking
      floatingActionButton: _buildFloatingBookingButton(service),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Build Image Gallery
  Widget _buildImageGallery(ServiceItem service) {
    if (service.media.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
              SizedBox(height: 8),
              Text('No images available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _imagePageController,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemCount: service.media.length,
          itemBuilder: (context, index) {
            final media = service.media[index];
            return GestureDetector(
              onTap: () => _showImageGallery(service.media, index),
              child: CachedNetworkImage(
                imageUrl: Uri.encodeFull(media.url),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error, color: Colors.red),
                ),
              ),
            );
          },
        ),
        
        // Image Counter
        if (service.media.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${service.media.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        
        // Navigation Arrows
        if (service.media.length > 1) ...[
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    if (_currentImageIndex > 0) {
                      _imagePageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () {
                    if (_currentImageIndex < service.media.length - 1) {
                      _imagePageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Build Service Header
  Widget _buildServiceHeader(ServiceItem service) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Name and Vendor
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            service.vendorName,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Verification Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Location and Distance
          LocationAwareWidget(
            requestPermissionOnInit: false,
            showPermissionDialog: false,
            builder: (context, position, hasPermission) {
              return Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _vendorProfile?.address ?? 'Hyderabad, Telangana',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  if (hasPermission && position != null)
                    DistanceWidget(
                      latitude: 17.3850, // This should come from service data
                      longitude: 78.4867,
                      textStyle: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Rating and Reviews
          Row(
            children: [
              if (service.ratingAvg != null) ...[
                Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 4),
                Text(
                  service.ratingAvg!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                service.ratingCount != null && service.ratingCount! > 0
                    ? '${service.ratingCount} reviews'
                    : 'No reviews yet',
                style: const TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllReviews(service),
                child: const Text('See all reviews'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Service Features
          _buildServiceFeatures(service),
          
          const SizedBox(height: 16),
          
          // Tags
          if (service.suitedFor.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.suitedFor.map((tag) => _buildTag(tag)).toList(),
            ),
        ],
      ),
    );
  }

  // Build Service Features
  Widget _buildServiceFeatures(ServiceItem service) {
    final features = <Map<String, dynamic>>[];
    
    if (service.capacityMin != null && service.capacityMax != null) {
      features.add({
        'icon': Icons.group,
        'label': 'Capacity',
        'value': '${service.capacityMin}-${service.capacityMax} guests',
      });
    }
    
    if (service.parkingSpaces != null) {
      features.add({
        'icon': Icons.local_parking,
        'label': 'Parking',
        'value': '${service.parkingSpaces}+ spaces',
      });
    }
    
    // Add more features from service.features
    service.features.forEach((key, value) {
      features.add({
        'icon': Icons.check_circle_outline,
        'label': key,
        'value': value.toString(),
      });
    });

    if (features.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(feature['icon'], size: 20, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['label'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      feature['value'],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // Build Price and Actions
  Widget _buildPriceAndActions(ServiceItem service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${service.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Text(
                  'Starting price',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _bookService(service),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Book Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4B63E),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Build Tab Navigation
  Widget _buildTabNavigation() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFF4B63E),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFF4B63E),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Reviews'),
          Tab(text: 'Vendor'),
          Tab(text: 'Similar'),
        ],
      ),
    );
  }

  // Build Tab Content
  Widget _buildTabContent(ServiceItem service) {
    return SizedBox(
      height: 600, // Fixed height for tab content
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(service),
          _buildReviewsTab(service),
          _buildVendorTab(service),
          _buildSimilarTab(),
        ],
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab(ServiceItem service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (service.description.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              service.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
              maxLines: _showFullDescription ? null : 3,
              overflow: _showFullDescription ? null : TextOverflow.ellipsis,
            ),
            if (service.description.length > 150)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showFullDescription = !_showFullDescription;
                  });
                },
                child: Text(_showFullDescription ? 'Show less' : 'Show more'),
              ),
            const SizedBox(height: 24),
          ],
          
          // Policies
          if (service.policies.isNotEmpty) ...[
            const Text(
              'Policies & Terms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...service.policies.map((policy) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(policy)),
                ],
              ),
            )),
            const SizedBox(height: 24),
          ],
          
          // Additional Features
          if (service.features.isNotEmpty) ...[
            const Text(
              'Additional Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...service.features.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  // Reviews Tab
  Widget _buildReviewsTab(ServiceItem service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Summary
          _buildRatingSummary(service),
          const SizedBox(height: 24),
          
          // Reviews List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddReviewDialog(service),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDBB42),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sample Reviews (In real app, fetch from database)
          _buildReviewItem(
            'Aysha Mishra',
            5,
            '2 days ago',
            'Excellent service! The venue was perfect for our wedding. Great staff and beautiful decorations.',
          ),
          _buildReviewItem(
            'Rajul Jayakrya',
            4,
            '1 week ago',
            'Good location and service. Our family enjoyed the event. Parking was convenient.',
          ),
          _buildReviewItem(
            'Priya Sharma',
            5,
            '2 weeks ago',
            'Amazing experience! Highly recommended for any celebration. Professional team.',
          ),
          
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => _showAllReviews(service),
              child: const Text('View All Reviews'),
            ),
          ),
        ],
      ),
    );
  }

  // Vendor Tab
  Widget _buildVendorTab(ServiceItem service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor Header
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  service.vendorName.isNotEmpty 
                      ? service.vendorName[0].toUpperCase()
                      : 'V',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.vendorName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vendorProfile?.category ?? 'Event Services',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Vendor Stats
          Row(
            children: [
              Expanded(
                child: _buildVendorStat('Services', '12+'),
              ),
              Expanded(
                child: _buildVendorStat('Experience', '5+ years'),
              ),
              Expanded(
                child: _buildVendorStat('Rating', '4.8'),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Contact Information
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildContactItem(
            Icons.location_on,
            'Address',
            _vendorProfile?.address ?? 'Hyderabad, Telangana',
            () => _openMap(service),
          ),
          _buildContactItem(
            Icons.phone,
            'Phone',
            '+91 98765 43210',
            () => _contactVendor(service),
          ),
          _buildContactItem(
            Icons.email,
            'Email',
            'contact@${service.vendorName.toLowerCase().replaceAll(' ', '')}.com',
            () => _emailVendor(service),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          ElevatedButton.icon(
            onPressed: () => _chatWithVendor(service),
            icon: const Icon(Icons.chat),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4B63E),
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Similar Services Tab
  Widget _buildSimilarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Similar Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_similarServices.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No similar services found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _similarServices.length,
              itemBuilder: (context, index) {
                final service = _similarServices[index];
                return _buildSimilarServiceCard(service);
              },
            ),
        ],
      ),
    );
  }

  // Helper Methods
  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRatingSummary(ServiceItem service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                service.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 16,
                    color: index < (service.ratingAvg?.round() ?? 0)
                        ? Colors.amber
                        : Colors.grey.shade300,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${service.ratingCount ?? 0} reviews',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final rating = 5 - index;
                final percentage = 0.8 - (index * 0.15); // Sample data
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$rating'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.amber.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String name, int rating, String date, String review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              size: 14,
                              color: index < rating
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarServiceCard(ServiceItem service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ServiceDetailsScreen(service: service),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: service.media.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: Uri.encodeFull(service.media.first.url),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.vendorName,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${service.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        if (service.ratingAvg != null) ...[
                          Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            service.ratingAvg!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBookingButton(ServiceItem service) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _bookService(service),
        icon: const Icon(Icons.calendar_today),
        label: const Text(
          'Check Availability & Book',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF4B63E),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // Action Methods
  Future<void> _shareService(ServiceItem service) async {
    HapticFeedback.lightImpact();
    
    final universalLink = DeepLinkHelper.serviceUniversalLink(service.id.toString());
    final deepLink = DeepLinkHelper.serviceLink(service.id.toString());
    
    final shareText = '''🌟 Check out this service: ${service.name}

Vendor: ${service.vendorName}
Starting from: ₹${service.price.toStringAsFixed(0)}
${service.description.isNotEmpty ? '\n${service.description.substring(0, service.description.length > 100 ? 100 : service.description.length)}...' : ''}

Open in app:
$universalLink

Or use custom link:
$deepLink

Tap the link above to view and book on Saral Events! 🎉''';

    try {
      await Share.share(shareText, subject: 'Check out: ${service.name}');
    } catch (e) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: deepLink));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  void _showImageGallery(List<MediaItem> media, int initialIndex) {
    // Implement full-screen image gallery
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImageGalleryScreen(
          media: media,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _bookService(ServiceItem service) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(service: service),
      ),
    );
  }

  void _contactVendor(ServiceItem service) async {
    HapticFeedback.lightImpact();
    final phoneNumber = '+919876543210'; // This should come from vendor data
    final uri = Uri.parse('tel:$phoneNumber');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  void _emailVendor(ServiceItem service) async {
    HapticFeedback.lightImpact();
    final email = 'contact@${service.vendorName.toLowerCase().replaceAll(' ', '')}.com';
    final uri = Uri.parse('mailto:$email?subject=Inquiry about ${service.name}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email client')),
        );
      }
    }
  }

  void _chatWithVendor(ServiceItem service) {
    HapticFeedback.lightImpact();
    // Implement chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat functionality coming soon!')),
    );
  }

  void _openMap(ServiceItem service) async {
    HapticFeedback.lightImpact();
    // Open maps with vendor location
    final address = Uri.encodeComponent(_vendorProfile?.address ?? 'Hyderabad, Telangana');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  void _showAddReviewDialog(ServiceItem service) {
    showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final reviewController = TextEditingController();
        int selectedRating = 5;
        final nameController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDBB42),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add Review',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Service Name
                            Text(
                              'Reviewing: ${service.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Your Name
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Your Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Rating
                        const Text(
                          'Rating *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedRating = index + 1;
                                });
                              },
                              icon: Icon(
                                Icons.star,
                                size: 36,
                                color: index < selectedRating
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        
                        // Review
                        TextFormField(
                          controller: reviewController,
                          decoration: const InputDecoration(
                            labelText: 'Write your review *',
                            border: OutlineInputBorder(),
                            hintText: 'Share your experience...',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please write your review';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    Navigator.pop(context);
                                    // TODO: Save review to database
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Review submitted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDBB42),
                                  foregroundColor: Colors.black87,
                                ),
                                child: const Text('Submit'),
                              ),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAllReviews(ServiceItem service) {
    // Navigate to reviews screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reviews screen coming soon!')),
    );
  }

}

// Full-screen Image Gallery
class _ImageGalleryScreen extends StatefulWidget {
  final List<MediaItem> media;
  final int initialIndex;

  const _ImageGalleryScreen({
    required this.media,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.media.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.media.length,
        itemBuilder: (context, index) {
          final media = widget.media[index];
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: Uri.encodeFull(media.url),
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.white, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


