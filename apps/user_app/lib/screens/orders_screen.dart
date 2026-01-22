import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/order_repository.dart';
import '../services/booking_draft_service.dart';
import 'order_details_screen.dart';
import 'order_status_screen.dart';
import 'cancellation_flow_screen.dart';
import '../core/utils/time_utils.dart';
import '../checkout/booking_flow.dart';
import '../checkout/checkout_state.dart';
import 'package:provider/provider.dart';
import '../core/cache/simple_cache.dart';
import '../core/config/razorpay_config.dart';

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
  RealtimeChannel? _bookingsChannel;

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
    _subscribeBookingsRealtime();
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
          // debugPrint('⚠️ WARNING: No bookings found!');
          // debugPrint('Possible causes:');
          // debugPrint('  1. User ID mismatch - Current: $currentUserId');
          // debugPrint('  2. RLS policy blocking access');
          // debugPrint('  3. No bookings exist for this user');
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

  void _subscribeBookingsRealtime() {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      _bookingsChannel?.unsubscribe();
      _bookingsChannel = client
          .channel('bookings_user_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
            callback: (payload) {
              // Reload bookings when vendor updates status (accepts, marks arrived, etc.)
              _loadBookings();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ordersChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
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
    final theme = Theme.of(context);
    switch (status.toLowerCase()) {
      case 'pending':
        return theme.colorScheme.primary;
      case 'confirmed':
        return theme.colorScheme.primary;
      case 'completed':
        return theme.colorScheme.primary;
      case 'cancelled':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        backgroundColor: Theme.of(context).cardColor,
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

  bool _isTestPayment(Map<String, dynamic> order) {
    // Check if Razorpay key is test mode
    final isTestKey = RazorpayConfig.keyId.startsWith('rzp_test_');
    
    // Check gateway_order_id for test indicators
    final gatewayOrderId = (order['gateway_order_id'] as String? ?? '').toLowerCase();
    final hasTestInId = gatewayOrderId.contains('test');
    
    // Check payment_id for test indicators
    final paymentId = (order['payment_id'] as String? ?? '').toLowerCase();
    final hasTestInPaymentId = paymentId.contains('test');
    
    return isTestKey || hasTestInId || hasTestInPaymentId;
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
          final isTest = _isTestPayment(o);
          
          return Card(
            child: InkWell(
              onTap: () {
                final id = (o['id'] ?? '').toString();
                if (id.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: id)),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: _getStatusColor(status), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rel.isEmpty ? createdPretty : '$createdPretty  •  $rel',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(), 
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError, 
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTest ? Colors.orange.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isTest ? Colors.orange.shade300 : Colors.green.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isTest ? 'TEST' : 'LIVE',
                                style: TextStyle(
                                  color: isTest ? Colors.orange.shade800 : Colors.green.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
    final bookingId = booking['booking_id'] as String?;

    return Card(
      child: InkWell(
        onTap: bookingId != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OrderStatusScreen(bookingId: bookingId),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
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
                    child: Text(
                      status.toUpperCase(), 
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError, 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Cancel Booking'),
                  ),
                ]),
            ],
          ),
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
                Icon(
                  Icons.drafts, 
                  size: 22, 
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(serviceName, style: Theme.of(context).textTheme.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DRAFT', 
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
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
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
      locationLink: null, // Will be set from draft if available
    );

      // Navigate to checkout with draft
      final draft = await _draftService.getDraft(draftId);
      if (draft != null) {
        DateTime? bookingDate;
        if (draft['booking_date'] != null) {
          bookingDate = DateTime.parse(draft['booking_date'] as String);
        }
        
        // booking_time is currently not used in cart item; keep parsing only when needed.

        if (mounted) {
          // Add item to cart (do NOT clear existing cart items)
          final checkoutState = Provider.of<CheckoutState>(context, listen: false);
          // Update item with location link from draft if available
          final itemWithLocation = CartItem(
            id: item.id,
            title: item.title,
            category: item.category,
            price: item.price,
            subtitle: item.subtitle,
            bookingDate: bookingDate,
            locationLink: draft['location_link'] as String?,
          );
          await checkoutState.addItem(itemWithLocation);
          // NOTE: CheckoutState currently supports only a single draftId; setting it here
          // would overwrite any previous draft reference when multiple services are added.
          
          // Load billing details if available
          if (draft['billing_name'] != null && 
              draft['billing_email'] != null && 
              draft['billing_phone'] != null) {
            checkoutState.saveBillingDetails(BillingDetails(
              name: draft['billing_name'] as String,
              email: draft['billing_email'] as String,
              phone: draft['billing_phone'] as String,
              eventDate: draft['event_date'] != null 
                  ? DateTime.parse(draft['event_date'] as String)
                  : bookingDate,
              messageToVendor: draft['message_to_vendor'] as String?,
            ));
          }
          
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BookingFlow(),
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
