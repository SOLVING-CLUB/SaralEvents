import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cache/simple_cache.dart';

class AvailabilityService {
  final SupabaseClient _supabase;

  AvailabilityService(this._supabase);

  Future<Map<String, dynamic>> getServiceAvailability(String serviceId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final startNextMonth = DateTime(month.year, month.month + 1, 1);
      // Convert LOCAL month boundaries to UTC, so comparisons align with vendor writes
      final startUtc = startOfMonth.toUtc();
      final nextUtc = startNextMonth.toUtc();
      final cacheKey = 'availability:$serviceId:${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}';

      final data = await CacheManager.instance.getOrFetch<List<dynamic>>(
        cacheKey,
        const Duration(minutes: 2),
        () async {
          final response = await _supabase
              .from('service_availability')
              .select('*')
              .eq('service_id', serviceId)
              .gte('date', startUtc.toIso8601String())
              .lt('date', nextUtc.toIso8601String());
          return response;
        },
      );

      return {
        'success': true,
        'data': data,
      };
    } catch (e) {
      print('Error fetching availability: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableTimeSlots(String serviceId, DateTime date) async {
    try {
      // Use LOCAL midnight converted to UTC for the window [dayStart, nextDayStart)
      final localStart = DateTime(date.year, date.month, date.day);
      final dateUtc = localStart.toUtc();
      final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
      
      // Invalidate cache to ensure fresh data (especially after bookings are created)
      final cacheKey = 'timeslots:$serviceId:${_dateOnly(date)}';
      CacheManager.instance.invalidate(cacheKey);
      
      // Fetch availability data (bypass cache to get fresh data)
      final availabilityResponse = await _supabase
          .from('service_availability')
          .select('*')
          .eq('service_id', serviceId)
          .gte('date', dateUtc.toIso8601String())
          .lt('date', dateUtc.add(const Duration(days: 1)).toIso8601String());

      if (availabilityResponse.isEmpty) {
        print('⚠️ No availability data found for service $serviceId on date $dateStr');
        return [];
      }

      final availability = availabilityResponse.first;
      
      // Get existing bookings for this service and date to check occupied slots
      // Only include active bookings (exclude cancelled and completed)
      final bookingsResponse = await _supabase
          .from('bookings')
          .select('booking_time, status')
          .eq('service_id', serviceId)
          .eq('booking_date', dateStr);
      
      print('🔍 Checking bookings for service $serviceId on date $dateStr');
      print('   Found ${bookingsResponse.length} total bookings');
      
      // Filter in Dart to only include active bookings (not cancelled or completed)
      final activeBookings = bookingsResponse.where((booking) {
        final status = booking['status'] as String?;
        final isActive = status == 'pending' || status == 'confirmed';
        if (isActive) {
          print('   ✅ Active booking found: time=${booking['booking_time']}, status=$status');
        }
        return isActive;
      }).toList();
      
      print('   ${activeBookings.length} active bookings found');
      
      // Note: We only check confirmed bookings here. Slots in cart are NOT locked.
      // Slots are only locked after payment is confirmed and booking is created.

      // Extract booked time slots - match exact slot ranges
      final Set<String> bookedTimeSlots = {};
      
      // Process confirmed bookings only (slots are locked only after payment)
      for (final booking in activeBookings) {
        final bookingTime = booking['booking_time'] as String?;
        if (bookingTime != null) {
          final slot = _getSlotFromTime(bookingTime);
          if (slot != null) {
            bookedTimeSlots.add(slot);
            print('   📅 Booking locks slot: $bookingTime → $slot');
          }
        }
      }
      
      print('   📊 Booked slots: $bookedTimeSlots');
      
      // Get availability for different time periods (exclude booked slots)
      final morningAvailable = (availability['morning_available'] as bool? ?? false) && !bookedTimeSlots.contains('morning');
      final afternoonAvailable = (availability['afternoon_available'] as bool? ?? false) && !bookedTimeSlots.contains('afternoon');
      final eveningAvailable = (availability['evening_available'] as bool? ?? false) && !bookedTimeSlots.contains('evening');
      final nightAvailable = (availability['night_available'] as bool? ?? false) && !bookedTimeSlots.contains('night');
      
      print('   ✅ Final availability:');
      print('      Morning: $morningAvailable (vendor: ${availability['morning_available']}, booked: ${bookedTimeSlots.contains('morning')})');
      print('      Afternoon: $afternoonAvailable (vendor: ${availability['afternoon_available']}, booked: ${bookedTimeSlots.contains('afternoon')})');
      print('      Evening: $eveningAvailable (vendor: ${availability['evening_available']}, booked: ${bookedTimeSlots.contains('evening')})');
      print('      Night: $nightAvailable (vendor: ${availability['night_available']}, booked: ${bookedTimeSlots.contains('night')})');
      final customStart = availability['custom_start'] as String?;
      final customEnd = availability['custom_end'] as String?;

      List<Map<String, dynamic>> timeSlots = [];

      // Add time slots based on availability (excluding booked ones)
      if (morningAvailable) {
        timeSlots.add({
          'start_time': '09:00',
          'end_time': '12:00',
          'is_available': true,
        });
      }
      
      if (afternoonAvailable) {
        timeSlots.add({
          'start_time': '12:00',
          'end_time': '17:00',
          'is_available': true,
        });
      }
      
      if (eveningAvailable) {
        timeSlots.add({
          'start_time': '17:00',
          'end_time': '21:00',
          'is_available': true,
        });
      }
      
      if (nightAvailable) {
        timeSlots.add({
          'start_time': '21:00',
          'end_time': '23:00',
          'is_available': true,
        });
      }
      
      // Add custom time slots if available (check if custom slot is booked/reserved)
      if (customStart != null && customEnd != null) {
        // For custom slots, check if any booking or draft time falls within the custom range
        bool customSlotBooked = false;
        
        // Check bookings only (slots in cart are not locked)
        for (final booking in activeBookings) {
          final bookingTime = booking['booking_time'] as String?;
          if (bookingTime != null && _isTimeInCustomRange(bookingTime, customStart, customEnd)) {
            customSlotBooked = true;
            print('   🔒 Custom slot locked by booking: $bookingTime');
            break;
          }
        }
        
        if (!customSlotBooked) {
          timeSlots.add({
            'start_time': customStart,
            'end_time': customEnd,
            'is_available': true,
          });
        }
      }
      
      return timeSlots;
    } catch (e) {
      print('Error fetching time slots: $e');
      return [];
    }
  }

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Get slot period name from time string (HH:mm format)
  String? _getSlotFromTime(String timeStr) {
    try {
      final timeParts = timeStr.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final totalMinutes = hour * 60 + minute;
        
        // Map booking time to slot periods (matching exact slot ranges)
        // Morning: 09:00 - 12:00 (540 - 720 minutes)
        if (totalMinutes >= 540 && totalMinutes < 720) {
          return 'morning';
        }
        // Afternoon: 12:00 - 17:00 (720 - 1020 minutes)
        else if (totalMinutes >= 720 && totalMinutes < 1020) {
          return 'afternoon';
        }
        // Evening: 17:00 - 21:00 (1020 - 1260 minutes)
        else if (totalMinutes >= 1020 && totalMinutes < 1260) {
          return 'evening';
        }
        // Night: 21:00 - 23:00 (1260 - 1380 minutes)
        else if (totalMinutes >= 1260 && totalMinutes < 1380) {
          return 'night';
        }
      }
    } catch (e) {
      print('⚠️ Error parsing time: $timeStr - $e');
    }
    return null;
  }

  /// Check if a time falls within a custom time range
  bool _isTimeInCustomRange(String timeStr, String customStart, String customEnd) {
    try {
      final timeParts = timeStr.split(':');
      final customStartParts = customStart.split(':');
      final customEndParts = customEnd.split(':');
      
      if (timeParts.length >= 2 && 
          customStartParts.length >= 2 && 
          customEndParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final customStartHour = int.parse(customStartParts[0]);
        final customEndHour = int.parse(customEndParts[0]);
        
        // Check if booking time falls within custom slot range
        return hour >= customStartHour && hour < customEndHour;
      }
    } catch (e) {
      print('⚠️ Error checking custom range: $e');
    }
    return false;
  }
}
