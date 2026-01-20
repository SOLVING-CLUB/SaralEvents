import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/availability_service.dart';

enum DayStatus {
  available,
  partiallyAvailable,
  booked,
  unavailable,
}

class DaySlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;

  const DaySlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });
}

class UserAvailabilityCalendar extends StatefulWidget {
  final String serviceId;
  final String vendorId;
  final Function(DateTime date, TimeOfDay? time) onDateSelected;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;

  const UserAvailabilityCalendar({
    super.key,
    required this.serviceId,
    required this.vendorId,
    required this.onDateSelected,
    this.selectedDate,
    this.selectedTime,
  });

  @override
  State<UserAvailabilityCalendar> createState() => _UserAvailabilityCalendarState();
}

class _UserAvailabilityCalendarState extends State<UserAvailabilityCalendar> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final AvailabilityService _availabilityService;
  DateTime _currentMonth = DateTime.now();
  Map<DateTime, DayStatus> _availabilityMap = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _availabilityService = AvailabilityService(_supabase);
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch availability data for the current month
      print('=== AVAILABILITY CALENDAR DEBUG ===');
      print('Service ID: ${widget.serviceId}');
      print('Vendor ID: ${widget.vendorId}');
      print('Current Month: ${_currentMonth.month}/${_currentMonth.year}');
      print('Date Range: ${_getMonthStart(_currentMonth).toIso8601String()} to ${_getMonthEnd(_currentMonth).toIso8601String()}');
      
      // Also check if there's ANY availability data for this service (regardless of month)
      final anyAvailability = await _supabase
          .from('service_availability')
          .select('*')
          .eq('service_id', widget.serviceId)
          .limit(1);
      print('Any availability data for this service: ${anyAvailability.isNotEmpty ? "YES" : "NO"}');
      if (anyAvailability.isNotEmpty) {
        print('Sample availability record: ${anyAvailability.first}');
      }
      
      // TEMPORARY DEBUG: Show ALL availability data for September 2025
      final allSeptemberData = await _supabase
          .from('service_availability')
          .select('*')
          .gte('date', '2025-09-01')
          .lt('date', '2025-10-01');
      print('All September 2025 availability data: $allSeptemberData');
      
      // Convert to UTC timestamps for proper comparison with timestamptz
      final startOfMonth = _getMonthStart(_currentMonth);
      final startNextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      // Convert LOCAL boundaries to UTC to avoid off-by-one due to timezone
      final startUtc = startOfMonth.toUtc();
      final nextUtc = startNextMonth.toUtc();
      
      final response = await _supabase
          .from('service_availability')
          .select('*')
          .eq('service_id', widget.serviceId)
          .gte('date', startUtc.toIso8601String())
          .lt('date', nextUtc.toIso8601String());
          
      print('Database Response: $response');
      print('Number of records found: ${response.length}');
      
      // Debug: Print each record's date format
      for (final record in response) {
        print('Record date: ${record['date']} (type: ${record['date'].runtimeType})');
        final parsed = DateTime.parse(record['date']);
        print('  Parsed as: $parsed');
        print('  Local date: ${DateTime(parsed.year, parsed.month, parsed.day)}');
      }

      final Map<DateTime, DayStatus> availabilityMap = {};

      for (final data in response) {
        try {
          final dateString = data['date'];
          if (dateString == null) continue;
          
          // Parse the timestamptz, convert to LOCAL, then take Y/M/D
          final utc = DateTime.parse(dateString);
          final local = utc.toLocal();
          final date = DateTime(local.year, local.month, local.day);
          
          // Get availability for different time periods
          final morningAvailable = data['morning_available'] as bool? ?? false;
          final afternoonAvailable = data['afternoon_available'] as bool? ?? false;
          final eveningAvailable = data['evening_available'] as bool? ?? false;
          final nightAvailable = data['night_available'] as bool? ?? false;
          final customStart = data['custom_start'] as String?;
          final customEnd = data['custom_end'] as String?;

          print('Processing date: ${date.day}/${date.month}/${date.year}');
          print('  Morning: $morningAvailable, Afternoon: $afternoonAvailable, Evening: $eveningAvailable, Night: $nightAvailable');

          DayStatus dayStatus;

          // Check actual available time slots (considering bookings and reservations)
          // This ensures dates with all slots booked are marked as unavailable
          final availableSlots = await _availabilityService.getAvailableTimeSlots(widget.serviceId, date);
          
          print('  Available slots after checking bookings: ${availableSlots.length}');
          
          // Determine overall day status based on actual available slots
          if (availableSlots.isEmpty) {
            // No slots available (all booked/reserved)
            dayStatus = DayStatus.booked;
            print('  → Status: BOOKED (all slots taken)');
          } else {
            // Check vendor availability to determine if fully or partially available
            final totalVendorAvailable = (morningAvailable ? 1 : 0) + 
                                        (afternoonAvailable ? 1 : 0) + 
                                        (eveningAvailable ? 1 : 0) + 
                                        (nightAvailable ? 1 : 0);
            
            if (totalVendorAvailable == 4 && availableSlots.length >= 4) {
              // All time periods available and not booked
              dayStatus = DayStatus.available;
              print('  → Status: AVAILABLE (all periods free)');
            } else if (customStart != null && customEnd != null) {
              // Custom time slots
              dayStatus = DayStatus.partiallyAvailable;
              print('  → Status: PARTIALLY AVAILABLE (custom slots)');
            } else {
              // Some time periods available (some may be booked)
              dayStatus = DayStatus.partiallyAvailable;
              print('  → Status: PARTIALLY AVAILABLE (${availableSlots.length} slots free)');
            }
          }

          availabilityMap[date] = dayStatus;
        } catch (e) {
          print('Error processing availability data: $e');
          continue;
        }
      }

      // If no availability data found, show all dates as unavailable
      if (availabilityMap.isEmpty) {
        print('❌ No availability data found for service: ${widget.serviceId}');
        print('   This means the vendor has not set availability for this service yet.');
        print('   Please ask the vendor to set availability in the vendor app.');
        
        // For testing: Create some sample availability data
        print('🔧 Creating sample availability data for testing...');
        final today = DateTime.now();
        for (int i = 0; i < 7; i++) {
          final testDate = DateTime(today.year, today.month, today.day + i);
          if (testDate.month == _currentMonth.month && testDate.year == _currentMonth.year) {
            availabilityMap[testDate] = DayStatus.available;
            print('  Added test availability for ${testDate.day}/${testDate.month}/${testDate.year}');
          }
        }
      } else {
        print('✅ Final availability map:');
        availabilityMap.forEach((date, status) {
          print('  ${date.day}/${date.month}/${date.year}: $status');
        });
      }
      
      print('============================');

      setState(() {
        _availabilityMap = availabilityMap;
        _isLoading = false;
      });
      
      print('🔄 Calendar state updated with ${_availabilityMap.length} availability records');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  DateTime _getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _getMonthEnd(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }


  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadAvailability();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadAvailability();
  }

  DayStatus _getDayStatus(DateTime date) {
    final status = _availabilityMap[date] ?? DayStatus.unavailable;
    if (status != DayStatus.unavailable) {
      print('  Found status for ${date.day}/${date.month}/${date.year}: $status');
    }
    return status;
  }

  Color _getDayColor(DayStatus status) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case DayStatus.available:
        color = Colors.green; // Mark available dates in green
        break;
      case DayStatus.partiallyAvailable:
        color = Colors.yellow; // Partially available in yellow
        break;
      case DayStatus.booked:
        color = theme.colorScheme.error;
        break;
      case DayStatus.unavailable:
        color = theme.colorScheme.onSurface.withOpacity(0.3);
        break;
    }
    print('Getting color for $status: $color');
    return color;
  }

  void _onDayTap(DateTime date) {
    final status = _getDayStatus(date);
    if (status == DayStatus.available || status == DayStatus.partiallyAvailable) {
      widget.onDateSelected(date, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building calendar with ${_availabilityMap.length} availability records');
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
              'Unable to load availability',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailability,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show message if no availability data is found
    if (_availabilityMap.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today, 
              size: 48, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Availability Set',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The vendor has not set availability for this service yet.\nPlease contact the vendor to set their availability.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAvailability,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    print('🎨 Building calendar UI with ${_availabilityMap.length} records');
    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildCalendarGrid(),
        ),

        const SizedBox(height: 16),

        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    print('🔧 Building calendar grid with ${_availabilityMap.length} availability records');
    final firstDayOfMonth = _getMonthStart(_currentMonth);
    final lastDayOfMonth = _getMonthEnd(_currentMonth);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Convert to 0-based Sunday start
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox(height: 40));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final status = _getDayStatus(date);
      final isSelected = widget.selectedDate != null &&
          widget.selectedDate!.year == date.year &&
          widget.selectedDate!.month == date.month &&
          widget.selectedDate!.day == date.day;
          
      // Debug: Print status for each day
      print('Calendar Grid - Day $day (${date.day}/${date.month}/${date.year}): $status');
      if (status != DayStatus.unavailable) {
        print('  → This day has availability data!');
      }

      dayWidgets.add(
        GestureDetector(
          onTap: () => _onDayTap(date),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (status == DayStatus.unavailable 
                      ? Colors.transparent 
                      : _getDayColor(status)),
              border: isSelected
                  ? null
                  : Border.all(
                      color: status == DayStatus.unavailable 
                          ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : (status == DayStatus.unavailable 
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.4)
                          : Theme.of(context).colorScheme.onPrimary),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Create rows of 7 days each
    final List<Widget> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      final rowDays = dayWidgets.sublist(i, (i + 7).clamp(0, dayWidgets.length));
      rows.add(
        Row(
          children: rowDays.map((day) => Expanded(child: day)).toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildLegend() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildLegendItem(Colors.green, 'Available', '8:00 AM - 11:00 PM'),
          const SizedBox(height: 8),
          _buildLegendItem(Colors.yellow, 'Partially Available', 'Custom time slots'),
          const SizedBox(height: 8),
          _buildLegendItem(theme.colorScheme.error, 'Booked', 'Not available'),
          const SizedBox(height: 8),
          _buildLegendItem(theme.colorScheme.onSurface.withOpacity(0.3), 'Unavailable', 'Not available'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String timeRange) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                timeRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
