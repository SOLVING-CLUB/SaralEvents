import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../core/cache/simple_cache.dart';
import 'refund_service.dart';
import 'availability_service.dart';

class BookingService {
  final SupabaseClient _supabase;
  final RefundService _refundService;
  final AvailabilityService _availabilityService;

  BookingService(this._supabase) 
    : _refundService = RefundService(_supabase),
      _availabilityService = AvailabilityService(_supabase);

  // Create a new booking
  Future<bool> createBooking({
    required String serviceId,
    required String vendorId,
    required DateTime bookingDate,
    required TimeOfDay? bookingTime,
    required double amount,
    String? notes,
    String? locationLink,
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
      
      // Verify user_id is not null
      if (userId.isEmpty) {
        print('ERROR: user_id is empty!');
        return false;
      }

      // Optional safety check: verify that the vendor_id matches the service's vendor.
      // If this check fails, we log a warning but still proceed with booking creation,
      // to avoid breaking the booking flow due to data inconsistencies.
      try {
        final serviceResult = await _supabase
            .from('services')
            .select('vendor_id')
            .eq('id', serviceId)
            .maybeSingle();

        if (serviceResult != null) {
          final serviceVendorId = serviceResult['vendor_id'];
          if (serviceVendorId != vendorId) {
            print('Warning: Vendor ID mismatch. Service vendor: $serviceVendorId, provided vendor: $vendorId');
          }
        } else {
          print('Warning: Service not found while verifying vendor for booking. service_id=$serviceId');
        }
      } catch (e) {
        print('Warning: Error verifying service vendor for booking: $e');
        // Continue – do not block booking creation on this check.
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
        'location_link': locationLink,
        'status': 'pending', // Waiting for vendor acceptance
        'milestone_status': 'created', // Initial state - vendor must accept or reject
        'vendor_accepted_at': null, // Will be set when vendor accepts
      };

      print('📋 BookingService: Creating booking with data:');
      print('   status: ${bookingData['status']}');
      print('   milestone_status: ${bookingData['milestone_status']}');
      print('   vendor_accepted_at: ${bookingData['vendor_accepted_at']}');
      print('   service_id: $serviceId');
      print('   vendor_id: $vendorId');
      print('   amount: $amount');
      print('   location_link: ${locationLink ?? 'null'}');
      print('📋 Full booking data: $bookingData');
      
      // CRITICAL: Final availability check right before inserting to prevent race conditions
      if (bookingTime != null) {
        print('🔒 Performing final slot availability check...');
        final availableSlots = await _availabilityService.getAvailableTimeSlots(
          serviceId,
          bookingDate,
        );
        
        // Convert bookingTime to time string format (HH:mm)
        final timeStr = '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}';
        
        // Check if the selected time slot is still available
        bool slotAvailable = false;
        for (final slot in availableSlots) {
          final startTime = slot['start_time'] as String?;
          final endTime = slot['end_time'] as String?;
          if (startTime != null && endTime != null) {
            // Check if booking time falls within this slot range
            if (_isTimeInRange(timeStr, startTime, endTime)) {
              slotAvailable = true;
              print('   ✅ Slot is available: $timeStr falls within $startTime-$endTime');
              break;
            }
          }
        }
        
        if (!slotAvailable) {
          print('❌ ERROR: Slot is no longer available!');
          print('   Service: $serviceId');
          print('   Date: ${bookingDate.toIso8601String().split('T')[0]}');
          print('   Time: $timeStr');
          print('   Available slots: $availableSlots');
          return false;
        }
        
        print('✅ Slot availability confirmed - proceeding with booking creation');
      }
      
      print('📋 Attempting to insert booking into database...');

      List<Map<String, dynamic>> result;
      try {
        result = await _supabase.from('bookings').insert(bookingData).select();
        print('Booking insert result: $result');
        
        // Verify booking was actually created
        if (result.isEmpty) {
          print('ERROR: Booking insert returned empty result');
          print('This could indicate:');
          print('  1. RLS policy blocking insert');
          print('  2. Constraint violation (check status/milestone_status values)');
          print('  3. Database error');
          return false;
        }
        
        print('✅ Booking insert successful, got ${result.length} row(s) back');
      } catch (insertError) {
        print('❌ ERROR inserting booking: $insertError');
        print('Error type: ${insertError.runtimeType}');
        print('Error details: ${insertError.toString()}');
        
        // Extract detailed error information
        final errorStr = insertError.toString();
        print('📋 Booking data that failed:');
        print('   user_id: ${bookingData['user_id']}');
        print('   service_id: ${bookingData['service_id']}');
        print('   vendor_id: ${bookingData['vendor_id']}');
        print('   status: ${bookingData['status']} (type: ${bookingData['status'].runtimeType})');
        print('   milestone_status: ${bookingData['milestone_status']} (type: ${bookingData['milestone_status'].runtimeType})');
        print('   booking_date: ${bookingData['booking_date']}');
        print('   booking_time: ${bookingData['booking_time']}');
        print('   amount: ${bookingData['amount']}');
        print('   location_link: ${bookingData['location_link'] ?? 'null'}');
        
        // Check for specific error types
        if (errorStr.contains('violates check constraint')) {
          print('⚠️ Constraint violation detected!');
          if (errorStr.contains('milestone_status')) {
            print('   → milestone_status constraint violation');
            print('   → Attempted value: ${bookingData['milestone_status']}');
            print('   → Allowed values should be: created, accepted, vendor_traveling, vendor_arrived, arrival_confirmed, setup_completed, setup_confirmed, completed, cancelled, or NULL');
          } else if (errorStr.contains('status')) {
            print('   → status constraint violation');
            print('   → Attempted value: ${bookingData['status']}');
            print('   → Allowed values should be: pending, confirmed, completed, cancelled');
          } else {
            print('   → Unknown constraint violation - check database constraints');
          }
        }
        if (errorStr.contains('permission denied') || errorStr.contains('RLS') || errorStr.contains('row-level security')) {
          print('⚠️ RLS policy issue detected!');
          print('   → Check if user has INSERT permission on bookings table');
          print('   → User ID: $userId');
        }
        if (errorStr.contains('foreign key')) {
          print('⚠️ Foreign key constraint violation!');
          print('   → Check if service_id, vendor_id, or user_id are valid');
        }
        if (errorStr.contains('not null')) {
          print('⚠️ NOT NULL constraint violation!');
          print('   → Check if all required fields are provided');
        }
        
        return false;
      }
      
      final createdBooking = result.first;
      final createdBookingId = createdBooking['id'] as String;
      final createdUserId = createdBooking['user_id'] as String;
      final createdStatus = createdBooking['status'] as String?;
      final createdMilestoneStatus = createdBooking['milestone_status'] as String?;
      final createdLocationLink = createdBooking['location_link'] as String?;
      
      print('✅ Created booking ID: $createdBookingId');
      print('✅ Created booking user_id: $createdUserId');
      print('✅ Current auth user_id: $userId');
      print('✅ Created booking status: $createdStatus');
      print('✅ Created booking milestone_status: $createdMilestoneStatus');
      print('✅ Created booking location_link: ${createdLocationLink ?? 'null'}');
      
      // Verify the booking was created with correct status
      if (createdStatus != 'pending') {
        print('⚠️ WARNING: Booking created with status="$createdStatus" instead of "pending"!');
      }
      if (createdMilestoneStatus != 'created') {
        print('⚠️ WARNING: Booking created with milestone_status="$createdMilestoneStatus" instead of "created"!');
      }
      
      // Verify user_id matches
      if (createdUserId != userId) {
        print('ERROR: Booking user_id mismatch! Created: $createdUserId, Expected: $userId');
        return false;
      }
      
      // Verify we can read it back immediately
      try {
        final verifyResult = await _supabase
            .from('bookings')
            .select('id')
            .eq('id', createdBookingId)
            .eq('user_id', userId)
            .maybeSingle();
        
        if (verifyResult == null) {
          print('WARNING: Cannot read back the booking we just created! RLS issue?');
        } else {
          print('SUCCESS: Can read back the booking - RLS is working');
        }
      } catch (e) {
        print('ERROR verifying booking: $e');
      }

      // Force cache invalidation - clear all booking-related caches
      // This ensures availability slots are updated immediately after booking
      final bookingDateStr = bookingDate.toIso8601String().split('T')[0];
      final cacheKey = 'timeslots:$serviceId:$bookingDateStr';
      CacheManager.instance.invalidate(cacheKey);
      CacheManager.instance.invalidateByPrefix('availability:$serviceId');
      CacheManager.instance.invalidateByPrefix('timeslots:$serviceId');
      CacheManager.instance.invalidate('user:bookings');
      CacheManager.instance.invalidate('user:booking-stats');
      CacheManager.instance.invalidateByPrefix('user:bookings');
      
      print('🗑️ Invalidated cache for: $cacheKey');
      print('🗑️ Invalidated all availability caches for service: $serviceId');

      return true;
    } catch (e) {
      print('Error creating booking: $e');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  // Helper: Create bookings from completed drafts that don't have bookings
  Future<void> _createBookingsFromCompletedDrafts(String userId) async {
    try {
      // Get completed drafts (include event_date as fallback for booking_date)
      final completedDrafts = await _supabase
          .from('booking_drafts')
          .select('id, service_id, vendor_id, booking_date, event_date, booking_time, amount, notes, location_link')
          .eq('user_id', userId)
          .eq('status', 'completed');
      
      if (completedDrafts.isEmpty) {
        return;
      }
      
      print('Found ${completedDrafts.length} completed drafts, checking for missing bookings...');
      
      for (final draft in completedDrafts) {
        // Skip drafts with missing required fields
        // Use event_date as fallback for booking_date
        final serviceId = draft['service_id']?.toString();
        final vendorId = draft['vendor_id']?.toString();
        final bookingDateStr = draft['booking_date']?.toString() ?? draft['event_date']?.toString();
        final amount = draft['amount'];
        
        if (serviceId == null || vendorId == null || bookingDateStr == null || amount == null) {
          print('Skipping draft ${draft['id']} - missing required fields (serviceId: $serviceId, vendorId: $vendorId, bookingDate: $bookingDateStr, amount: $amount)');
          continue;
        }
        
        // Check if booking already exists
        final existingBooking = await _supabase
            .from('bookings')
            .select('id')
            .eq('user_id', userId)
            .eq('service_id', serviceId)
            .eq('booking_date', bookingDateStr)
            .maybeSingle();
        
        if (existingBooking == null) {
          // Create booking from draft
          print('Creating booking from completed draft: ${draft['id']}');
          try {
            final success = await createBooking(
              serviceId: serviceId,
              vendorId: vendorId,
              bookingDate: DateTime.parse(bookingDateStr),
              bookingTime: draft['booking_time'] != null
                  ? TimeOfDay(
                      hour: int.parse((draft['booking_time'] as String).split(':')[0]),
                      minute: int.parse((draft['booking_time'] as String).split(':')[1]),
                    )
                  : null,
              amount: (amount as num).toDouble(),
              notes: draft['notes']?.toString(),
              locationLink: draft['location_link']?.toString(),
            );
            
            if (success) {
              print('✅ Created booking from completed draft: ${draft['id']}');
            } else {
              print('❌ Failed to create booking from draft: ${draft['id']}');
            }
          } catch (e) {
            print('Error creating booking from draft ${draft['id']}: $e');
          }
        }
      }
    } catch (e) {
      print('Error checking completed drafts: $e');
    }
  }

  // Get user's booking history
  // This combines bookings from both 'bookings' table and 'orders' table (for paid orders)
  // Also checks for completed drafts without bookings and creates bookings for them
  Future<List<Map<String, dynamic>>> getUserBookings({bool forceRefresh = false}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('ERROR: No authenticated user found for getUserBookings');
        return [];
      }
      
      print('=== GET USER BOOKINGS DEBUG ===');
      print('Authenticated user ID: $userId');

      // Fast path: return from in-memory cache when not forcing refresh
      if (!forceRefresh) {
        final cached = CacheManager.instance.get<List<Map<String, dynamic>>>('user:bookings');
        if (cached != null) {
          print('Returning ${cached.length} bookings from CacheManager (user:bookings)');
          return cached;
        }
      }
      
      // Force cache invalidation if requested
      if (forceRefresh) {
        CacheManager.instance.invalidate('user:bookings');
        CacheManager.instance.invalidateByPrefix('user:bookings');
      }
      
      // First, check for completed drafts without bookings and create bookings for them
      await _createBookingsFromCompletedDrafts(userId);
      
      final allBookings = <Map<String, dynamic>>[];
      
      // 1. Get bookings from 'bookings' table
      try {
        print('Querying bookings table...');
        final bookingsResult = await _supabase
            .from('bookings')
            .select('id, service_id, vendor_id, booking_date, booking_time, status, milestone_status, amount, notes, created_at, user_id, vendor_accepted_at, vendor_arrived_at, arrival_confirmed_at, setup_completed_at, setup_confirmed_at, completed_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        print('Found ${bookingsResult.length} bookings from bookings table');
        
        for (final booking in bookingsResult) {
          String serviceName = 'Unknown Service';
          String vendorName = 'Unknown Vendor';
          
          // Get service name
          try {
            if (booking['service_id'] != null) {
              final serviceResult = await _supabase
                  .from('services')
                  .select('name')
                  .eq('id', booking['service_id'])
                  .maybeSingle();
              if (serviceResult != null && serviceResult['name'] != null) {
                serviceName = serviceResult['name'] as String;
              }
            }
          } catch (e) {
            print('Error fetching service name: $e');
          }
          
          // Get vendor name
          try {
            if (booking['vendor_id'] != null) {
              final vendorResult = await _supabase
                  .from('vendor_profiles')
                  .select('business_name')
                  .eq('id', booking['vendor_id'])
                  .maybeSingle();
              if (vendorResult != null && vendorResult['business_name'] != null) {
                vendorName = vendorResult['business_name'] as String;
              }
            }
          } catch (e) {
            print('Error fetching vendor name: $e');
          }
          
          // Fetch payment milestones for this booking to determine payment status
          bool arrivalMilestonePaid = false;
          bool completionMilestonePaid = false;
          try {
            final milestonesResult = await _supabase
                .from('payment_milestones')
                .select('milestone_type, status')
                .eq('booking_id', booking['id']);
            
            for (final milestone in milestonesResult) {
              final milestoneType = milestone['milestone_type'] as String?;
              final status = milestone['status'] as String?;
              
              if (milestoneType == 'arrival' && 
                  (status == 'held_in_escrow' || status == 'paid' || status == 'released')) {
                arrivalMilestonePaid = true;
              } else if (milestoneType == 'completion' && 
                         (status == 'held_in_escrow' || status == 'paid' || status == 'released')) {
                completionMilestonePaid = true;
              }
            }
          } catch (e) {
            print('Error fetching payment milestones: $e');
          }
          
          allBookings.add({
            'booking_id': booking['id'],
            'service_name': serviceName,
            'vendor_name': vendorName,
            'booking_date': booking['booking_date'],
            'booking_time': booking['booking_time'],
            'status': booking['status'],
            'milestone_status': booking['milestone_status'],
            'amount': booking['amount'],
            'notes': booking['notes'],
            'created_at': booking['created_at'],
            'vendor_accepted_at': booking['vendor_accepted_at'],
            'vendor_arrived_at': booking['vendor_arrived_at'],
            'arrival_confirmed_at': booking['arrival_confirmed_at'],
            'setup_completed_at': booking['setup_completed_at'],
            'setup_confirmed_at': booking['setup_confirmed_at'],
            'completed_at': booking['completed_at'],
            'arrival_milestone_paid': arrivalMilestonePaid,
            'completion_milestone_paid': completionMilestonePaid,
          });
        }
      } catch (e) {
        print('Error querying bookings table: $e');
      }
      
      // 2. Get paid orders from 'orders' table that don't have corresponding bookings
      // These are orders that were paid but booking creation might have failed
      try {
        print('Querying orders table for paid orders...');
        final ordersResult = await _supabase
            .from('orders')
            .select('id, status, total_amount, created_at, items_json, billing_name, event_date')
            .eq('user_id', userId)
            .inFilter('status', ['completed', 'confirmed', 'pending'])
            .order('created_at', ascending: false);
        
        print('Found ${ordersResult.length} orders from orders table');
        
        // Parse items_json to get service info
        for (final order in ordersResult) {
          try {
            final itemsJson = order['items_json'];
            if (itemsJson != null && itemsJson is String) {
              final items = (jsonDecode(itemsJson) as List).cast<Map<String, dynamic>>();
              if (items.isNotEmpty) {
                final firstItem = items.first;
                final serviceName = firstItem['title'] as String? ?? 'Service';
                
                // Extract booking date from event_date or created_at
                String? bookingDate;
                if (order['event_date'] != null) {
                  bookingDate = order['event_date'] as String;
                } else if (order['created_at'] != null) {
                  final createdAt = DateTime.parse(order['created_at'] as String);
                  bookingDate = createdAt.toIso8601String().split('T')[0];
                }
                
                // Check if this order already has a booking (by checking if booking exists with same date/amount)
                bool hasBooking = false;
                if (bookingDate != null) {
                  try {
                    allBookings.firstWhere(
                      (b) => b['booking_date'] == bookingDate && 
                              (b['amount'] as num).toDouble() == (order['total_amount'] as num).toDouble(),
                    );
                    hasBooking = true; // Found a match
                  } catch (e) {
                    hasBooking = false; // No match found
                  }
                }
                
                // Only add if no booking exists for this order
                if (!hasBooking) {
                  allBookings.add({
                    'booking_id': order['id'], // Use order ID as booking_id
                    'service_name': serviceName,
                    'vendor_name': 'Vendor', // Orders don't have vendor_id, use placeholder
                    'booking_date': bookingDate,
                    'booking_time': null,
                    'status': order['status'] ?? 'pending',
                    'amount': order['total_amount'],
                    'notes': null,
                    'created_at': order['created_at'],
                    'is_from_order': true, // Flag to indicate this came from orders table
                  });
                }
              }
            }
          } catch (e) {
            print('Error parsing order items: $e');
          }
        }
      } catch (e) {
        print('Error querying orders table: $e');
      }
      
      // Sort all bookings by created_at descending
      allBookings.sort((a, b) {
        final aDate = a['created_at'] as String? ?? '';
        final bDate = b['created_at'] as String? ?? '';
        return bDate.compareTo(aDate);
      });
      
      print('Total bookings to return: ${allBookings.length}');
      CacheManager.instance.set('user:bookings', allBookings, const Duration(minutes: 1));
      return allBookings;
    } catch (e, stackTrace) {
      print('Error fetching user bookings: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Cancel a booking with refund calculation
  Future<Map<String, dynamic>> cancelBookingWithRefund({
    required String bookingId,
    bool isVendorCancellation = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
        };
      }

      // Calculate refund
      final refundCalculation = await _refundService.calculateRefund(
        bookingId: bookingId,
        cancellationDate: DateTime.now(),
        isVendorCancellation: isVendorCancellation,
      );

      // Process refund
      final refundProcessed = await _refundService.processRefund(
        bookingId: bookingId,
        calculation: refundCalculation,
        cancelledBy: isVendorCancellation ? 'vendor' : 'customer',
      );

      if (!refundProcessed) {
        return {
          'success': false,
          'error': 'Failed to process refund',
        };
      }

      // Get booking details to invalidate availability cache
      final bookingDetails = await _supabase
          .from('bookings')
          .select('service_id, booking_date')
          .eq('id', bookingId)
          .maybeSingle();
      
      // Invalidate related caches
      CacheManager.instance.invalidate('user:bookings');
      CacheManager.instance.invalidate('user:booking-stats');
      CacheManager.instance.invalidateByPrefix('user:bookings');
      
      // Invalidate availability cache so the slot becomes available again
      if (bookingDetails != null) {
        final serviceId = bookingDetails['service_id'] as String?;
        final bookingDate = bookingDetails['booking_date'] as String?;
        if (serviceId != null && bookingDate != null) {
          final cacheKey = 'timeslots:$serviceId:$bookingDate';
          CacheManager.instance.invalidate(cacheKey);
          CacheManager.instance.invalidateByPrefix('availability:$serviceId');
          CacheManager.instance.invalidateByPrefix('timeslots:$serviceId');
          print('🗑️ Invalidated availability cache after cancellation: $cacheKey');
          print('   Slot should now be available again for service $serviceId on date $bookingDate');
        }
      }

      return {
        'success': true,
        'refund_amount': refundCalculation.refundableAmount,
        'non_refundable_amount': refundCalculation.nonRefundableAmount,
        'refund_percentage': refundCalculation.refundPercentage,
        'reason': refundCalculation.reason,
        'breakdown': refundCalculation.breakdown,
      };
    } catch (e) {
      print('Error cancelling booking: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Cancel a booking (legacy method - kept for backward compatibility)
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final result = await cancelBookingWithRefund(
        bookingId: bookingId,
        isVendorCancellation: false,
      );
      return result['success'] == true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  // Get refund preview before cancellation
  Future<RefundCalculation?> getRefundPreview({
    required String bookingId,
    bool isVendorCancellation = false,
  }) async {
    try {
      return await _refundService.calculateRefund(
        bookingId: bookingId,
        cancellationDate: DateTime.now(),
        isVendorCancellation: isVendorCancellation,
      );
    } catch (e) {
      print('Error getting refund preview: $e');
      return null;
    }
  }

  // Helper: Check if a time falls within a time range
  bool _isTimeInRange(String timeStr, String startTime, String endTime) {
    try {
      final timeParts = timeStr.split(':');
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      if (timeParts.length != 2 || startParts.length != 2 || endParts.length != 2) {
        return false;
      }
      
      final timeMinutes = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      
      // Handle time ranges that span midnight (e.g., 22:00 to 02:00)
      if (endMinutes < startMinutes) {
        // Range spans midnight
        return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
      } else {
        // Normal range
        return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
      }
    } catch (e) {
      print('Error checking time range: $e');
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
