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
        bookings.add({
          'id': booking['id'],
          'status': booking['status'],
          'amount': booking['amount'],
          'booking_date': booking['booking_date'],
          'booking_time': booking['booking_time'],
          'notes': booking['notes'],
          'created_at': booking['created_at'],
          'service_name': service['name'],
          'service_price': service['price'],
          'service_description': service['description'],
          'customer_name': 'Customer (ID: ${booking['user_id']})',
          'customer_email': 'No email available',
          'customer_phone': 'No phone available',
          'user_id': userId,
        });
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

      // Update booking status
      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
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
