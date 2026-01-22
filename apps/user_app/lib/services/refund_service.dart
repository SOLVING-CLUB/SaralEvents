import 'package:supabase_flutter/supabase_flutter.dart';

/// Category types for refund policy mapping
enum RefundCategoryType {
  foodCatering,      // Food & Catering Services
  venues,            // Venues (Function Halls, Banquet Halls, Farmhouses, Marriage Gardens)
  djMusicians,       // DJs, Musicians & Live Performers
  decorators,        // Decorators & Event Essentials Providers
  other,             // Default/Other categories
}

/// Refund calculation result
class RefundCalculation {
  final double refundableAmount;
  final double nonRefundableAmount;
  final double refundPercentage;
  final String reason;
  final Map<String, dynamic> breakdown;

  RefundCalculation({
    required this.refundableAmount,
    required this.nonRefundableAmount,
    required this.refundPercentage,
    required this.reason,
    required this.breakdown,
  });
}

/// Refund service implementing category-wise payment & refund policies
class RefundService {
  final SupabaseClient _supabase;

  RefundService(this._supabase);

  /// Map vendor category to refund policy category
  RefundCategoryType _getRefundCategoryType(String vendorCategory) {
    final category = vendorCategory.toLowerCase();
    
    // Food & Catering Services
    if (category.contains('catering') || 
        category.contains('food') || 
        category.contains('kitchen')) {
      return RefundCategoryType.foodCatering;
    }
    
    // Venues
    if (category.contains('venue') || 
        category.contains('hall') || 
        category.contains('banquet') || 
        category.contains('farmhouse') || 
        category.contains('garden')) {
      return RefundCategoryType.venues;
    }
    
    // DJs, Musicians & Live Performers
    if (category.contains('dj') || 
        category.contains('music') || 
        category.contains('band') || 
        category.contains('singer') || 
        category.contains('performer') || 
        category.contains('anchor')) {
      return RefundCategoryType.djMusicians;
    }
    
    // Decorators & Event Essentials
    if (category.contains('decor') || 
        category.contains('decoration') || 
        category.contains('flower') || 
        category.contains('lighting') || 
        category.contains('stage') || 
        category.contains('tent') || 
        category.contains('chair') || 
        category.contains('sound') || 
        category.contains('generator') || 
        category.contains('essential')) {
      return RefundCategoryType.decorators;
    }
    
    return RefundCategoryType.other;
  }

  /// Calculate refund for Food & Catering Services
  RefundCalculation _calculateFoodCateringRefund({
    required double advanceAmount,
    required int daysBeforeEvent,
  }) {
    double refundPercentage = 0.0;
    String reason = '';

    if (daysBeforeEvent > 7) {
      refundPercentage = 100.0;
      reason = 'More than 7 days before event - Full refund';
    } else if (daysBeforeEvent >= 3) {
      refundPercentage = 50.0;
      reason = '3-7 days before event - 50% refund';
    } else {
      refundPercentage = 0.0;
      reason = 'Less than 72 hours before event - No refund';
    }

    final refundableAmount = advanceAmount * (refundPercentage / 100);
    final nonRefundableAmount = advanceAmount - refundableAmount;

    return RefundCalculation(
      refundableAmount: refundableAmount,
      nonRefundableAmount: nonRefundableAmount,
      refundPercentage: refundPercentage,
      reason: reason,
      breakdown: {
        'category': 'Food & Catering Services',
        'days_before_event': daysBeforeEvent,
        'advance_amount': advanceAmount,
        'refund_percentage': refundPercentage,
        'refundable_amount': refundableAmount,
        'non_refundable_amount': nonRefundableAmount,
      },
    );
  }

  /// Calculate refund for Venues
  RefundCalculation _calculateVenueRefund({
    required double advanceAmount,
    required int daysBeforeEvent,
  }) {
    double refundPercentage = 0.0;
    String reason = '';

    if (daysBeforeEvent > 30) {
      refundPercentage = 75.0;
      reason = 'More than 30 days before event - 75% refund';
    } else if (daysBeforeEvent >= 15) {
      refundPercentage = 50.0;
      reason = '15-30 days before event - 50% refund';
    } else if (daysBeforeEvent >= 7) {
      refundPercentage = 25.0;
      reason = '7-15 days before event - 25% refund';
    } else {
      refundPercentage = 0.0;
      reason = 'Less than 7 days before event - No refund';
    }

    final refundableAmount = advanceAmount * (refundPercentage / 100);
    final nonRefundableAmount = advanceAmount - refundableAmount;

    return RefundCalculation(
      refundableAmount: refundableAmount,
      nonRefundableAmount: nonRefundableAmount,
      refundPercentage: refundPercentage,
      reason: reason,
      breakdown: {
        'category': 'Venues',
        'days_before_event': daysBeforeEvent,
        'advance_amount': advanceAmount,
        'refund_percentage': refundPercentage,
        'refundable_amount': refundableAmount,
        'non_refundable_amount': nonRefundableAmount,
      },
    );
  }

  /// Calculate refund for DJs, Musicians & Live Performers
  RefundCalculation _calculateDjMusicianRefund({
    required double advanceAmount,
    required int daysBeforeEvent,
  }) {
    double refundPercentage = 0.0;
    String reason = '';

    if (daysBeforeEvent > 7) {
      refundPercentage = 75.0;
      reason = 'More than 7 days before event - 75% refund';
    } else if (daysBeforeEvent >= 3) {
      refundPercentage = 50.0;
      reason = '3-7 days before event - 50% refund';
    } else {
      refundPercentage = 0.0;
      reason = 'Less than 72 hours before event - No refund';
    }

    final refundableAmount = advanceAmount * (refundPercentage / 100);
    final nonRefundableAmount = advanceAmount - refundableAmount;

    return RefundCalculation(
      refundableAmount: refundableAmount,
      nonRefundableAmount: nonRefundableAmount,
      refundPercentage: refundPercentage,
      reason: reason,
      breakdown: {
        'category': 'DJs, Musicians & Live Performers',
        'days_before_event': daysBeforeEvent,
        'advance_amount': advanceAmount,
        'refund_percentage': refundPercentage,
        'refundable_amount': refundableAmount,
        'non_refundable_amount': nonRefundableAmount,
      },
    );
  }

  /// Calculate refund for Decorators & Event Essentials
  RefundCalculation _calculateDecoratorRefund({
    required double advanceAmount,
    required int daysBeforeEvent,
  }) {
    double refundPercentage = 0.0;
    String reason = '';

    if (daysBeforeEvent >= 2) { // More than 48 hours
      refundPercentage = 75.0;
      reason = 'More than 48 hours before event - 75% refund';
    } else if (daysBeforeEvent >= 1) { // 24-48 hours
      refundPercentage = 50.0;
      reason = '24-48 hours before event - 50% refund';
    } else {
      refundPercentage = 0.0;
      reason = 'Less than 24 hours before event - No refund';
    }

    final refundableAmount = advanceAmount * (refundPercentage / 100);
    final nonRefundableAmount = advanceAmount - refundableAmount;

    return RefundCalculation(
      refundableAmount: refundableAmount,
      nonRefundableAmount: nonRefundableAmount,
      refundPercentage: refundPercentage,
      reason: reason,
      breakdown: {
        'category': 'Decorators & Event Essentials',
        'days_before_event': daysBeforeEvent,
        'advance_amount': advanceAmount,
        'refund_percentage': refundPercentage,
        'refundable_amount': refundableAmount,
        'non_refundable_amount': nonRefundableAmount,
      },
    );
  }

  /// Calculate days before event
  int _calculateDaysBeforeEvent(DateTime bookingDate, DateTime cancellationDate) {
    final difference = bookingDate.difference(cancellationDate);
    return difference.inDays;
  }

  /// Calculate refund for a booking cancellation
  Future<RefundCalculation> calculateRefund({
    required String bookingId,
    required DateTime cancellationDate,
    bool isVendorCancellation = false,
  }) async {
    try {
      // Get booking details with vendor category
      final bookingResult = await _supabase
          .from('bookings')
          .select('''
            id,
            booking_date,
            amount,
            vendor_id,
            vendor_profiles!inner(category),
            payment_milestones(status, amount, milestone_type)
          ''')
          .eq('id', bookingId)
          .single();

      final bookingDate = DateTime.parse(bookingResult['booking_date']);
      final totalAmount = (bookingResult['amount'] as num).toDouble();
      final vendorCategory = bookingResult['vendor_profiles']['category'] as String;
      final milestones = bookingResult['payment_milestones'] as List<dynamic>;

      // Vendor cancellation: 100% refund of all payments
      if (isVendorCancellation) {
        final totalPaid = milestones
            .where((m) => m['status'] == 'held_in_escrow' || m['status'] == 'released')
            .fold(0.0, (sum, m) => sum + (m['amount'] as num).toDouble());

        return RefundCalculation(
          refundableAmount: totalPaid,
          nonRefundableAmount: 0.0,
          refundPercentage: 100.0,
          reason: 'Vendor cancellation - Full refund of all payments',
          breakdown: {
            'category': vendorCategory,
            'is_vendor_cancellation': true,
            'total_paid': totalPaid,
            'refund_percentage': 100.0,
            'refundable_amount': totalPaid,
            'non_refundable_amount': 0.0,
          },
        );
      }

      // Customer cancellation: Category-specific refund policy
      final daysBeforeEvent = _calculateDaysBeforeEvent(bookingDate, cancellationDate);
      final refundCategory = _getRefundCategoryType(vendorCategory);

      // Get advance payment milestone (20%)
      final advanceMilestone = milestones.firstWhere(
        (m) => m['milestone_type'] == 'advance',
        orElse: () => null,
      );

      if (advanceMilestone == null) {
        return RefundCalculation(
          refundableAmount: 0.0,
          nonRefundableAmount: 0.0,
          refundPercentage: 0.0,
          reason: 'No advance payment found',
          breakdown: {},
        );
      }

      final advanceAmount = (advanceMilestone['amount'] as num).toDouble();
      final advanceStatus = advanceMilestone['status'] as String;

      // Only calculate refund if advance is paid
      // If advance is still pending, allow cancellation with 0 refund
      if (advanceStatus != 'held_in_escrow' && advanceStatus != 'released' && advanceStatus != 'paid') {
        return RefundCalculation(
          refundableAmount: 0.0,
          nonRefundableAmount: 0.0,
          refundPercentage: 0.0,
          reason: 'No payments made yet - Booking cancelled without refund',
          breakdown: {
            'category': vendorCategory,
            'advance_status': advanceStatus,
            'note': 'Booking cancelled before any payment was processed',
          },
        );
      }

      // Calculate refund based on category
      RefundCalculation calculation;
      switch (refundCategory) {
        case RefundCategoryType.foodCatering:
          calculation = _calculateFoodCateringRefund(
            advanceAmount: advanceAmount,
            daysBeforeEvent: daysBeforeEvent,
          );
          break;
        case RefundCategoryType.venues:
          calculation = _calculateVenueRefund(
            advanceAmount: advanceAmount,
            daysBeforeEvent: daysBeforeEvent,
          );
          break;
        case RefundCategoryType.djMusicians:
          calculation = _calculateDjMusicianRefund(
            advanceAmount: advanceAmount,
            daysBeforeEvent: daysBeforeEvent,
          );
          break;
        case RefundCategoryType.decorators:
          calculation = _calculateDecoratorRefund(
            advanceAmount: advanceAmount,
            daysBeforeEvent: daysBeforeEvent,
          );
          break;
        default:
          // Default policy: No refund for other categories
          calculation = RefundCalculation(
            refundableAmount: 0.0,
            nonRefundableAmount: advanceAmount,
            refundPercentage: 0.0,
            reason: 'Category not eligible for refund',
            breakdown: {
              'category': vendorCategory,
              'days_before_event': daysBeforeEvent,
              'advance_amount': advanceAmount,
            },
          );
      }

      return calculation;
    } catch (e) {
      print('Error calculating refund: $e');
      rethrow;
    }
  }

  /// Process refund for a booking cancellation
  Future<bool> processRefund({
    required String bookingId,
    required RefundCalculation calculation,
    required String cancelledBy, // 'customer' or 'vendor'
    String? adminNotes,
  }) async {
    try {
      // Get booking milestones that are paid (held_in_escrow or released)
      final milestonesResult = await _supabase
          .from('payment_milestones')
          .select('*')
          .eq('booking_id', bookingId)
          .inFilter('status', ['held_in_escrow', 'released', 'paid']);

      final milestones = milestonesResult as List<dynamic>;

      // Check if refund already exists for this booking
      final existingRefund = await _supabase
          .from('refunds')
          .select('id')
          .eq('booking_id', bookingId)
          .maybeSingle();

      String refundId;
      if (existingRefund != null) {
        // Refund already exists, use existing refund ID
        refundId = existingRefund['id'] as String;
        print('Refund already exists for booking $bookingId, using existing refund: $refundId');
      } else {
        // Create refund record (even if refundableAmount is 0 - this allows cancellation without payment)
        // IMPORTANT: Refunds are created with status 'pending' and require admin approval
        // Admin must release the refund in the admin portal for it to be completed
        try {
          final refundResult = await _supabase
              .from('refunds')
              .insert({
                'booking_id': bookingId,
                'cancelled_by': cancelledBy,
                'refund_amount': calculation.refundableAmount,
                'non_refundable_amount': calculation.nonRefundableAmount,
                'refund_percentage': calculation.refundPercentage,
                'reason': calculation.reason,
                'breakdown': calculation.breakdown,
                'status': calculation.refundableAmount > 0 ? 'pending' : 'completed', // If no refund, mark as completed immediately
                'admin_notes': adminNotes,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          refundId = refundResult['id'] as String;
          print('Created refund record: $refundId for booking $bookingId');
        } catch (e) {
          print('Error creating refund record: $e');
          print('Booking ID: $bookingId');
          print('Refund amount: ${calculation.refundableAmount}');
          print('Cancelled by: $cancelledBy');
          rethrow;
        }
      }

      // Update milestone statuses to refunded ONLY if refund amount > 0
      // If refund amount is 0 (no refund due to policy), milestones stay in escrow
      if (milestones.isNotEmpty && calculation.refundableAmount > 0) {
        for (final milestone in milestones) {
          final milestoneId = milestone['id'] as String;
          final milestoneAmount = (milestone['amount'] as num).toDouble();
          final milestoneType = milestone['milestone_type'] as String;
          
          // Calculate refund for this milestone
          double milestoneRefund = 0.0;
          if (milestoneType == 'advance') {
            // For advance, use the calculated refund amount
            milestoneRefund = calculation.refundableAmount;
          } else {
            // For other milestones (arrival, completion), refund only if vendor cancelled
            if (cancelledBy == 'vendor') {
              milestoneRefund = milestoneAmount;
            }
          }

          // Only mark milestone as refunded if refund amount > 0
          if (milestoneRefund > 0) {
            try {
              // Update milestone status to refunded
              await _supabase
                  .from('payment_milestones')
                  .update({
                    'status': 'refunded',
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', milestoneId);

              // Create refund milestone record
              await _supabase
                  .from('refund_milestones')
                  .insert({
                    'refund_id': refundId,
                    'milestone_id': milestoneId,
                    'refund_amount': milestoneRefund,
                    'original_amount': milestoneAmount,
                  });
            } catch (e) {
              print('Error updating milestone $milestoneId: $e');
              // Continue with other milestones even if one fails
              // Don't fail the entire refund process if one milestone update fails
            }
          }
        }
      }

      // Update booking status to cancelled (always do this, even if no refund)
      await _supabase
          .from('bookings')
          .update({
            'status': 'cancelled',
            'milestone_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId);

      return true;
    } catch (e) {
      print('Error processing refund: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Get refund details for a booking
  Future<Map<String, dynamic>?> getRefundDetails(String bookingId) async {
    try {
      final result = await _supabase
          .from('refunds')
          .select('*')
          .eq('booking_id', bookingId)
          .maybeSingle();

      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      print('Error fetching refund details: $e');
      return null;
    }
  }

  /// Calculate refund for multi-vendor/combo booking
  Future<Map<String, dynamic>> calculateMultiVendorRefund({
    required List<String> bookingIds,
    required DateTime cancellationDate,
  }) async {
    final vendorWiseRefunds = <String, RefundCalculation>{};
    double totalRefundable = 0.0;
    double totalNonRefundable = 0.0;

    for (final bookingId in bookingIds) {
      final calculation = await calculateRefund(
        bookingId: bookingId,
        cancellationDate: cancellationDate,
      );
      
      // Get vendor name for display
      final bookingResult = await _supabase
          .from('bookings')
          .select('vendor_profiles!inner(business_name)')
          .eq('id', bookingId)
          .single();
      
      final vendorName = bookingResult['vendor_profiles']['business_name'] as String;
      vendorWiseRefunds[vendorName] = calculation;
      
      totalRefundable += calculation.refundableAmount;
      totalNonRefundable += calculation.nonRefundableAmount;
    }

    return {
      'vendor_wise_refunds': vendorWiseRefunds.map((key, value) => MapEntry(
        key,
        {
          'refundable_amount': value.refundableAmount,
          'non_refundable_amount': value.nonRefundableAmount,
          'refund_percentage': value.refundPercentage,
          'reason': value.reason,
          'breakdown': value.breakdown,
        },
      )),
      'total_refundable': totalRefundable,
      'total_non_refundable': totalNonRefundable,
      'total_refund_percentage': totalRefundable / (totalRefundable + totalNonRefundable) * 100,
    };
  }
}

