import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_models.dart';
import '../core/cache/simple_cache.dart';

class BookingService {
  final SupabaseClient _supabase;

  BookingService(this._supabase);

  // Create a new booking
  Future<bool> createBooking({
    required String serviceId,
    required String vendorId,
    required DateTime bookingDate,
    required TimeOfDay? bookingTime,
    required double amount,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: No authenticated user found');
        return false;
      }

      // Validate inputs
      if (serviceId.isEmpty) {
        print('Error: Service ID is empty');
        return false;
      }
      if (vendorId.isEmpty) {
        print('Error: Vendor ID is empty');
        return false;
      }

      print('Creating booking with:');
      print('  user_id: $userId');
      print('  service_id: $serviceId');
      print('  vendor_id: $vendorId');
      print('  booking_date: ${bookingDate.toIso8601String().split('T')[0]}');
      print('  booking_time: ${bookingTime != null ? '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}' : 'null'}');
      print('  amount: $amount');
      print('  notes: $notes');

      // Verify that the vendor_id matches the service
      try {
        final serviceResult = await _supabase
            .from('services')
            .select('vendor_id')
            .eq('id', serviceId)
            .single();
        
        final serviceVendorId = serviceResult['vendor_id'];
        if (serviceVendorId != vendorId) {
          print('Error: Vendor ID mismatch. Service vendor: $serviceVendorId, provided vendor: $vendorId');
          return false;
        }
      } catch (e) {
        print('Error verifying service vendor: $e');
        return false;
      }

      final bookingData = {
        'user_id': userId,
        'service_id': serviceId,
        'vendor_id': vendorId,
        'booking_date': bookingDate.toIso8601String().split('T')[0],
        'booking_time': bookingTime != null 
            ? '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}'
            : null,
        'amount': amount,
        'notes': notes,
        'status': 'pending',
        'milestone_status': 'created', // Initial milestone status
      };

      print('Booking data: $bookingData');

      final result = await _supabase.from('bookings').insert(bookingData).select();
      print('Booking created successfully: $result');

      // Invalidate caches impacted by booking
      CacheManager.instance.invalidateByPrefix('availability:$serviceId');
      CacheManager.instance.invalidate('user:bookings');

      return true;
    } catch (e) {
      print('Error creating booking: $e');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  // Get user's booking history
  Future<List<Map<String, dynamic>>> getUserBookings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      return await CacheManager.instance.getOrFetch<List<Map<String, dynamic>>>(
        'user:bookings',
        const Duration(minutes: 1),
        () async {
          final result = await _supabase
              .rpc('get_user_bookings', params: {'user_uuid': userId});
          return List<Map<String, dynamic>>.from(result);
        },
      );
    } catch (e) {
      print('Error fetching user bookings: $e');
      return [];
    }
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('user_id', userId);

      // Invalidate related caches
      CacheManager.instance.invalidate('user:bookings');

      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  // Check if a service is available for booking
  Future<bool> isServiceAvailable(String serviceId) async {
    try {
      final result = await _supabase
          .from('services')
          .select('is_active, is_visible_to_users')
          .eq('id', serviceId)
          .single();

      return result['is_active'] == true && result['is_visible_to_users'] == true;
    } catch (e) {
      print('Error checking service availability: $e');
      return false;
    }
  }

  // Get booking statistics for user
  Future<Map<String, int>> getUserBookingStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final result = await CacheManager.instance.getOrFetch<List<dynamic>>(
        'user:booking-stats',
        const Duration(minutes: 1),
        () async {
          return await _supabase
              .from('bookings')
              .select('status')
              .eq('user_id', userId);
        },
      );

      final stats = <String, int>{};
      for (final booking in result) {
        final status = booking['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error fetching user booking stats: $e');
      return {};
    }
  }
}
