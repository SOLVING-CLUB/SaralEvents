import 'package:supabase_flutter/supabase_flutter.dart';

class BookingService {
  final SupabaseClient _supabase;

  BookingService(this._supabase);

  // Get vendor ID for current user
  Future<String?> _getVendorId() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        return null;
      }

      final result = await _supabase
          .from('vendor_profiles')
          .select('id, business_name')
          .eq('user_id', userId)
          .maybeSingle();

      if (result != null) {
        print('Vendor found: ${result['business_name']} (ID: ${result['id']})');
        return result['id'];
      } else {
        print('No vendor profile found for user: $userId');
        return null;
      }
    } catch (e) {
      print('Error getting vendor ID: $e');
      return null;
    }
  }

  // Fetch all bookings for the current vendor with complete information
  Future<List<Map<String, dynamic>>> getVendorBookings() async {
    try {
      final vendorId = await _getVendorId();
      print('Fetching bookings for vendor ID: $vendorId');
      
      if (vendorId == null) {
        print('No vendor ID found for current user');
        return [];
      }

      // Get bookings with service information only first
      final result = await _supabase
          .from('bookings')
          .select('''
            *,
            services!inner(
              id,
              name,
              price,
              description
            )
          ''')
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      print('Found ${result.length} bookings for vendor $vendorId');

      // Build a map of user_id -> basic placeholders first
      final List<Map<String, dynamic>> bookings = [];
      final Set<String> userIds = {};
      for (final booking in result) {
        final service = booking['services'] as Map<String, dynamic>;
        final String userId = booking['user_id'];
        userIds.add(userId);
        
        // Debug logging for each booking
        print('📦 BookingService: Processing booking ${booking['id']}');
        print('   Raw status: ${booking['status']} (type: ${booking['status'].runtimeType})');
        print('   Raw milestone_status: ${booking['milestone_status']} (type: ${booking['milestone_status']?.runtimeType})');
        print('   Location link: ${booking['location_link']}');
        
        bookings.add({
          'id': booking['id'],
          'status': booking['status'],
          'milestone_status': booking['milestone_status'],
          'vendor_accepted_at': booking['vendor_accepted_at'],
          'vendor_traveling_at': booking['vendor_traveling_at'],
          'vendor_arrived_at': booking['vendor_arrived_at'],
          'arrival_confirmed_at': booking['arrival_confirmed_at'],
          'setup_completed_at': booking['setup_completed_at'],
          'setup_confirmed_at': booking['setup_confirmed_at'],
          'amount': booking['amount'],
          'booking_date': booking['booking_date'],
          'booking_time': booking['booking_time'],
          'notes': booking['notes'],
          'location_link': booking['location_link'], // Include location link
          'created_at': booking['created_at'],
          'service_name': service['name'],
          'service_price': service['price'],
          'service_description': service['description'],
          'customer_name': 'Customer (ID: ${booking['user_id']})',
          'customer_email': 'No email available',
          'customer_phone': 'No phone available',
          'user_id': userId,
        });
        
        print('   Added to bookings list with status: ${bookings.last['status']}');
        print('   Added to bookings list with milestone_status: ${bookings.last['milestone_status']}');
      }

      // Try to enrich with customer details from user_profiles in one batched call
      try {
        if (userIds.isNotEmpty) {
          final profiles = await _supabase
              .from('user_profiles')
              .select('user_id, first_name, last_name, email, phone_number')
              .inFilter('user_id', userIds.toList());

          final Map<String, Map<String, dynamic>> profileByUserId = {
            for (final p in profiles) (p['user_id'] as String): p
          };

          for (final booking in bookings) {
            final String uid = booking['user_id'] as String;
            final profile = profileByUserId[uid];
            if (profile != null) {
              final String firstName = (profile['first_name'] ?? '').toString();
              final String lastName = (profile['last_name'] ?? '').toString();
              final String fullName = (firstName + ' ' + lastName).trim();
              booking['customer_name'] = fullName.isEmpty ? 'Customer' : fullName;
              booking['customer_email'] = (profile['email'] ?? '');
              booking['customer_phone'] = (profile['phone_number'] ?? '');
            }
          }
        }
      } catch (e) {
        // If RLS blocks access or any error occurs, keep placeholders
        print('Could not enrich bookings with user_profiles due to: $e');
      }

      return bookings;
    } catch (e) {
      print('Error fetching vendor bookings: $e');
      print('Error details: ${e.toString()}');
      return [];
    }
  }

  // Update booking status with proper error handling
  Future<bool> updateBookingStatus(String bookingId, String status, String? notes) async {
    try {
      print('Updating booking $bookingId to status: $status');
      
      final vendorId = await _getVendorId();
      if (vendorId == null) {
        print('No vendor ID found for current user');
        return false;
      }

      // First verify the booking belongs to this vendor
      final bookingCheck = await _supabase
          .from('bookings')
          .select('vendor_id, status')
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .maybeSingle();
      
      if (bookingCheck == null) {
        print('Booking not found or does not belong to current vendor');
        return false;
      }

      print('Current booking status: ${bookingCheck['status']}');

      // Update the booking status
      final updateResult = await _supabase
          .from('bookings')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .select();
      
      if (updateResult.isEmpty) {
        print('Failed to update booking - no rows affected');
        return false;
      }

      print('Booking updated successfully: ${updateResult.first}');

      // Create status update record
      try {
        await _supabase
            .from('booking_status_updates')
            .insert({
              'booking_id': bookingId,
              'status': status,
              'updated_by': _supabase.auth.currentUser?.id,
              'notes': notes ?? 'Status updated to $status by vendor',
            });
        print('Status update record created');
      } catch (e) {
        print('Warning: Failed to create status update record: $e');
        // Don't fail the entire operation if status update record fails
      }

      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  // Mark booking as accepted by vendor and update milestone status
  Future<bool> acceptBooking(String bookingId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) {
        print('No vendor ID found for current user');
        return false;
      }

      final booking = await _supabase
          .from('bookings')
          .select('id, vendor_id, user_id')
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .maybeSingle();

      if (booking == null) {
        print('Booking not found or does not belong to vendor');
        return false;
      }

      await _supabase
          .from('bookings')
          .update({
            'status': 'confirmed', // Update status to confirmed when vendor accepts
            'milestone_status': 'accepted',
            'vendor_accepted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Create simple order notification for customer
      try {
        await _supabase.from('order_notifications').insert({
          'booking_id': bookingId,
          'user_id': booking['user_id'],
          'notification_type': 'vendor_accepted',
          'title': 'Order Confirmed',
          'message': 'Your vendor has accepted the booking.',
        });
      } catch (e) {
        print('Warning: failed to create order notification for acceptBooking: $e');
      }

      return true;
    } catch (e) {
      print('Error accepting booking: $e');
      return false;
    }
  }

  // Mark that vendor has arrived at the event location
  Future<bool> markArrived(String bookingId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return false;

      final booking = await _supabase
          .from('bookings')
          .select('id, vendor_id, user_id')
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .maybeSingle();

      if (booking == null) return false;

      await _supabase
          .from('bookings')
          .update({
            'milestone_status': 'vendor_arrived',
            'vendor_arrived_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Notify customer that vendor has arrived
      try {
        await _supabase.from('order_notifications').insert({
          'booking_id': bookingId,
          'user_id': booking['user_id'],
          'notification_type': 'vendor_arrived',
          'title': 'Vendor Arrived',
          'message': 'Your vendor has marked arrival at the event location. Please confirm arrival in the app.',
        });
      } catch (e) {
        print('Warning: failed to create order notification for markArrived: $e');
      }

      return true;
    } catch (e) {
      print('Error marking vendor arrived: $e');
      return false;
    }
  }

  // Mark that vendor has completed the setup
  Future<bool> markSetupCompleted(String bookingId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return false;

      final booking = await _supabase
          .from('bookings')
          .select('id, vendor_id, user_id')
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .maybeSingle();

      if (booking == null) return false;

      await _supabase
          .from('bookings')
          .update({
            'milestone_status': 'setup_completed',
            'setup_completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Notify customer that setup is completed
      try {
        await _supabase.from('order_notifications').insert({
          'booking_id': bookingId,
          'user_id': booking['user_id'],
          'notification_type': 'setup_completed',
          'title': 'Setup Completed',
          'message': 'Your vendor has marked setup as completed. Please review and confirm in the app.',
        });
      } catch (e) {
        print('Warning: failed to create order notification for markSetupCompleted: $e');
      }

      return true;
    } catch (e) {
      print('Error marking setup completed: $e');
      return false;
    }
  }

  // Cancel booking as vendor (triggers 100% refund to customer)
  Future<Map<String, dynamic>> cancelBookingAsVendor({
    required String bookingId,
    String? reason,
  }) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) {
        return {
          'success': false,
          'error': 'Vendor not found',
        };
      }

      // Verify booking belongs to vendor
      final bookingCheck = await _supabase
          .from('bookings')
          .select('vendor_id, status')
          .eq('id', bookingId)
          .eq('vendor_id', vendorId)
          .maybeSingle();

      if (bookingCheck == null) {
        return {
          'success': false,
          'error': 'Booking not found or does not belong to vendor',
        };
      }

      if (bookingCheck['status'] == 'cancelled') {
        return {
          'success': false,
          'error': 'Booking is already cancelled',
        };
      }

      // Call refund service RPC function to process vendor cancellation
      // This will trigger 100% refund and vendor penalties
      final refundResult = await _supabase.rpc('process_vendor_cancellation', params: {
        'p_booking_id': bookingId,
        'p_reason': reason ?? 'Vendor cancellation',
      });

      if (refundResult == null || refundResult['success'] != true) {
        return {
          'success': false,
          'error': refundResult?['error'] ?? 'Failed to process cancellation',
        };
      }

      // Update booking status and milestone status
      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
            'milestone_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      // Create status update record
      try {
        await _supabase
            .from('booking_status_updates')
            .insert({
              'booking_id': bookingId,
              'status': 'cancelled',
              'updated_by': _supabase.auth.currentUser?.id,
              'notes': reason ?? 'Cancelled by vendor - Full refund issued to customer',
            });
      } catch (e) {
        print('Warning: Failed to create status update record: $e');
      }

      return {
        'success': true,
        'message': 'Booking cancelled. Full refund issued to customer.',
        'refund_amount': refundResult['refund_amount'],
      };
    } catch (e) {
      print('Error cancelling booking as vendor: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get booking statistics
  Future<Map<String, int>> getBookingStats() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return {};

      final result = await _supabase
          .from('bookings')
          .select('status')
          .eq('vendor_id', vendorId);

      final stats = <String, int>{};
      for (final booking in result) {
        final status = booking['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      print('Booking stats: $stats');
      return stats;
    } catch (e) {
      print('Error fetching booking stats: $e');
      return {};
    }
  }
}
