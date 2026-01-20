import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/event_models.dart';
import '../screens/event_categories_screen.dart';

class EventsSection extends StatelessWidget {
  const EventsSection({super.key});

  void _onEventTapped(BuildContext context, EventType eventType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventCategoriesScreen(eventType: eventType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Events',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/events'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
            cacheExtent: 1200,
            itemCount: EventData.eventTypes.length,
            itemBuilder: (context, index) {
              final eventType = EventData.eventTypes[index];
              return _buildEventCard(context, eventType);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, EventType eventType) {
    return GestureDetector(
      onTap: () => _onEventTapped(context, eventType),
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
                child: Stack(
                  children: [
                    // Background image or fallback
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _getEventGradientColors(eventType.id),
                        ),
                      ),
                      child: _buildEventImage(context, eventType),
                    ),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    
                    // Event icon
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getEventIcon(eventType.iconName),
                          size: 20,
                          color: _getEventColor(eventType.id),
                        ),
                      ),
                    ),
                    
                    // Event name overlay
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Text(
                        eventType.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                              color: Theme.of(context).colorScheme.shadow.withOpacity(0.26),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                eventType.description,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage(BuildContext context, EventType eventType) {
    // For now, we'll use a placeholder with icon
    // In production, you would load actual images
    return Center(
      child: Icon(
        _getEventIcon(eventType.iconName),
        size: 60,
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
      ),
    );
  }

  List<Color> _getEventGradientColors(String eventId) {
    switch (eventId) {
      case 'wedding':
        return [
          const Color(0xFFE91E63).withValues(alpha: 0.8),
          const Color(0xFF9C27B0).withValues(alpha: 0.9),
        ];
      case 'birthday':
        return [
          const Color(0xFFFF9800).withValues(alpha: 0.8),
          const Color(0xFFFF5722).withValues(alpha: 0.9),
        ];
      case 'corporate':
        return [
          const Color(0xFF2196F3).withValues(alpha: 0.8),
          const Color(0xFF3F51B5).withValues(alpha: 0.9),
        ];
      case 'anniversary':
        return [
          const Color(0xFF4CAF50).withValues(alpha: 0.8),
          const Color(0xFF009688).withValues(alpha: 0.9),
        ];
      case 'engagement':
        return [
          const Color(0xFFE91E63).withValues(alpha: 0.7),
          const Color(0xFFF44336).withValues(alpha: 0.8),
        ];
      case 'baby_shower':
        return [
          const Color(0xFF9C27B0).withValues(alpha: 0.7),
          const Color(0xFF673AB7).withValues(alpha: 0.8),
        ];
      default:
        return [
          const Color(0xFF607D8B).withValues(alpha: 0.8),
          const Color(0xFF455A64).withValues(alpha: 0.9),
        ];
    }
  }

  Color _getEventColor(String eventId) {
    switch (eventId) {
      case 'wedding':
        return const Color(0xFFE91E63);
      case 'birthday':
        return const Color(0xFFFF9800);
      case 'corporate':
        return const Color(0xFF2196F3);
      case 'anniversary':
        return const Color(0xFF4CAF50);
      case 'engagement':
        return const Color(0xFFE91E63);
      case 'baby_shower':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  IconData _getEventIcon(String? iconName) {
    switch (iconName) {
      case 'favorite':
        return Icons.favorite;
      case 'cake':
        return Icons.cake;
      case 'business':
        return Icons.business;
      case 'celebration':
        return Icons.celebration;
      case 'diamond':
        return Icons.diamond;
      case 'child_care':
        return Icons.child_care;
      default:
        return Icons.event;
    }
  }
}