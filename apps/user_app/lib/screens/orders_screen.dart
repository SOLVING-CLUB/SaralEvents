import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/order_repository.dart';
import 'order_details_screen.dart';
import '../core/utils/time_utils.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final BookingService _bookingService;
  late final OrderRepository _orderRepo;
  late final TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _bookingService = BookingService(Supabase.instance.client);
    _orderRepo = OrderRepository(Supabase.instance.client);
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
    _loadOrders();
    _subscribeOrdersRealtime();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.getUserBookings();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _orderRepo.getUserOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _subscribeOrdersRealtime() {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      _ordersChannel?.unsubscribe();
      _ordersChannel = client
          .channel('orders_user_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
            callback: (payload) {
              _loadOrders();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndCancelBooking(String bookingId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (shouldCancel != true) return;

    try {
      final success = await _bookingService.cancelBooking(bookingId);
      if (success) {
        await _loadBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bookings'),
            Tab(text: 'Payments'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingsTab(context),
          _buildOrdersTab(context),
        ],
      ),
    );
  }

  Widget _buildBookingsTab(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadBookings, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_bookings.isEmpty) {
      return _emptyState(context, 'No bookings yet', 'Your booking history will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _bookingCard(context, _bookings[index]),
      ),
    );
  }

  Widget _buildOrdersTab(BuildContext context) {
    if (_orders.isEmpty) {
      return _emptyState(context, 'No payments yet', 'Your payment history will appear here');
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadOrders();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final o = _orders[index];
          final status = (o['status'] as String? ?? 'pending').toLowerCase();
          final total = (o['total_amount'] as num? ?? 0).toDouble();
          final createdAt = o['created_at'] as String?;
          final createdPretty = TimeUtils.formatDateTime(createdAt);
          final rel = TimeUtils.relativeTime(createdAt);
          return Card(
            child: ListTile(
              leading: Icon(Icons.payment, color: _getStatusColor(status)),
              title: Text('₹${total.toStringAsFixed(2)}'),
              subtitle: Text(rel.isEmpty ? createdPretty : '$createdPretty  •  $rel'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              onTap: () {
                final id = (o['id'] ?? '').toString();
                if (id.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: id)),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _bookingCard(BuildContext context, Map<String, dynamic> booking) {
    final serviceName = booking['service_name'] as String? ?? 'Unknown Service';
    final vendorName = booking['vendor_name'] as String? ?? 'Unknown Vendor';
    final status = booking['status'] as String? ?? 'unknown';
    final amount = booking['amount'] as num? ?? 0;
    final bookingDate = booking['booking_date'] as String?;
    final bookingTime = booking['booking_time'] as String?;
    final notes = booking['notes'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(serviceName, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(12)),
                  child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [const Icon(Icons.business, size: 16), const SizedBox(width: 4), Text(vendorName)]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 4),
              Text(bookingDate ?? 'No date'),
              if (bookingTime != null) ...[
                const SizedBox(width: 16), const Icon(Icons.access_time, size: 16), const SizedBox(width: 4), Text(bookingTime),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.attach_money, size: 16), const SizedBox(width: 4), Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.note, size: 16), const SizedBox(width: 4), Expanded(child: Text(notes))]),
            ],
            const SizedBox(height: 12),
            if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'confirmed')
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => _confirmAndCancelBooking(booking['booking_id']),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel Booking'),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
