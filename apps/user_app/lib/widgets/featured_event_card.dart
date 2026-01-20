import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/service_models.dart';
import '../widgets/wishlist_button.dart';

class FeaturedEventCard extends StatelessWidget {
  final ServiceItem service;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const FeaturedEventCard({
    super.key,
    required this.service,
    this.onTap,
    this.width = 180,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        // Outer spacing so cards don't stick to each other or edges
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with overlay elements
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Main image
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: service.media.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: service.media.first.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                  
                  // Subtle gradient overlay for better contrast
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Wishlist button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistButton(
                      serviceId: service.id,
                      size: 32,
                    ),
                  ),
                  
                  // Rating badge (if available)
                  if (service.ratingAvg != null && service.ratingAvg! > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 70),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Theme.of(context).colorScheme.primary,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                service.ratingAvg!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  

                ],
              ),
            ),
            
            // Content section with consistent inner padding
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Service name (flexible to take available space)
                    Flexible(
                      child: Text(
                        service.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Vendor name
                    Text(
                      service.vendorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Price and capacity info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price section (flexible to take available space)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Starting from',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '₹${_formatPrice(service.price)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Capacity or additional info (fixed width)
                        if (service.capacityMax != null)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 60),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 10,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    '${service.capacityMax}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFDBB42).withValues(alpha: 0.2),
            const Color(0xFFFDBB42).withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getServiceIcon(service.name),
          size: 40,
          color: const Color(0xFFFDBB42),
        ),
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

  String _formatPrice(double price) {
    if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)}L';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}K';
    } else {
      return price.toStringAsFixed(0);
    }
  }
}