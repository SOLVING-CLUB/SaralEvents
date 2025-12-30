import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_planning_models.dart';
import '../services/event_planning_service.dart';
import 'checklist_screen.dart';
import 'guest_list_screen.dart';
import 'event_notes_screen.dart';
import 'create_event_screen.dart';
import 'budget_tracking_screen.dart';
import 'invitations_list_screen.dart';
import 'dart:async';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final EventPlanningService _eventService;
  
  late Event _event;
  EventStatistics? _statistics;
  Timer? _countdownTimer;
  Duration _timeUntilEvent = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _eventService = EventPlanningService(Supabase.instance.client);
    _loadEventData();
    _startCountdownTimer();

    // Subscribe to real-time updates for tasks to refresh stats in place
    _eventService.subscribeToTaskUpdates(_event.id, (_) {
      if (mounted) {
        _loadEventData();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _eventService.unsubscribeFromUpdates();
    super.dispose();
  }

  Future<void> _loadEventData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh event data
      final updatedEvent = await _eventService.getEvent(_event.id);
      if (updatedEvent != null) {
        _event = updatedEvent;
      }

      // Load statistics
      final stats = await _eventService.getEventStatistics(_event.id);
      
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final timeUntil = _event.date.difference(now);
    
    if (mounted) {
      setState(() {
        _timeUntilEvent = timeUntil;
      });
    }
  }

  double _computeTaskProgressBar() {
    final int total = _statistics?.totalTasks ?? 0;
    final double pct = (_statistics?.taskCompletionPercentage ?? 0) / 100.0;
    if (total <= 0) return 0.0; // 0/0 -> show empty bar
    return pct.clamp(0.0, 1.0);
  }

  double? _computeBudgetProgressBar() {
    final double budget = _event.budget ?? 0;
    if (budget <= 0) return null; // hide bar if no budget set
    final double spent = (_event.spentAmount ?? 0).toDouble();
    return (spent / budget).clamp(0.0, 1.0);
  }

  Future<void> _navigateToEditEvent() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(event: _event),
      ),
    );
    
    if (result == true) {
      _loadEventData();
    }
  }

  Future<void> _navigateToChecklist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(event: _event),
      ),
    );
    
    // Always refresh after returning to reflect any changes
    _loadEventData();
  }

  Future<void> _navigateToGuestList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GuestListScreen(event: _event),
      ),
    );
    
    _loadEventData();
  }

  Future<void> _navigateToNotes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventNotesScreen(event: _event),
      ),
    );
    
    _loadEventData();
  }

  Future<void> _navigateToBudget() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BudgetTrackingScreen(event: _event),
      ),
    );
    _loadEventData();
  }

  Future<void> _navigateToEInvites() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const InvitationsListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Event Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _event.type.color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildEventHeader(),
            ),
            actions: [
              IconButton(
                onPressed: _navigateToEditEvent,
                icon: const Icon(Icons.edit),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // Event Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Event Info Card
                _buildEventInfoCard(),
                
                // Countdown Timer
                if (_event.isUpcoming) _buildCountdownCard(),
                
                // Management Modules
                _buildManagementModules(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image or Color
        _event.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: _event.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: _event.type.color.withValues(alpha: 0.3),
                ),
                errorWidget: (context, url, error) => Container(
                  color: _event.type.color.withValues(alpha: 0.3),
                  child: Center(
                    child: Icon(
                      _event.type.icon,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _event.type.color.withValues(alpha: 0.8),
                      _event.type.color,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _event.type.icon,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
        
        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        
        // Event Title and Type
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _event.type.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _event.type.icon,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _event.type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _event.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventInfoCard() {
    final dateFormat = '${_event.date.day}/${_event.date.month}/${_event.date.year}';
    final timeFormat = '${_event.date.hour.toString().padLeft(2, '0')}:${_event.date.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date and Time
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.grey),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date & Time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$dateFormat at $timeFormat',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          if (_event.venue != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Venue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _event.venue!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          if (_event.description != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _event.description!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Payment Status
          Row(
            children: [
              const Icon(Icons.payment, color: Colors.grey),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _event.paymentStatus.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _event.paymentStatus.icon,
                          size: 16,
                          color: _event.paymentStatus.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _event.paymentStatus.displayName,
                          style: TextStyle(
                            color: _event.paymentStatus.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Parking Capacity (if available)
          if (_event.parkingCapacity != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.local_parking, color: Colors.grey),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parking Capacity',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_event.parkingCapacity} vehicles',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    if (_timeUntilEvent.isNegative) {
      return const SizedBox.shrink();
    }

    final days = _timeUntilEvent.inDays;
    final hours = _timeUntilEvent.inHours % 24;
    final minutes = _timeUntilEvent.inMinutes % 60;
    final seconds = _timeUntilEvent.inSeconds % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFDBB42).withValues(alpha: 0.1),
            const Color(0xFFFDBB42).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFDBB42).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer,
                color: Color(0xFFFDBB42),
              ),
              const SizedBox(width: 8),
              const Text(
                'Time Until Event',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDBB42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountdownItem('Days', days.toString()),
              _buildCountdownItem('Hours', hours.toString().padLeft(2, '0')),
              _buildCountdownItem('Minutes', minutes.toString().padLeft(2, '0')),
              _buildCountdownItem('Seconds', seconds.toString().padLeft(2, '0')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownItem(String label, String value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFDBB42),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementModules() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // First Row
          Row(
            children: [
              Expanded(
                child: _buildModuleCard(
                  title: 'Checklist',
                  subtitle: _isLoading 
                      ? 'Loading...'
                      : '${_statistics?.completedTasks ?? 0}/${_statistics?.totalTasks ?? 0} completed',
                  icon: Icons.checklist,
                  color: Colors.green,
                  progress: _isLoading 
                      ? 0.0 
                      : _computeTaskProgressBar(),
                  onTap: _navigateToChecklist,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModuleCard(
                  title: 'Guest List',
                  subtitle: _isLoading 
                      ? 'Loading...'
                      : '${_statistics?.totalGuests ?? 0} guests',
                  icon: Icons.group,
                  color: Colors.blue,
                  onTap: _navigateToGuestList,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second Row
          Row(
            children: [
              Expanded(
                child: _buildModuleCard(
                  title: 'Budget',
                  subtitle: _event.budget != null 
                      ? '₹${(_event.spentAmount ?? 0).toStringAsFixed(0)} / ₹${_event.budget!.toStringAsFixed(0)}'
                      : 'Not set',
                  icon: Icons.currency_rupee,
                  color: Colors.orange,
                  progress: _computeBudgetProgressBar(),
                  onTap: _navigateToBudget,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModuleCard(
                  title: 'Notes',
                  subtitle: _isLoading 
                      ? 'Loading...'
                      : 'View and manage notes',
                  icon: Icons.note_alt,
                  color: Colors.purple,
                  onTap: _navigateToNotes,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Third Row
          Row(
            children: [
              Expanded(
                child: _buildModuleCard(
                  title: 'E-Invites',
                  subtitle: 'Send invitations',
                  icon: Icons.mail,
                  color: Colors.teal,
                  onTap: _navigateToEInvites,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // Empty space for symmetry
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? progress,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}