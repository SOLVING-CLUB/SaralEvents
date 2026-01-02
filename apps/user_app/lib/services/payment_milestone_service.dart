import 'package:supabase_flutter/supabase_flutter.dart';

enum MilestoneType {
  advance,    // 20% - paid at booking creation
  arrival,    // 50% - paid when vendor arrives and customer confirms
  completion, // 30% - paid when setup completed and customer confirms
}

enum MilestoneStatus {
  pending,
  paid,
  heldInEscrow,
  released,
  refunded,
}

class PaymentMilestone {
  final String id;
  final String bookingId;
  final String? orderId;
  final MilestoneType type;
  final int percentage;
  final double amount;
  final MilestoneStatus status;
  final String? paymentId;
  final String? gatewayOrderId;
  final String? gatewayPaymentId;
  final DateTime? escrowHeldAt;
  final DateTime? escrowReleasedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentMilestone({
    required this.id,
    required this.bookingId,
    this.orderId,
    required this.type,
    required this.percentage,
    required this.amount,
    required this.status,
    this.paymentId,
    this.gatewayOrderId,
    this.gatewayPaymentId,
    this.escrowHeldAt,
    this.escrowReleasedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentMilestone.fromMap(Map<String, dynamic> map) {
    return PaymentMilestone(
      id: map['id'].toString(),
      bookingId: map['booking_id'].toString(),
      orderId: map['order_id']?.toString(),
      type: MilestoneType.values.firstWhere(
        (e) => e.name == map['milestone_type'],
        orElse: () => MilestoneType.advance,
      ),
      percentage: map['percentage'] as int,
      amount: (map['amount'] as num).toDouble(),
      status: MilestoneStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MilestoneStatus.pending,
      ),
      paymentId: map['payment_id']?.toString(),
      gatewayOrderId: map['gateway_order_id']?.toString(),
      gatewayPaymentId: map['gateway_payment_id']?.toString(),
      escrowHeldAt: map['escrow_held_at'] != null
          ? DateTime.parse(map['escrow_held_at'])
          : null,
      escrowReleasedAt: map['escrow_released_at'] != null
          ? DateTime.parse(map['escrow_released_at'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class PaymentMilestoneService {
  final SupabaseClient _supabase;

  PaymentMilestoneService(this._supabase);

  /// Get all milestones for a booking
  Future<List<PaymentMilestone>> getMilestonesForBooking(String bookingId) async {
    try {
      final result = await _supabase
          .from('payment_milestones')
          .select('*')
          .eq('booking_id', bookingId)
          .order('created_at', ascending: true);

      return (result as List<dynamic>)
          .map((row) => PaymentMilestone.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      print('Error fetching milestones: $e');
      return [];
    }
  }

  /// Get a specific milestone
  Future<PaymentMilestone?> getMilestone(String milestoneId) async {
    try {
      final result = await _supabase
          .from('payment_milestones')
          .select('*')
          .eq('id', milestoneId)
          .maybeSingle();

      if (result == null) return null;
      return PaymentMilestone.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('Error fetching milestone: $e');
      return null;
    }
  }

  /// Get the next pending milestone for a booking
  Future<PaymentMilestone?> getNextPendingMilestone(String bookingId) async {
    try {
      final result = await _supabase
          .from('payment_milestones')
          .select('*')
          .eq('booking_id', bookingId)
          .eq('status', 'pending')
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (result == null) return null;
      return PaymentMilestone.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('Error fetching next milestone: $e');
      return null;
    }
  }

  /// Mark milestone as paid and held in escrow
  Future<bool> markMilestonePaid({
    required String milestoneId,
    required String paymentId,
    String? gatewayOrderId,
    String? gatewayPaymentId,
  }) async {
    try {
      await _supabase.rpc('update_milestone_status', params: {
        'p_booking_id': (await getMilestone(milestoneId))?.bookingId ?? '',
        'p_milestone_type': (await getMilestone(milestoneId))?.type.name ?? '',
        'p_status': 'held_in_escrow',
        'p_payment_id': paymentId,
        'p_gateway_order_id': gatewayOrderId,
        'p_gateway_payment_id': gatewayPaymentId,
      });

      // Also update directly for immediate feedback
      await _supabase
          .from('payment_milestones')
          .update({
            'status': 'held_in_escrow',
            'payment_id': paymentId,
            'gateway_order_id': gatewayOrderId,
            'gateway_payment_id': gatewayPaymentId,
            'escrow_held_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', milestoneId);

      return true;
    } catch (e) {
      print('Error marking milestone as paid: $e');
      return false;
    }
  }

  /// Release milestone from escrow (admin action)
  Future<bool> releaseMilestoneFromEscrow(String milestoneId) async {
    try {
      await _supabase
          .from('payment_milestones')
          .update({
            'status': 'released',
            'escrow_released_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', milestoneId);

      return true;
    } catch (e) {
      print('Error releasing milestone: $e');
      return false;
    }
  }

  /// Calculate total paid amount for a booking
  Future<double> getTotalPaidForBooking(String bookingId) async {
    try {
      final milestones = await getMilestonesForBooking(bookingId);
      return milestones
          .where((m) => m.status == MilestoneStatus.heldInEscrow ||
              m.status == MilestoneStatus.released)
          .fold(0.0, (sum, m) => sum + m.amount);
    } catch (e) {
      print('Error calculating total paid: $e');
      return 0.0;
    }
  }

  /// Get milestone progress percentage
  Future<double> getMilestoneProgress(String bookingId) async {
    try {
      final milestones = await getMilestonesForBooking(bookingId);
      if (milestones.isEmpty) return 0.0;

      int totalPercentage = 0;
      for (final milestone in milestones) {
        if (milestone.status == MilestoneStatus.heldInEscrow ||
            milestone.status == MilestoneStatus.released) {
          totalPercentage += milestone.percentage;
        }
      }

      return totalPercentage / 100.0;
    } catch (e) {
      print('Error calculating progress: $e');
      return 0.0;
    }
  }
}

