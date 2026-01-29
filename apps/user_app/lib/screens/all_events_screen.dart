import 'package:flutter/material.dart';
import '../core/theme/color_tokens.dart';
import '../models/event_models.dart';
import 'event_categories_screen.dart';

class AllEventsScreen extends StatelessWidget {
  const AllEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: ColorTokens.textPrimary(context),
          ),
        ),
        backgroundColor: ColorTokens.bgApp(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: EventData.eventTypes.length,
        itemBuilder: (context, index) {
          final eventType = EventData.eventTypes[index];
          return _buildEventCard(context, eventType);
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventType eventType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventCategoriesScreen(eventType: eventType),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getEventGradientColors(eventType.id),
            ),
          ),
          child: Stack(
            children: [
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
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
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getEventIcon(eventType.iconName),
                    size: 28,
                    color: _getEventColor(eventType.id),
                  ),
                ),
              ),
              
              // Event name
              Positioned(
                bottom: 16,
                left: 16,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventType.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eventType.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
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
