import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/order_repository.dart';
import '../services/booking_draft_service.dart';
import 'order_details_screen.dart';
import 'cancellation_flow_screen.dart';
import '../core/utils/time_utils.dart';
import '../checkout/flow.dart';
import '../checkout/checkout_state.dart';
import '../core/cache/simple_cache.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final BookingService _bookingService;
  late final OrderRepository _orderRepo;
  late final BookingDraftService _draftService;
  late final TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _orders = [];
  // Kept for compatibility with existing draft-loading logic, even though
  // drafts are no longer shown as a separate tab in the UI.
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _bookingService = BookingService(Supabase.instance.client);
    _orderRepo = OrderRepository(Supabase.instance.client);
    _draftService = BookingDraftService(Supabase.instance.client);
    // Only two tabs now: Bookings and Payments (Drafts removed from UI)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadBookings();
    _loadOrders();
    _subscribeOrdersRealtime();
  }

  void _onTabChanged() {
    // Refresh bookings when switching to bookings tab
    if (_tabController.index == 0 && !_tabController.indexIsChanging) {
      _loadBookings(forceRefresh: false);
    }
  }

  Future<void> _loadBookings({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingService.getUserBookings(forceRefresh: forceRefresh);
      
      if (kDebugMode) {
        debugPrint('=== BOOKINGS LOADED ===');
        debugPrint('Total bookings returned: ${bookings.length}');
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        debugPrint('Current authenticated User ID: $currentUserId');
        
        if (bookings.isEmpty) {
          debugPrint('⚠️ WARNING: No bookings found!');
          debugPrint('Possible causes:');
          debugPrint('  1. User ID mismatch - Current: $currentUserId');
          debugPrint('  2. RLS policy blocking access');
          debugPrint('  3. No bookings exist for this user');
          
          // Show diagnostic dialog in debug mode
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDiagnosticDialog(currentUserId);
            });
          }
        } else {
          debugPrint('✅ Bookings found:');
          for (int i = 0; i < bookings.length; i++) {
            final booking = bookings[i];
            debugPrint('  [$i] ${booking['service_name']} - Status: ${booking['status']} - Amount: ${booking['amount']}');
            debugPrint('      Booking ID: ${booking['booking_id']}');
            debugPrint('      Date: ${booking['booking_date']}');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
          debugPrint('State updated: _bookings.length = ${_bookings.length}');
        });
      } else {
        debugPrint('⚠️ Widget not mounted, cannot update state');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error loading bookings: $e');
        debugPrint('Stack trace: $stackTrace');
      }
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

  Future<void> _loadDrafts() async {
    try {
      final drafts = await _draftService.getUserDrafts();
      if (mounted) {
        setState(() {
          _drafts = drafts;
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
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndCancelBooking(String bookingId) async {
    // Navigate to cancellation flow screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CancellationFlowScreen(bookingId: bookingId),
      ),
    );

    if (result == true) {
      // Booking was cancelled, reload bookings
      await _loadBookings();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadBookings(forceRefresh: true);
              _loadOrders();
            },
            tooltip: 'Refresh all',
          ),
        ],
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
    if (kDebugMode) {
      debugPrint('_buildBookingsTab: _isLoading=$_isLoading, _error=$_error, _bookings.length=${_bookings.length}');
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadBookings(forceRefresh: true), 
              child: const Text('Retry')
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Force clear cache and reload
                CacheManager.instance.invalidate('user:bookings');
                CacheManager.instance.invalidateByPrefix('user:bookings');
                _loadBookings(forceRefresh: true);
              },
              child: const Text('Force Refresh'),
            ),
          ],
        ),
      );
    }
    if (_bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadBookings(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _emptyState(context, 'No bookings yet', 'Your booking history will appear here'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadBookings(forceRefresh: true),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (kDebugMode) {
      debugPrint('Rendering ${_bookings.length} bookings in ListView');
    }
    return RefreshIndicator(
      onRefresh: () => _loadBookings(forceRefresh: true),
      child: _bookings.isEmpty 
        ? SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No bookings to display', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('_bookings.length = ${_bookings.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadBookings(forceRefresh: true),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (kDebugMode && index == 0) {
                debugPrint('Building first booking card: ${_bookings[index]}');
              }
              return _bookingCard(context, _bookings[index]);
            },
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

  Widget _buildDraftsTab(BuildContext context) {
    if (_drafts.isEmpty) {
      return _emptyState(context, 'No saved drafts', 'Your saved booking drafts will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadDrafts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _drafts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _draftCard(context, _drafts[index]),
      ),
    );
  }

  Widget _draftCard(BuildContext context, Map<String, dynamic> draft) {
    final service = draft['services'] as Map<String, dynamic>?;
    final vendor = draft['vendor_profiles'] as Map<String, dynamic>?;
    final serviceName = service?['name'] as String? ?? 'Unknown Service';
    final vendorName = vendor?['business_name'] as String? ?? 'Unknown Vendor';
    final amount = (draft['amount'] as num? ?? 0).toDouble();
    final bookingDate = draft['booking_date'] as String?;
    final bookingTime = draft['booking_time'] as String?;
    final notes = draft['notes'] as String?;
    final draftId = draft['id'] as String;
    final serviceId = draft['service_id'] as String;
    final vendorId = draft['vendor_id'] as String;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.drafts, size: 22, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(serviceName, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('DRAFT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(bookingTime),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.attach_money, size: 16),
              const SizedBox(width: 4),
              Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(notes)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _deleteDraft(draftId),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _continueBooking(
                    context,
                    draftId: draftId,
                    serviceId: serviceId,
                    vendorId: vendorId,
                    serviceName: serviceName,
                    vendorName: vendorName,
                    amount: amount,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDBB42),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue Booking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueBooking(
    BuildContext context, {
    required String draftId,
    required String serviceId,
    required String vendorId,
    required String serviceName,
    required String vendorName,
    required double amount,
  }) async {
    // Create cart item
    final item = CartItem(
      id: serviceId,
      title: serviceName,
      category: 'Service',
      price: amount,
      subtitle: vendorName,
    );

      // Navigate to checkout with draft
      final draft = await _draftService.getDraft(draftId);
      if (draft != null) {
        DateTime? bookingDate;
        if (draft['booking_date'] != null) {
          bookingDate = DateTime.parse(draft['booking_date'] as String);
        }
        
        final bookingTimeStr = draft['booking_time'] as String?;
        TimeOfDay? bookingTime;
        if (bookingTimeStr != null) {
          final parts = bookingTimeStr.split(':');
          bookingTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CheckoutFlowWithDraft(
                initialItem: item,
                draftId: draftId,
                bookingDate: bookingDate,
                bookingTime: bookingTime,
                notes: draft['notes'] as String?,
                billingName: draft['billing_name'] as String?,
                billingEmail: draft['billing_email'] as String?,
                billingPhone: draft['billing_phone'] as String?,
                eventDate: draft['event_date'] != null 
                    ? DateTime.parse(draft['event_date'] as String)
                    : null,
                messageToVendor: draft['message_to_vendor'] as String?,
              ),
            ),
          ).then((_) {
            // Reload drafts after returning
            _loadDrafts();
          });
        }
      }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this saved draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _draftService.deleteDraft(draftId);
      _loadDrafts();
    }
  }

  void _showDiagnosticDialog(String? currentUserId) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 Booking Diagnostic'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No bookings found. Diagnostic info:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Current User ID:\n${currentUserId ?? "NULL"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Expected User ID (from DB):\n62a201d9-ec45-4532-ace0-825152934451', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 16),
              if (currentUserId != '62a201d9-ec45-4532-ace0-825152934451')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚠️ USER ID MISMATCH!', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Your app is logged in with a different user ID than the bookings in the database.'),
                      SizedBox(height: 8),
                      Text('Solution: Run fix_user_id_mismatch.sql to update bookings to match your current user ID.'),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ℹ️ User IDs match, but no bookings found.'),
                      SizedBox(height: 8),
                      Text('Possible causes:'),
                      Text('• RLS policy blocking access'),
                      Text('• Bookings exist but with different status'),
                      Text('• Database connection issue'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Check the debug console for detailed logs.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
