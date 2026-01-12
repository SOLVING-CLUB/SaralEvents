import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bookings/booking_service.dart';

  Future<String?> _getVendorId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      final result = await Supabase.instance.client
          .from('vendor_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      return result?['id'];
    } catch (e) {
      return null;
    }
  }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with TickerProviderStateMixin {
  late final BookingService _bookingService;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all';
  late TabController _tabController;

  // 'confirmed' = payment received, service not yet completed (show as "Pending" to vendor)
  // 'completed' = service completed
  // 'cancelled' = booking cancelled
  final List<String> _statuses = ['all', 'pending', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _bookingService = BookingService(Supabase.instance.client);
    _tabController = TabController(length: _statuses.length, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.getVendorBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
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

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedStatus == 'all') {
      return _bookings;
    }
    // For vendor view: 'pending' filter should also include 'confirmed' status
    // (confirmed = payment received but service not yet completed)
    if (_selectedStatus == 'pending') {
      return _bookings.where((booking) => 
        booking['status'] == 'pending' || booking['status'] == 'confirmed'
      ).toList();
    }
    return _bookings.where((booking) => booking['status'] == _selectedStatus).toList();
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus, [String? notes]) async {
    try {
      final success = await _bookingService.updateBookingStatus(bookingId, newStatus, notes);
      
      if (success) {
        await _loadBookings();
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

  void _showStatusUpdateDialog(Map<String, dynamic> booking) {
    final currentStatus = booking['status'] as String;
    final notesController = TextEditingController();

    // Only allow status updates for pending/confirmed bookings (not completed/cancelled)
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
                booking['id'],
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'confirmed': // Confirmed = paid but not yet completed, show as pending to vendor
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get display status for vendor view
  // 'confirmed' should show as 'PENDING' to vendor (service not yet completed)
  String _getDisplayStatus(String status) {
    if (status.toLowerCase() == 'confirmed') {
      return 'PENDING';
    }
    return status.toUpperCase();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No date';
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return 'No time';
    try {
      // Handle both "HH:mm:ss" and "HH:mm" formats
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          onTap: (index) {
            setState(() {
              _selectedStatus = _statuses[index];
            });
          },
          tabs: _statuses.map((status) {
            final count = status == 'all' 
                ? _bookings.length 
                : _bookings.where((b) => b['status'] == status).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status.toUpperCase()),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading orders...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
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
              'Error loading orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedStatus == 'all' ? '' : _selectedStatus} orders yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders will appear here when customers book your services',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredBookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildBookingCard(_filteredBookings[index]),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final amount = booking['amount'] as num? ?? 0;
    final bookingDate = booking['booking_date'] as String?;
    final bookingTime = booking['booking_time'] as String?;
    final notes = booking['notes'] as String?;
    final customerName = booking['customer_name'] as String? ?? 'Unknown Customer';
    final serviceName = booking['service_name'] as String? ?? 'Unknown Service';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getDisplayStatus(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Service information - prominently displayed
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.room_service,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviceName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Amount',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const Divider(height: 24),
            
            // Customer information
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Event date and time - stacked vertically for better visibility
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Event Date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      _formatDate(bookingDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  if (bookingTime != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Time',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        _formatTime(bookingTime),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            _buildActionButtons(booking, status),
          ],
        ),
      ),
    );
  }

  int _calculateDaysBeforeEvent(String? bookingDate) {
    if (bookingDate == null) return 0;
    try {
      final eventDate = DateTime.parse(bookingDate);
      final today = DateTime.now();
      final difference = eventDate.difference(today);
      return difference.inDays;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic> _getRefundPolicy(String vendorCategory, int daysBeforeEvent) {
    final category = vendorCategory.toLowerCase();
    
    // Food & Catering Services
    if (category.contains('catering') || category.contains('food') || category.contains('kitchen')) {
      if (daysBeforeEvent > 7) {
        return {
          'refund_percentage': 100.0,
          'policy': 'More than 7 days before event: 100% refund',
        };
      } else if (daysBeforeEvent >= 3) {
        return {
          'refund_percentage': 50.0,
          'policy': '3-7 days before event: 50% refund',
        };
      } else {
        return {
          'refund_percentage': 0.0,
          'policy': 'Less than 72 hours before event: No refund',
        };
      }
    }
    
    // Venues
    if (category.contains('venue') || category.contains('hall') || 
        category.contains('banquet') || category.contains('farmhouse') || 
        category.contains('garden')) {
      if (daysBeforeEvent > 30) {
        return {
          'refund_percentage': 75.0,
          'policy': 'More than 30 days before event: 75% refund',
        };
      } else if (daysBeforeEvent >= 15) {
        return {
          'refund_percentage': 50.0,
          'policy': '15-30 days before event: 50% refund',
        };
      } else if (daysBeforeEvent >= 7) {
        return {
          'refund_percentage': 25.0,
          'policy': '7-15 days before event: 25% refund',
        };
      } else {
        return {
          'refund_percentage': 0.0,
          'policy': 'Less than 7 days before event: No refund',
        };
      }
    }
    
    // DJs, Musicians & Live Performers
    if (category.contains('dj') || category.contains('music') || 
        category.contains('band') || category.contains('singer') || 
        category.contains('performer') || category.contains('anchor')) {
      if (daysBeforeEvent > 7) {
        return {
          'refund_percentage': 75.0,
          'policy': 'More than 7 days before event: 75% refund',
        };
      } else if (daysBeforeEvent >= 3) {
        return {
          'refund_percentage': 50.0,
          'policy': '3-7 days before event: 50% refund',
        };
      } else {
        return {
          'refund_percentage': 0.0,
          'policy': 'Less than 72 hours before event: No refund',
        };
      }
    }
    
    // Decorators & Event Essentials
    if (category.contains('decor') || category.contains('decoration') || 
        category.contains('flower') || category.contains('lighting') || 
        category.contains('stage') || category.contains('tent') || 
        category.contains('chair') || category.contains('sound') || 
        category.contains('generator') || category.contains('essential')) {
      if (daysBeforeEvent >= 2) {
        return {
          'refund_percentage': 75.0,
          'policy': 'More than 48 hours before event: 75% refund',
        };
      } else if (daysBeforeEvent >= 1) {
        return {
          'refund_percentage': 50.0,
          'policy': '24-48 hours before event: 50% refund',
        };
      } else {
        return {
          'refund_percentage': 0.0,
          'policy': 'Less than 24 hours before event: No refund',
        };
      }
    }
    
    // Default
    return {
      'refund_percentage': 0.0,
      'policy': 'Category not eligible for refund',
    };
  }

  Future<void> _showCancellationDialog(Map<String, dynamic> booking) async {
    final bookingId = booking['id'] as String;
    final bookingDate = booking['booking_date'] as String?;
    final amount = (booking['amount'] as num?)?.toDouble() ?? 0.0;
    final serviceName = booking['service_name'] as String? ?? 'Service';
    
    // Get vendor category
    String vendorCategory = 'Other';
    try {
      final vendorId = await _getVendorId();
      if (vendorId != null) {
        final vendorResult = await Supabase.instance.client
            .from('vendor_profiles')
            .select('category')
            .eq('id', vendorId)
            .maybeSingle();
        vendorCategory = vendorResult?['category'] ?? 'Other';
      }
    } catch (e) {
      print('Error fetching vendor category: $e');
    }
    
    // Get total amount paid so far from payment milestones
    double totalPaid = 0.0;
    try {
      final milestonesResult = await Supabase.instance.client
          .from('payment_milestones')
          .select('amount, status')
          .eq('booking_id', bookingId)
          .inFilter('status', ['held_in_escrow', 'released']);
      
      for (final milestone in milestonesResult) {
        totalPaid += (milestone['amount'] as num).toDouble();
      }
    } catch (e) {
      print('Error fetching payment milestones: $e');
      // Fallback to advance amount if milestones not found
      totalPaid = amount * 0.20;
    }
    
    final daysBeforeEvent = _calculateDaysBeforeEvent(bookingDate);
    final refundPolicy = _getRefundPolicy(vendorCategory, daysBeforeEvent);
    final advanceAmount = amount * 0.20; // 20% advance
    final customerRefundAmount = advanceAmount * (refundPolicy['refund_percentage'] as double) / 100;
    
    // Vendor cancellation always gives 100% refund of all payments made
    final vendorRefundAmount = totalPaid > 0 ? totalPaid : amount;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Cancel Booking?')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service: $serviceName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Booking Date: ${bookingDate ?? 'N/A'}',
                style: TextStyle(color: Colors.grey[700]),
              ),
              Text(
                'Days before event: $daysBeforeEvent days',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Booking Amount: ₹${amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
              if (totalPaid > 0)
                Text(
                  'Amount Paid So Far: ₹${totalPaid.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700]),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vendor Cancellation Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer will receive 100% refund of all payments',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refund Amount: ₹${vendorRefundAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Cancellation Policy (Reference)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      refundPolicy['policy'] as String,
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If customer cancelled: ₹${customerRefundAmount.toStringAsFixed(2)} refund',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vendor penalties may apply for cancellations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Proceed with cancellation
      final result = await _bookingService.cancelBookingAsVendor(
        bookingId: booking['id'],
        reason: 'Vendor cancellation',
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Booking cancelled. Full refund issued to customer.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          await _loadBookings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to cancel booking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildActionButtons(Map<String, dynamic> booking, String status) {
    // Use a Row with Expanded buttons for consistent alignment and spacing
    final List<Widget> primaryButtons = [];
    
    // Handle both 'pending' and 'confirmed' status (confirmed = paid but not completed)
    if (status == 'pending' || status == 'confirmed') {
      // Show Cancel button - bookings are auto-accepted per new policy
      primaryButtons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCancellationDialog(booking),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel Booking'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
      );
    } else if (status == 'completed') {
      // No actions needed for completed bookings
      return const SizedBox.shrink();
    } else if (status == 'cancelled') {
      // No actions for cancelled bookings
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primaryButtons.isNotEmpty) ...[
          Row(children: primaryButtons),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _showStatusUpdateDialog(booking),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Update Status'),
          ),
        ),
      ],
    );
  }
}


