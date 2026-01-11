import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/payment_milestone_service.dart';
import '../models/service_models.dart';
import 'dart:async';

class OrderTrackingScreen extends StatefulWidget {
  final String bookingId;
  final String? serviceId;
  final String? vendorId;

  const OrderTrackingScreen({
    super.key,
    required this.bookingId,
    this.serviceId,
    this.vendorId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final BookingService _bookingService = BookingService(Supabase.instance.client);
  final PaymentMilestoneService _milestoneService =
      PaymentMilestoneService(Supabase.instance.client);

  Map<String, dynamic>? _booking;
  List<PaymentMilestone> _milestones = [];
  ServiceItem? _service;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh every 10 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load booking details
      final bookings = await _bookingService.getUserBookings();
      _booking = bookings.firstWhere(
        (b) => b['id'].toString() == widget.bookingId,
        orElse: () => {},
      );

      // Load milestones
      _milestones = await _milestoneService.getMilestonesForBooking(widget.bookingId);

      // Load service details if serviceId is available
      if (widget.serviceId != null) {
        try {
          final serviceResult = await Supabase.instance.client
              .from('services')
              .select('*')
              .eq('id', widget.serviceId)
              .maybeSingle();
          if (serviceResult != null) {
            _service = ServiceItem.fromMap(Map<String, dynamic>.from(serviceResult));
          }
        } catch (e) {
          print('Error loading service: $e');
        }
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error loading order data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_booking == null || _booking!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Tracking')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final milestoneStatus = _booking!['milestone_status'] as String? ?? 'created';
    final progress = _calculateProgress(milestoneStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service Info Card
              if (_service != null) _buildServiceInfoCard(),
              
              // Progress Indicator (Zomato-like)
              _buildProgressIndicator(milestoneStatus, progress),
              
              // Milestone Details
              _buildMilestoneDetails(),
              
              // Payment Summary
              _buildPaymentSummary(),
              
              // Action Buttons
              _buildActionButtons(milestoneStatus),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFDBB42).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.event,
              color: const Color(0xFFFDBB42),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _service?.name ?? 'Service',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _service?.category ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(String status, double progress) {
    final milestones = [
      _MilestoneStep(
        title: 'Booking Created',
        subtitle: 'Your booking is confirmed',
        icon: Icons.check_circle,
        isCompleted: true,
        isActive: status == 'created',
      ),
      _MilestoneStep(
        title: 'Vendor Accepted',
        subtitle: 'Vendor has accepted your booking',
        icon: Icons.handshake,
        isCompleted: ['accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(status),
        isActive: status == 'accepted',
      ),
      _MilestoneStep(
        title: 'Vendor Arrived',
        subtitle: 'Vendor has arrived at location',
        icon: Icons.location_on,
        isCompleted: ['vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(status),
        isActive: status == 'vendor_arrived',
      ),
      _MilestoneStep(
        title: 'Setup Completed',
        subtitle: 'Vendor has completed the setup',
        icon: Icons.build,
        isCompleted: ['setup_completed', 'setup_confirmed', 'completed'].contains(status),
        isActive: status == 'setup_completed',
      ),
      _MilestoneStep(
        title: 'Order Completed',
        subtitle: 'All milestones completed',
        icon: Icons.celebration,
        isCompleted: status == 'completed',
        isActive: status == 'completed',
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Icon(Icons.track_changes, color: Color(0xFFFDBB42)),
              const SizedBox(width: 8),
              const Text(
                'Order Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDBB42),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...milestones.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == milestones.length - 1;

            return _buildMilestoneStep(step, isLast);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMilestoneStep(_MilestoneStep step, bool isLast) {
    final color = step.isCompleted
        ? Colors.green
        : step.isActive
            ? const Color(0xFFFDBB42)
            : Colors.grey[300]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? Colors.green
                    : step.isActive
                        ? const Color(0xFFFDBB42)
                        : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted ? Colors.green : Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: step.isActive || step.isCompleted
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: step.isCompleted || step.isActive
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Milestones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._milestones.map((milestone) => _buildMilestoneCard(milestone)),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(PaymentMilestone milestone) {
    final statusColor = milestone.status == MilestoneStatus.released
        ? Colors.green
        : milestone.status == MilestoneStatus.heldInEscrow
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${milestone.percentage}% - ${milestone.type.name.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${milestone.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            milestone.status.name.toUpperCase().replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final totalAmount = _booking!['amount'] as num? ?? 0.0;
    final totalPaid = _milestones
        .where((m) =>
            m.status == MilestoneStatus.heldInEscrow ||
            m.status == MilestoneStatus.released)
        .fold(0.0, (sum, m) => sum + m.amount);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDBB42).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBB42).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:'),
              Text(
                '₹${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount Paid:'),
              Text(
                '₹${totalPaid.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Remaining:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹${(totalAmount - totalPaid).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFFFDBB42),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Show payment button for next milestone
          if (status == 'created' || status == 'accepted' || status == 'vendor_arrived' || status == 'setup_completed')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleNextPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDBB42),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pay Next Milestone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Show confirmation buttons
          if (status == 'vendor_arrived')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmArrival(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Vendor Arrival',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          if (status == 'setup_completed')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmSetup(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Setup Completion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateProgress(String status) {
    switch (status) {
      case 'created':
        return 0.2;
      case 'accepted':
        return 0.3;
      case 'vendor_traveling':
        return 0.4;
      case 'vendor_arrived':
        return 0.5;
      case 'arrival_confirmed':
        return 0.6;
      case 'setup_completed':
        return 0.8;
      case 'setup_confirmed':
        return 0.9;
      case 'completed':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Future<void> _handleNextPayment() async {
    // Navigate to payment screen for next milestone
    final nextMilestone = await _milestoneService.getNextPendingMilestone(widget.bookingId);
    if (nextMilestone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending payments')),
      );
      return;
    }

    // TODO: Navigate to payment screen with milestone details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment for ${nextMilestone.percentage}% milestone (₹${nextMilestone.amount.toStringAsFixed(2)})')),
    );
  }

  Future<void> _confirmArrival() async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'milestone_status': 'arrival_confirmed',
            'arrival_confirmed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arrival confirmed successfully')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error confirming arrival: $e')),
      );
    }
  }

  Future<void> _confirmSetup() async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({
            'milestone_status': 'setup_confirmed',
            'setup_confirmed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup confirmed successfully')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error confirming setup: $e')),
      );
    }
  }
}

class _MilestoneStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;

  _MilestoneStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
  });
}


