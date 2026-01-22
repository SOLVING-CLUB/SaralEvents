import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/order_repository.dart';
import '../services/payment_service.dart';
import '../services/refund_service.dart';
import '../core/utils/time_utils.dart';
import 'cancellation_flow_screen.dart';

/// Screen to display order/booking status with details
class OrderStatusScreen extends StatefulWidget {
  final String? bookingId;
  final String? orderId;

  const OrderStatusScreen({
    super.key,
    this.bookingId,
    this.orderId,
  }) : assert(bookingId != null || orderId != null, 'Either bookingId or orderId must be provided');

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _refund;
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _bookingChannel;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _subscribeToBookingUpdates();
  }

  @override
  void dispose() {
    _bookingChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToBookingUpdates() {
    if (widget.bookingId == null) return;
    
    try {
      final client = Supabase.instance.client;
      _bookingChannel?.unsubscribe();
      
      _bookingChannel = client
          .channel('booking_${widget.bookingId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.bookingId,
            ),
            callback: (payload) {
              // Reload booking details when updated
              _loadOrderDetails();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up real-time subscription: $e');
    }
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load booking details if bookingId is provided
      if (widget.bookingId != null) {
        final bookingService = BookingService(Supabase.instance.client);
        // Force refresh so we don't read stale cached bookings after status changes
        final bookings = await bookingService.getUserBookings(forceRefresh: true);
        _booking = bookings.firstWhere(
          (b) => b['booking_id'] == widget.bookingId,
          orElse: () => <String, dynamic>{},
        );

        if (_booking!.isEmpty) {
          throw Exception('Booking not found');
        }

        // Try to get order ID from booking if available
        final orderId = _booking!['order_id'] as String?;
        if (orderId != null && widget.orderId == null) {
          await _loadOrder(orderId);
        }

        // Load refund details if booking is cancelled
        if (_booking!['status'] == 'cancelled') {
          await _loadRefundDetails(widget.bookingId!);
        }
      }

      // Load order details if orderId is provided
      if (widget.orderId != null && _order == null) {
        await _loadOrder(widget.orderId!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrder(String orderId) async {
    try {
      final orderRepo = OrderRepository(Supabase.instance.client);
      final order = await orderRepo.getOrderById(orderId);
      if (order != null) {
        setState(() {
          _order = order;
        });
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    }
  }

  Future<void> _loadRefundDetails(String bookingId) async {
    try {
      final refundService = RefundService(Supabase.instance.client);
      final refund = await refundService.getRefundDetails(bookingId);
      if (refund != null) {
        setState(() {
          _refund = refund;
        });
      }
    } catch (e) {
      debugPrint('Error loading refund details: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrderDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrderDetails,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Header Card
                        _buildStatusCard(),
                        const SizedBox(height: 24),

                        // Order/Booking Details
                        if (_booking != null) _buildBookingDetails(),
                        if (_order != null) _buildOrderDetails(),

                        const SizedBox(height: 24),

                        // Timeline/Status Steps
                        _buildStatusTimeline(),

                        const SizedBox(height: 24),

                        // Action Buttons
                        if (_booking != null) _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final status = _booking?['status'] as String? ?? _order?['status'] as String? ?? 'unknown';
    final milestoneStatus = _booking?['milestone_status'] as String?;
    
    // Determine display status:
    // - If milestone_status is 'created', it means payment is done but vendor hasn't accepted yet - show as PENDING
    // - Only show as CONFIRMED when vendor has actually accepted (milestone_status is 'accepted' or beyond)
    // - If status is 'confirmed' but milestone_status is 'created', it's a data inconsistency - show as PENDING
    final displayStatus = (milestoneStatus == 'created')
        ? 'pending' // Payment done, waiting for vendor acceptance
        : (milestoneStatus != null && ['accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(milestoneStatus))
            ? 'confirmed' // Vendor has accepted or beyond
            : (status.toLowerCase() == 'pending')
                ? 'pending'
                : status.toLowerCase();
    
    // Derive a more user-friendly header label/message based on milestoneStatus
    String headerLabel;
    String headerMessage;

    if (milestoneStatus == 'completed' || status.toLowerCase() == 'completed') {
      headerLabel = 'COMPLETED';
      headerMessage = 'Order completed successfully.';
    } else if (milestoneStatus == 'vendor_arrived') {
      headerLabel = 'VENDOR ARRIVED';
      headerMessage = 'Vendor has arrived at your location. Please confirm their arrival.';
    } else if (milestoneStatus == 'arrival_confirmed') {
      headerLabel = 'ARRIVAL CONFIRMED';
      headerMessage = 'You confirmed the vendor\'s arrival. Setup will start soon.';
    } else if (milestoneStatus == 'setup_completed') {
      headerLabel = 'SETUP COMPLETED';
      headerMessage = 'Vendor has completed the setup. Please review and confirm.';
    } else if (milestoneStatus == 'setup_confirmed') {
      headerLabel = 'SETUP CONFIRMED';
      headerMessage = 'You confirmed setup completion. Order is nearing completion.';
    } else if (status.toLowerCase() == 'cancelled') {
      headerLabel = 'CANCELLED';
      // Show who cancelled the booking
      final cancelledBy = _refund?['cancelled_by'] as String?;
      if (cancelledBy == 'customer') {
        headerMessage = 'This booking was cancelled by you.';
      } else if (cancelledBy == 'vendor') {
        headerMessage = 'This booking was cancelled by the vendor.';
      } else {
        headerMessage = 'This booking has been cancelled.';
      }
    } else {
      headerLabel = displayStatus.toUpperCase();
      headerMessage = _getStatusMessage(displayStatus, milestoneStatus);
    }

    final statusColor = _getStatusColor(displayStatus);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(displayStatus),
                size: 40,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              headerLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              headerMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingDetails() {
    final serviceName = _booking!['service_name'] as String? ?? 'Unknown Service';
    final vendorName = _booking!['vendor_name'] as String? ?? 'Unknown Vendor';
    final amount = _booking!['amount'] as num? ?? 0;
    final bookingDate = _booking!['booking_date'] as String?;
    final bookingTime = _booking!['booking_time'] as String?;
    final notes = _booking!['notes'] as String?;
    final bookingId = _booking!['booking_id'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.receipt_long, 'Service', serviceName),
            _buildDetailRow(Icons.business, 'Vendor', vendorName),
            if (bookingId != null)
              _buildCopyableDetailRow(Icons.tag, 'Booking ID', bookingId),
            if (bookingDate != null)
              _buildDetailRow(
                Icons.calendar_today,
                'Date',
                TimeUtils.formatDateTime(bookingDate).split(' ').first,
              ),
            if (bookingTime != null)
              _buildDetailRow(Icons.access_time, 'Time', bookingTime),
            _buildDetailRow(
              Icons.attach_money,
              'Amount',
              '₹${amount.toStringAsFixed(2)}',
              isBold: true,
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(notes),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final orderId = _order!['id'] as String? ?? '';
    final totalAmount = _order!['total_amount'] as num? ?? 0;
    final paymentId = _order!['payment_id'] as String?;
    final createdAt = _order!['created_at'] as String?;
    final razorpayOrderId = _order!['razorpay_order_id'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (orderId.isNotEmpty)
              _buildCopyableDetailRow(Icons.receipt, 'Order ID', orderId),
            if (paymentId != null)
              _buildDetailRow(Icons.payment, 'Payment ID', '${paymentId.substring(0, 8)}...'),
            if (razorpayOrderId != null)
              _buildDetailRow(Icons.account_circle, 'Gateway Order', '${razorpayOrderId.substring(0, 8)}...'),
            _buildDetailRow(
              Icons.attach_money,
              'Total Amount',
              '₹${totalAmount.toStringAsFixed(2)}',
              isBold: true,
            ),
            if (createdAt != null)
              _buildDetailRow(
                Icons.schedule,
                'Order Date',
                TimeUtils.formatDateTime(createdAt),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableDetailRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.length > 20 ? '${value.substring(0, 20)}...' : value,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy $label',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final status = _booking?['status'] as String? ?? _order?['status'] as String? ?? 'unknown';
    final milestoneStatus = _booking?['milestone_status'] as String?;
    final createdAt = _booking?['created_at'] as String? ?? _order?['created_at'] as String?;
    final vendorAcceptedAt = _booking?['vendor_accepted_at'] as String?;
    final vendorArrivedAt = _booking?['vendor_arrived_at'] as String?;
    final arrivalConfirmedAt = _booking?['arrival_confirmed_at'] as String?;
    final setupCompletedAt = _booking?['setup_completed_at'] as String?;
    final setupConfirmedAt = _booking?['setup_confirmed_at'] as String?;
    final completedAt = _booking?['completed_at'] as String?;

    // Determine completion status for each milestone step
    final isBookingConfirmed = milestoneStatus != null && 
        ['accepted', 'vendor_traveling', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(milestoneStatus);
    final isVendorArrived = milestoneStatus != null && 
        ['vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(milestoneStatus);
    final isArrivalConfirmed = milestoneStatus != null && 
        ['arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'].contains(milestoneStatus);
    final isSetupCompleted = milestoneStatus != null && 
        ['setup_completed', 'setup_confirmed', 'completed'].contains(milestoneStatus);
    final isSetupConfirmed = milestoneStatus != null && 
        ['setup_confirmed', 'completed'].contains(milestoneStatus);
    final isOrderCompleted = milestoneStatus == 'completed' || status == 'completed';

    final steps = [
      _TimelineStep(
        title: 'Order Placed',
        description: createdAt != null ? TimeUtils.formatDateTime(createdAt) : 'Pending',
        isCompleted: true,
        isActive: false,
      ),
      _TimelineStep(
        title: 'Payment Confirmed',
        description: 'Advance payment (20%) processed successfully',
        // Payment is confirmed when milestone_status exists (payment was made)
        // It's active when payment is done but vendor hasn't accepted yet
        isCompleted: milestoneStatus != null, // Payment made if milestone_status exists
        isActive: milestoneStatus == 'created', // Active when waiting for vendor acceptance
      ),
      _TimelineStep(
        title: 'Booking Confirmed',
        description: vendorAcceptedAt != null 
            ? 'Vendor confirmed booking - ${TimeUtils.formatDateTime(vendorAcceptedAt)}'
            : 'Waiting for vendor confirmation',
        isCompleted: isBookingConfirmed,
        isActive: milestoneStatus == 'accepted',
      ),
      _TimelineStep(
        title: 'Vendor Arrived',
        description: vendorArrivedAt != null 
            ? 'Vendor arrived at location - ${TimeUtils.formatDateTime(vendorArrivedAt)}'
            : 'Waiting for vendor to arrive',
        isCompleted: isVendorArrived,
        isActive: milestoneStatus == 'vendor_arrived',
      ),
      _TimelineStep(
        title: 'Arrival Confirmed',
        description: arrivalConfirmedAt != null 
            ? 'You confirmed vendor arrival - ${TimeUtils.formatDateTime(arrivalConfirmedAt)}'
            : 'Please confirm vendor arrival',
        isCompleted: isArrivalConfirmed,
        isActive: milestoneStatus == 'arrival_confirmed',
      ),
      _TimelineStep(
        title: 'Setup Completed',
        description: setupCompletedAt != null 
            ? 'Vendor completed setup - ${TimeUtils.formatDateTime(setupCompletedAt)}'
            : 'Waiting for vendor to complete setup',
        isCompleted: isSetupCompleted,
        isActive: milestoneStatus == 'setup_completed',
      ),
      _TimelineStep(
        title: 'Setup Confirmed',
        description: setupConfirmedAt != null 
            ? 'You confirmed setup completion - ${TimeUtils.formatDateTime(setupConfirmedAt)}'
            : 'Please confirm setup completion',
        isCompleted: isSetupConfirmed,
        isActive: milestoneStatus == 'setup_confirmed',
      ),
      _TimelineStep(
        title: 'Order Completed',
        description: completedAt != null 
            ? 'Order completed - ${TimeUtils.formatDateTime(completedAt)}'
            : 'All milestones completed',
        isCompleted: isOrderCompleted,
        isActive: isOrderCompleted,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Timeline',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;

              return _buildTimelineStep(step, isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(_TimelineStep step, bool isLast) {
    final theme = Theme.of(context);
    final color = step.isCompleted
        ? theme.colorScheme.primary
        : step.isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withOpacity(0.3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.isCompleted || step.isActive ? color : Colors.transparent,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
              ),
              child: step.isCompleted
                  ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                  : step.isActive
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isCompleted ? color : theme.colorScheme.onSurface.withOpacity(0.2),
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: step.isActive || step.isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: step.isActive || step.isCompleted ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = _booking?['status'] as String? ?? 'unknown';
    // bookingId here is the actual primary key id used in the bookings table
    final bookingId = widget.bookingId ?? _booking?['id'] as String?;
    final vendorArrivedAt = _booking?['vendor_arrived_at'] as String?;
    final arrivalConfirmedAt = _booking?['arrival_confirmed_at'] as String?;
    final setupCompletedAt = _booking?['setup_completed_at'] as String?;
    final setupConfirmedAt = _booking?['setup_confirmed_at'] as String?;
    final arrivalMilestonePaid = _booking?['arrival_milestone_paid'] as bool? ?? false;
    final completionMilestonePaid = _booking?['completion_milestone_paid'] as bool? ?? false;

    final shouldShowArrivalConfirm =
        vendorArrivedAt != null && arrivalConfirmedAt == null;
    final shouldShowSetupConfirm =
        setupCompletedAt != null && setupConfirmedAt == null;

    return Column(
      children: [
        // 1) Require 50% payment after arrival confirmation
        if (!arrivalMilestonePaid && arrivalConfirmedAt != null && bookingId != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final paymentService = PaymentService();
                await paymentService.processMilestonePayment(
                  context: context,
                  bookingId: bookingId,
                  milestoneType: 'arrival',
                  onSuccess: () async {
                    // Reload order details after successful payment
                    await _loadOrderDetails();
                  },
                  onFailure: () {
                    // Payment failed, no need to reload
                  },
                );
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pay 50% (On Arrival)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (!arrivalMilestonePaid && arrivalConfirmedAt != null)
          const SizedBox(height: 12),

        if (shouldShowArrivalConfirm && bookingId != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('bookings')
                      .update({
                        'milestone_status': 'arrival_confirmed',
                        'arrival_confirmed_at':
                            DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', bookingId);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vendor arrival confirmed successfully'),
                    ),
                  );
                  await _loadOrderDetails();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error confirming arrival: $e'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Vendor Arrival'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (shouldShowArrivalConfirm || shouldShowSetupConfirm)
          const SizedBox(height: 12),

        if (shouldShowSetupConfirm && bookingId != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('bookings')
                      .update({
                        'milestone_status': 'setup_confirmed',
                        'setup_confirmed_at':
                            DateTime.now().toIso8601String(),
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', bookingId);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Setup confirmed successfully'),
                    ),
                  );
                  await _loadOrderDetails();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error confirming setup: $e'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Setup Completion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (shouldShowSetupConfirm) const SizedBox(height: 12),

        // 2) Require final 30% payment after setup confirmed
        if (!completionMilestonePaid && setupConfirmedAt != null && bookingId != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final paymentService = PaymentService();
                await paymentService.processMilestonePayment(
                  context: context,
                  bookingId: bookingId,
                  milestoneType: 'completion',
                  onSuccess: () async {
                    // Reload order details after successful payment
                    await _loadOrderDetails();
                  },
                  onFailure: () {
                    // Payment failed, no need to reload
                  },
                );
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pay Final 30%'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (!completionMilestonePaid && setupConfirmedAt != null)
          const SizedBox(height: 12),
        if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'confirmed' && bookingId != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CancellationFlowScreen(bookingId: bookingId!),
                  ),
                );

                if (result == true && mounted) {
                  // Reload booking details after cancellation
                  await _loadOrderDetails();
                }
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Booking'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDBB42),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }

  String _getStatusMessage(String status, [String? milestoneStatus]) {
    // If status is pending and milestone_status is 'created', payment is done but vendor hasn't accepted
    if (status.toLowerCase() == 'pending' && milestoneStatus == 'created') {
      return 'Payment received. Waiting for vendor to accept your booking.';
    }
    
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Your booking has been confirmed by the vendor.';
      case 'pending':
        return 'Your booking is pending confirmation.';
      case 'cancelled':
        // Show who cancelled (if refund info is loaded)
        final cancelledBy = _refund?['cancelled_by'] as String?;
        if (cancelledBy == 'customer') {
          return 'This booking was cancelled by you.';
        } else if (cancelledBy == 'vendor') {
          return 'This booking was cancelled by the vendor.';
        }
        return 'This booking has been cancelled.';
      case 'completed':
        return 'This service has been completed.';
      default:
        return 'Order status: $status';
    }
  }
}

class _TimelineStep {
  final String title;
  final String description;
  final bool isCompleted;
  final bool isActive;

  _TimelineStep({
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isActive,
  });
}
