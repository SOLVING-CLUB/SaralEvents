import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bookings/booking_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String bookingId;

  const OrderDetailsScreen({super.key, required this.bookingId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final BookingService _bookingService;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _refund;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bookingService = BookingService(Supabase.instance.client);
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.getVendorBookings();
      final booking = bookings.firstWhere(
        (b) => b['id'] == widget.bookingId,
        orElse: () => <String, dynamic>{},
      );

      if (booking.isEmpty) {
        setState(() {
          _error = 'Booking not found';
          _isLoading = false;
        });
        return;
      }

      // Load additional details like payment milestones
      try {
        final milestones = await Supabase.instance.client
            .from('payment_milestones')
            .select('*')
            .eq('booking_id', widget.bookingId)
            .order('created_at', ascending: true);

        booking['payment_milestones'] = milestones;
      } catch (e) {
        print('Error loading payment milestones: $e');
      }

      // Load refund details if booking is cancelled
      if (booking['status'] == 'cancelled') {
        try {
          final refundResult = await Supabase.instance.client
              .from('refunds')
              .select('*')
              .eq('booking_id', widget.bookingId)
              .maybeSingle();
          
          if (refundResult != null) {
            _refund = refundResult;
          }
        } catch (e) {
          print('Error loading refund details: $e');
        }
      }

      if (mounted) {
        setState(() {
          _booking = booking;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'confirmed':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayStatus(String status) {
    if (status.toLowerCase() == 'confirmed') {
      return 'PENDING';
    }
    return status.toUpperCase();
  }

  String _getCancelledByMessage() {
    final cancelledBy = _refund?['cancelled_by'] as String?;
    if (cancelledBy == 'customer') {
      return 'Cancelled by customer';
    } else if (cancelledBy == 'vendor') {
      return 'Cancelled by you';
    }
    return 'Booking cancelled';
  }

  Future<void> _openLocationLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open location link: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening location link: $e')),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return 'Not specified';
    try {
      final parts = timeString.split(':');
      if (parts.isEmpty) return timeString;
      
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final minuteStr = minute.toString().padLeft(2, '0');
      
      return '$hour12:$minuteStr $period';
    } catch (e) {
      return timeString;
    }
  }

  Future<void> _updateBookingStatus(String newStatus, [String? notes]) async {
    try {
      // Enforce payment gating for completion:
      // Vendor can only mark booking as completed after customer paid final 30% (completion milestone)
      if (newStatus == 'completed') {
        final paymentMilestones = _booking?['payment_milestones'] as List<dynamic>? ?? [];
        Map<String, dynamic>? completionMilestone;
        try {
          completionMilestone = paymentMilestones.firstWhere(
            (m) => m['milestone_type'] == 'completion',
          ) as Map<String, dynamic>?;
        } catch (_) {
          completionMilestone = null;
        }

        final completionPaymentStatus =
            completionMilestone != null ? completionMilestone['status'] as String? : null;
        final isCompletionPaid = completionPaymentStatus == 'held_in_escrow' ||
            completionPaymentStatus == 'paid' ||
            completionPaymentStatus == 'released';

        if (!isCompletionPaid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot mark as completed: waiting for customer to complete final payment (30%). '
                  'Payment Status: ${completionPaymentStatus ?? 'Pending'}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      final success = await _bookingService.updateBookingStatus(
        widget.bookingId,
        newStatus,
        notes,
      );
      
      if (success) {
        await _loadBookingDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Booking status updated to ${newStatus.toUpperCase()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusUpdateDialog() {
    final currentStatus = _booking?['status'] as String? ?? '';
    final notesController = TextEditingController();

    if (currentStatus == 'completed' || currentStatus == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update status for completed or cancelled bookings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Booking Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mark this booking as completed?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any additional notes...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updateBookingStatus(
                'completed',
                notesController.text.isNotEmpty ? notesController.text : null,
              );
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Mark as Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading order details...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading order',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Order not found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadBookingDetails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final booking = _booking!;
    final status = booking['status'] as String;
    final milestoneStatusRaw = booking['milestone_status'] as String?;
    final milestoneStatus = milestoneStatusRaw ?? 'created';
    final locationLink = booking['location_link'] as String?;
    
    // Normalize milestone_status for comparison
    final normalizedMilestoneStatusRaw = milestoneStatusRaw?.toString().trim().toLowerCase();
    final normalizedMilestoneStatus = normalizedMilestoneStatusRaw ?? 'created';
    
    // Debug logging
    print('🔍 OrderDetailsScreen: Loading order details for booking: ${widget.bookingId}');
    print('   status: "$status" (type: ${status.runtimeType})');
    print('   milestoneStatusRaw: "$milestoneStatusRaw" (type: ${milestoneStatusRaw.runtimeType})');
    print('   normalizedMilestoneStatusRaw: "$normalizedMilestoneStatusRaw"');
    print('   normalizedMilestoneStatus: "$normalizedMilestoneStatus"');
    print('   status == "pending": ${status.toString().toLowerCase() == "pending"}');
    print('   normalizedMilestoneStatusRaw == null: ${normalizedMilestoneStatusRaw == null}');
    print('   normalizedMilestoneStatus == "created": ${normalizedMilestoneStatus == "created"}');
    print('   location_link: "$locationLink" (type: ${locationLink.runtimeType})');
    print('   location_link isNotEmpty: ${locationLink != null && locationLink.isNotEmpty}');
    
    final isPending = status.toString().toLowerCase() == 'pending';
    final shouldShowAcceptReject = isPending && (
      normalizedMilestoneStatusRaw == null || 
      normalizedMilestoneStatusRaw.isEmpty ||
      normalizedMilestoneStatus == 'created'
    );
    print('   shouldShowAcceptReject: $shouldShowAcceptReject');
    final amount = (booking['amount'] as num?)?.toDouble() ?? 0.0;
    final bookingDate = booking['booking_date'] as String?;
    final bookingTime = booking['booking_time'] as String?;
    final notes = booking['notes'] as String?;
    final customerName = booking['customer_name'] as String? ?? 'Customer';
    final customerEmail = booking['customer_email'] as String?;
    final customerPhone = booking['customer_phone'] as String?;
    final serviceName = booking['service_name'] as String? ?? 'Service';
    final serviceDescription = booking['service_description'] as String?;
    final createdAt = booking['created_at'] as String?;
    final paymentMilestones = booking['payment_milestones'] as List<dynamic>? ?? [];
    final bookingId = booking['id'] as String? ?? widget.bookingId;
    final orderId = booking['order_id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookingDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Card
            Card(
              elevation: 0,
              color: _getStatusColor(status).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _getStatusColor(status),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        status == 'completed' 
                            ? Icons.check_circle
                            : status == 'cancelled'
                                ? Icons.cancel
                                : Icons.schedule,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Order Status',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDisplayStatus(status),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                          // Show who cancelled if booking is cancelled
                          if (status == 'cancelled' && _refund != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getCancelledByMessage(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Milestone status text (high level customer flow)
            Row(
              children: [
                const Icon(Icons.timeline, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Milestone: ${milestoneStatus.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Service Information
            _buildSection(
              title: 'Service Information',
              icon: Icons.room_service,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    serviceName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (serviceDescription != null && serviceDescription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      serviceDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Total Amount',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Customer Information
            _buildSection(
              title: 'Customer Details',
              icon: Icons.person,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('Name', customerName),
                  if (customerEmail != null && customerEmail.isNotEmpty)
                    _buildInfoRow('Email', customerEmail),
                  if (customerPhone != null && customerPhone.isNotEmpty)
                    _buildInfoRow('Phone', customerPhone),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order Information
            _buildSection(
              title: 'Order Information',
              icon: Icons.receipt_long,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCopyableInfoRow('Booking ID', bookingId),
                  if (orderId != null && orderId.isNotEmpty)
                    _buildCopyableInfoRow('Order ID', orderId),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location Link (if available)
            if (booking['location_link'] != null && (booking['location_link'] as String).isNotEmpty) ...[
              _buildSection(
                title: 'Destination Location',
                icon: Icons.location_on,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        final locationLink = booking['location_link'] as String;
                        // Open location link in browser/maps app
                        _openLocationLink(locationLink);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'View Location on Maps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    booking['location_link'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new, color: Colors.green),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Event Details
            _buildSection(
              title: 'Event Details',
              icon: Icons.event,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('Date', _formatDate(bookingDate)),
                  _buildInfoRow('Time', _formatTime(bookingTime)),
                  if (createdAt != null)
                    _buildInfoRow(
                      'Ordered',
                      DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(createdAt)),
                    ),
                ],
              ),
            ),

            // Payment Milestones
            if (paymentMilestones.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Payment Milestones',
                icon: Icons.payment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: paymentMilestones.asMap().entries.map((entry) {
                    final milestone = entry.value as Map<String, dynamic>;
                    final milestoneType = milestone['milestone_type'] as String? ?? '';
                    final milestoneAmount = (milestone['amount'] as num?)?.toDouble() ?? 0.0;
                    final milestoneStatus = milestone['status'] as String? ?? 'pending';
                    
                    return Padding(
                      padding: EdgeInsets.only(bottom: entry.key < paymentMilestones.length - 1 ? 12 : 0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: milestoneStatus == 'paid' || milestoneStatus == 'released'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              milestoneStatus == 'paid' || milestoneStatus == 'released'
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: milestoneStatus == 'paid' || milestoneStatus == 'released'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  milestoneType.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  milestoneStatus.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${milestoneAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection(
                title: 'Notes',
                icon: Icons.note,
                child:                 Text(
                  notes,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons (milestone-based flow)
            if (status != 'completed' && status != 'cancelled') ...[
              const Divider(height: 32),
              // Show accept/reject buttons if booking is pending and needs vendor acceptance
              if (shouldShowAcceptReject) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await _bookingService.acceptBooking(widget.bookingId);
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Booking accepted. Customer will be notified.')),
                        );
                        _loadBookingDetails();
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Accept Booking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await _bookingService.cancelBookingAsVendor(
                        bookingId: widget.bookingId,
                        reason: 'Vendor rejected booking before acceptance',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['success'] == true
                                ? 'Booking cancelled. Refund will be processed to customer.'
                                : (result['error']?.toString() ?? 'Failed to cancel booking')),
                          ),
                        );
                        if (result['success'] == true) {
                          _loadBookingDetails();
                        }
                      }
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Reject Booking'),
                  ),
                ),
              ] else if (milestoneStatus == 'accepted' ||
                  milestoneStatus == 'vendor_traveling') ...[
                // Vendor can mark arrived only after accepting and before user confirms arrival
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await _bookingService.markArrived(widget.bookingId);
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as arrived. Customer will be asked to confirm.')),
                        );
                        _loadBookingDetails();
                      }
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Mark Arrived at Location'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else if (milestoneStatus == 'vendor_arrived') ...[
                // Waiting for user to confirm arrival
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Waiting for customer to confirm your arrival.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (milestoneStatus == 'arrival_confirmed') ...[
                // User confirmed arrival - check if arrival payment is completed before allowing setup
                Builder(
                  builder: (context) {
                    // Check if arrival payment milestone is paid/held_in_escrow
                    final paymentMilestones = booking['payment_milestones'] as List<dynamic>? ?? [];
                    Map<String, dynamic>? arrivalMilestone;
                    try {
                      arrivalMilestone = paymentMilestones.firstWhere(
                        (m) => m['milestone_type'] == 'arrival',
                      ) as Map<String, dynamic>?;
                    } catch (e) {
                      arrivalMilestone = null;
                    }
                    
                    final arrivalPaymentStatus = arrivalMilestone != null 
                        ? arrivalMilestone['status'] as String? 
                        : null;
                    
                    print('🔍 Payment Check: arrival milestone status = $arrivalPaymentStatus');
                    print('   Total milestones: ${paymentMilestones.length}');
                    print('   Milestone types: ${paymentMilestones.map((m) => m['milestone_type']).toList()}');
                    
                    final isArrivalPaid = arrivalPaymentStatus == 'held_in_escrow' || 
                                         arrivalPaymentStatus == 'paid' ||
                                         arrivalPaymentStatus == 'released';
                    
                    if (!isArrivalPaid) {
                      // Arrival payment not completed yet
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            const Text(
                              'Waiting for customer to complete arrival payment (50%).',
                              style: TextStyle(color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Payment Status: ${arrivalPaymentStatus ?? 'Pending'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // Arrival payment completed - vendor can mark setup completed
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await _bookingService.markSetupCompleted(widget.bookingId);
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Setup marked as completed. Customer will be asked to confirm.')),
                            );
                            _loadBookingDetails();
                          }
                        },
                        icon: const Icon(Icons.build),
                        label: const Text('Mark Setup Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ] else if (milestoneStatus == 'setup_completed') ...[
                const Text(
                  'Waiting for customer to confirm setup and pay remaining amount.',
                  style: TextStyle(color: Colors.grey),
                ),
              ] else if (milestoneStatus == 'setup_confirmed') ...[
                // Customer confirmed setup - wait for final 30% payment before vendor can complete
                Builder(
                  builder: (context) {
                    final paymentMilestones = booking['payment_milestones'] as List<dynamic>? ?? [];
                    Map<String, dynamic>? completionMilestone;
                    try {
                      completionMilestone = paymentMilestones.firstWhere(
                        (m) => m['milestone_type'] == 'completion',
                      ) as Map<String, dynamic>?;
                    } catch (_) {
                      completionMilestone = null;
                    }

                    final completionPaymentStatus = completionMilestone != null
                        ? completionMilestone['status'] as String?
                        : null;

                    final isCompletionPaid = completionPaymentStatus == 'held_in_escrow' ||
                        completionPaymentStatus == 'paid' ||
                        completionPaymentStatus == 'released';

                    if (!isCompletionPaid) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            const Text(
                              'Waiting for customer to complete final payment (30%).',
                              style: TextStyle(color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Payment Status: ${completionPaymentStatus ?? 'Pending'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showStatusUpdateDialog,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark as Completed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showStatusUpdateDialog,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              
              // Cancel Booking Button (always available except for completed/cancelled)
              if (status != 'completed' && status != 'cancelled') ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelBookingDialog(),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Booking'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.length > 20 ? '${value.substring(0, 20)}...' : value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelBookingDialog() async {
    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('Cancel Booking?', maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this booking? This action will trigger a full refund to the customer.',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) {
      return; // User cancelled the first dialog
    }

    // Second confirmation dialog (double check)
    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('Final Confirmation', maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone. Are you absolutely sure you want to cancel this booking?',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              
              // Refund Policy Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Policy:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When you cancel a booking:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text('✓ Customer receives 100% refund of all payments made'),
                    Text('✓ All payment milestones will be refunded'),
                    Text('✓ Refund will be processed within 5-7 business days'),
                    Text('✓ Customer will be notified immediately'),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Vendor Penalties Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Penalties:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'First Cancellation:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('• Wallet freeze for 7 days'),
                    Text('• Ranking reduction for 30 days'),
                    SizedBox(height: 6),
                    Text(
                      'Second Cancellation:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('• All above penalties'),
                    Text('• Visibility reduction for 60 days'),
                    SizedBox(height: 6),
                    Text(
                      'Third+ Cancellation:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('• Account suspension (90 days) or permanent blacklisting'),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Other Consequences
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Other Consequences:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Booking will be permanently marked as cancelled'),
                    Text('• This action cannot be reversed'),
                    Text('• Your cancellation history will be recorded'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Go Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel Booking'),
          ),
        ],
      ),
    );

    if (secondConfirm != true) {
      return; // User cancelled the second dialog
    }

    // Proceed with cancellation
    if (!mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _bookingService.cancelBookingAsVendor(
        bookingId: widget.bookingId,
        reason: 'Cancelled by vendor',
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Booking cancelled successfully. Full refund issued to customer.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        // Reload booking details
        _loadBookingDetails();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to cancel booking. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
