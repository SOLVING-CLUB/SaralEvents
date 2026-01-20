import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_planning_models.dart';
import '../services/event_planning_service.dart';
import 'event_details_screen.dart';
import 'create_event_screen.dart';
import 'budget_tracking_screen.dart';
import 'event_notes_screen.dart';
import 'checklist_screen.dart';
import 'guest_list_screen.dart';
import 'invitations_list_screen.dart';

// Simple value class for grid items
class _Tool {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _Tool({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late final EventPlanningService _eventService;
  
  
  List<Event> _allEvents = [];
  List<Event> _upcomingEvents = [];
  List<Event> _previousEvents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eventService = EventPlanningService(Supabase.instance.client);
    _loadEvents();
  }

  


  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Initialize sample data if needed (disabled for production to avoid repopulating)
      // await _eventService.initializeSampleData();
      
      final events = await _eventService.getEvents();
      final now = DateTime.now();
      
      setState(() {
        _allEvents = events;
        _upcomingEvents = events
            .where((event) => event.date.isAfter(now))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        _previousEvents = events
            .where((event) => event.date.isBefore(now))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToCreateEvent() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateEventScreen(),
      ),
    );
    
    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _navigateToEventDetails(Event event) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(event: event),
      ),
    );
    
    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Keep a copy for quick restore
      final Event deletedEvent = event;

      // Optimistic UI: remove immediately from lists to reflect deletion
      setState(() {
        _allEvents.removeWhere((e) => e.id == event.id);
        _upcomingEvents.removeWhere((e) => e.id == event.id);
        _previousEvents.removeWhere((e) => e.id == event.id);
      });

      // Show snackbar with Undo action
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${event.name}" deleted'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  // Recreate the event quickly
                  await _eventService.saveEvent(deletedEvent);
                  if (mounted) {
                    _loadEvents();
                  }
                },
              ),
            ),
          );
      }

      try {
        await _eventService.deleteEvent(event.id);
        // Final refresh to ensure state matches server/local storage
        _loadEvents();
      } catch (e) {
        // If something goes wrong, reload data to restore consistency
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete event: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Event Planning',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateEvent,
            tooltip: 'New Event',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildPlanningTools(),
                    Expanded(
                      child: _buildTimelineEventsList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPlanningTools() {
    final List<_Tool> tools = [
      _Tool(icon: Icons.account_balance_wallet, label: 'Budget', color: Colors.blue, onTap: _openBudget),
      _Tool(icon: Icons.note_alt, label: 'Notes', color: Colors.purple, onTap: _openNotes),
      _Tool(icon: Icons.checklist, label: 'Tasks', color: Colors.green, onTap: _openChecklist),
      _Tool(icon: Icons.group, label: 'Guests', color: Colors.teal, onTap: _openGuests),
      _Tool(icon: Icons.mail_outline, label: 'Invites', color: Colors.orange, onTap: _openInvites),
    ];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double containerPadding = width >= 700 ? 20 : 16;
        final double spacing = width >= 700 ? 16 : 12;

        final theme = Theme.of(context);
        return Container(
          margin: EdgeInsets.all(containerPadding),
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
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
              Text(
                'Planning Tools',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: spacing),
              // Use a custom grid layout for 5 items: 2-2-1 pattern
              Column(
                children: [
                  // First row: 2 items
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: tools[0].icon,
                          label: tools[0].label,
                          color: tools[0].color,
                          onTap: tools[0].onTap,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildToolCard(
                          icon: tools[1].icon,
                          label: tools[1].label,
                          color: tools[1].color,
                          onTap: tools[1].onTap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  // Second row: 2 items
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: tools[2].icon,
                          label: tools[2].label,
                          color: tools[2].color,
                          onTap: tools[2].onTap,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: _buildToolCard(
                          icon: tools[3].icon,
                          label: tools[3].label,
                          color: tools[3].color,
                          onTap: tools[3].onTap,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  // Third row: 1 item left-aligned with same width
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          icon: tools[4].icon,
                          label: tools[4].label,
                          color: tools[4].color,
                          onTap: tools[4].onTap,
                        ),
                      ),
                      Expanded(
                        child: Container(), // Empty space to maintain layout
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.north_east, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBudget() async {
    final event = await _promptSelectEvent();
    if (event == null) return;
    // Navigate to budget screen
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetTrackingScreen(event: event),
      ),
    );
  }

  Future<void> _openNotes() async {
    final event = await _promptSelectEvent();
    if (event == null) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventNotesScreen(event: event),
      ),
    );
  }

  Future<void> _openChecklist() async {
    final event = await _promptSelectEvent();
    if (event == null) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(event: event),
      ),
    );
  }

  Future<void> _openGuests() async {
    final event = await _promptSelectEvent();
    if (event == null) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuestListScreen(event: event),
      ),
    );
  }

  Future<Event?> _promptSelectEvent() async {
    // Prefer upcoming events first; if none, allow choosing from all
    final selectable = _upcomingEvents.isNotEmpty ? _upcomingEvents : _allEvents;
    if (selectable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an event first to use planning tools.')),
        );
      }
      return null;
    }

    if (selectable.length == 1) {
      return selectable.first;
    }

    return showModalBottomSheet<Event>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Event',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: selectable.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = selectable[index];
                    return ListTile(
                      title: Text(e.name),
                      subtitle: Text('${e.date.day}/${e.date.month}/${e.date.year}'),
                      leading: Icon(e.type.icon, color: e.type.color),
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openInvites() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const InvitationsListScreen(),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading events',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEvents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<Event> events, {required bool isUpcoming}) {
    if (events.isEmpty) {
      return _buildEmptyState(isUpcoming);
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event, isUpcoming: isUpcoming);
        },
      ),
    );
  }

  Widget _buildTimelineEventsList() {
    // Compose a single list: upcoming (soonest first), then previous (most recent past first)
    final List<Event> upcomingSorted = List<Event>.from(_upcomingEvents)
      ..sort((a, b) => a.date.compareTo(b.date));
    final List<Event> previousSorted = List<Event>.from(_previousEvents)
      ..sort((a, b) => b.date.compareTo(a.date));
    final List<Event> timeline = [...upcomingSorted, ...previousSorted];

    if (timeline.isEmpty) {
      return _buildEmptyState(true);
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: timeline.length,
        itemBuilder: (context, index) {
          final event = timeline[index];
          final bool isUpcoming = event.date.isAfter(DateTime.now());
          return _buildEventCard(event, isUpcoming: isUpcoming);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isUpcoming) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUpcoming ? Icons.event_available : Icons.event_busy,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isUpcoming ? 'No Upcoming Events' : 'No Previous Events',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUpcoming
                ? 'Create your first event to get started!'
                : 'Your completed events will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event, {required bool isUpcoming}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToEventDetails(event),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            _buildEventImage(event),
            
            // Event Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  event.type.icon,
                                  size: 16,
                                  color: event.type.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.type.displayName,
                                  style: TextStyle(
                                    color: event.type.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit Button
                      IconButton(
                        onPressed: () => _showEventOptions(event),
                        icon: const Icon(Icons.more_vert),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Event Date and Venue
                  _buildEventInfo(event, isUpcoming),
                  
                  const SizedBox(height: 12),
                  
                  // Payment Status
                  _buildPaymentStatus(event),
                  
                  if (isUpcoming) ...[
                    const SizedBox(height: 12),
                    // Countdown Timer
                    _buildCountdownTimer(event),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage(Event event) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: event.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: event.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: event.type.color.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      event.type.icon,
                      size: 48,
                      color: event.type.color,
                    ),
                  ),
                ),
              )
            : Container(
                color: event.type.color.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    event.type.icon,
                    size: 48,
                    color: event.type.color,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEventInfo(Event event, bool isUpcoming) {
    final dateFormat = '${event.date.day}/${event.date.month}/${event.date.year}';
    final timeFormat = '${event.date.hour.toString().padLeft(2, '0')}:${event.date.minute.toString().padLeft(2, '0')}';
    
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today, 
              size: 16, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              '$dateFormat at $timeFormat',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (event.venue != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on, 
                size: 16, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.venue!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentStatus(Event event) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: event.paymentStatus.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: event.paymentStatus.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            event.paymentStatus.icon,
            size: 16,
            color: event.paymentStatus.color,
          ),
          const SizedBox(width: 6),
          Text(
            event.paymentStatus.displayName,
            style: TextStyle(
              color: event.paymentStatus.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer(Event event) {
    final timeUntil = event.timeUntilEvent;
    
    if (timeUntil.isNegative) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_busy, 
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Event has passed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final days = timeUntil.inDays;
    final hours = timeUntil.inHours % 24;
    final minutes = timeUntil.inMinutes % 60;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$days days, $hours hours, $minutes minutes left',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventOptions(Event event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Event'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CreateEventScreen(event: event),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadEvents();
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Event'),
              onTap: () {
                Navigator.pop(context);
                _shareEvent(event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteEvent(event);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareEvent(Event event) {
    HapticFeedback.lightImpact();
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon!')),
    );
  }
}