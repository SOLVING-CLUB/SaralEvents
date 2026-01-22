import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/state/session.dart';
import '../../services/vendor_wallet_service.dart';
import '../vendor_setup/vendor_models.dart';
import '../orders/order_details_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  final VendorWalletService _walletService = VendorWalletService(Supabase.instance.client);
  late final TabController _tabController;
  bool _isLoading = true;
  VendorWallet? _wallet;
  List<WalletTransaction> _transactions = [];
  List<WithdrawalRequest> _withdrawals = [];
  List<Map<String, dynamic>> _pendingPayments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final vendor = context.read<AppSession>().vendorProfile;
      if (vendor == null || vendor.id == null) {
        throw Exception('Vendor profile missing. Please complete setup.');
      }
      final wallet = await _walletService.ensureWallet(vendor.id!);
      final txns = await _walletService.getTransactions(vendor.id!);
      final withdrawals = await _walletService.getWithdrawalRequests(vendor.id!);
      final pending = await _loadPendingPayments(vendor.id!);
      
      setState(() {
        _wallet = wallet;
        _transactions = txns;
        _withdrawals = withdrawals;
        _pendingPayments = pending;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingPayments(String vendorId) async {
    try {
      // Get bookings with payment milestones that are held in escrow but not yet released
      // Include all milestones that are paid/held_in_escrow OR released but wallet not credited
      final result = await Supabase.instance.client
          .from('bookings')
          .select('''
            id,
            amount,
            booking_date,
            status,
            services!inner(
              id,
              name,
              category_id,
              categories(name)
            ),
            payment_milestones!inner(
              id,
              milestone_type,
              percentage,
              amount,
              status,
              escrow_held_at,
              escrow_released_at,
              escrow_transactions(
                id,
                transaction_type,
                amount,
                commission_amount,
                vendor_amount,
                status,
                vendor_wallet_credited,
                admin_verified_at
              )
            )
          ''')
          .eq('vendor_id', vendorId)
          .inFilter('status', ['confirmed', 'vendor_arrived', 'arrival_confirmed', 'setup_completed', 'setup_confirmed', 'completed'])
          .order('booking_date', ascending: false);

      final List<Map<String, dynamic>> pending = [];
      for (final booking in result) {
        final milestones = booking['payment_milestones'] as List<dynamic>? ?? [];
        for (final milestone in milestones) {
          final milestoneStatus = milestone['status'] as String? ?? '';
          
          // Show milestone as "awaiting release" ONLY if:
          // 1. Status is 'held_in_escrow' or 'paid' (still in escrow, not yet released)
          // 2. Status is NOT 'released' (once released, it's in wallet balance)
          final isHeldInEscrow = milestoneStatus == 'held_in_escrow' || milestoneStatus == 'paid';
          
          // Once status is 'released', the amount is already in wallet balance
          // So we only show milestones that are still in escrow
          if (isHeldInEscrow && milestoneStatus != 'released') {
            pending.add({
              'booking_id': booking['id'],
              'booking_amount': booking['amount'],
              'booking_date': booking['booking_date'],
              'service_name': booking['services']?['name'] ?? 'Service',
              'category_name': booking['services']?['categories']?['name'] ?? 'Unknown',
              'milestone': milestone,
            });
          }
        }
      }
      return pending;
    } catch (e) {
      print('Error loading pending payments: $e');
      return [];
    }
  }

  double _availableBalance() {
    if (_wallet == null) return 0;
    return _wallet!.balance - _wallet!.pendingWithdrawal;
  }

  double _calculatePendingAmount() {
    double total = 0;
    for (final payment in _pendingPayments) {
      final milestone = payment['milestone'] as Map<String, dynamic>;
      final milestoneType = milestone['milestone_type'] as String? ?? '';
      final bookingAmount = (payment['booking_amount'] as num?)?.toDouble() ?? 0.0;
      
      if (milestoneType == 'completion') {
        // For completion milestone, vendor gets 20% of booking amount
        total += bookingAmount * 0.20;
      } else {
        // For advance (20%) and arrival (50%), vendor gets full milestone amount
        total += (milestone['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  Future<void> _openWithdrawSheet() async {
    final vendor = context.read<AppSession>().vendorProfile;
    if (vendor == null || vendor.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor profile missing. Complete setup first.')),
      );
      return;
    }
    
    if (vendor.accountHolderName == null ||
        vendor.accountNumber == null ||
        vendor.ifscCode == null ||
        vendor.bankName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill bank details in Profile before withdrawing.')),
      );
      return;
    }

    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Request Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Available: ₹${_availableBalance().toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text.trim()) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }
                    if (amount > _availableBalance()) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Amount exceeds available balance of ₹${_availableBalance().toStringAsFixed(2)}')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _requestWithdrawal(amount, vendor);
                  },
                  child: const Text('Submit Request'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Withdrawal requests are sent to Saral Events admin for approval. Funds are paid out after review.',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestWithdrawal(double amount, VendorProfile vendor) async {
    try {
      final bankSnapshot = {
        'account_holder_name': vendor.accountHolderName,
        'account_number': vendor.accountNumber,
        'ifsc_code': vendor.ifscCode,
        'bank_name': vendor.bankName,
        'branch_name': vendor.branchName,
      };
      final req = await _walletService.createWithdrawalRequest(
        vendorId: vendor.id!,
        amount: amount,
        bankSnapshot: bankSnapshot,
      );
      if (req == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create withdrawal request')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted to admin')),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Withdrawals'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error loading wallet', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _wallet == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Wallet not found'),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildTransactionsTab(),
                        _buildWithdrawalsTab(),
                      ],
                    ),
    );
  }

  Widget _buildOverviewTab() {
    final pendingAmount = _calculatePendingAmount();
    
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Summary Card
            _WalletSummaryCard(
              balance: _wallet!.balance,
              pending: _wallet!.pendingWithdrawal,
              total: _wallet!.totalEarned,
              available: _availableBalance(),
              pendingPayments: pendingAmount,
            ),
            
            const SizedBox(height: 16),
            
            // Withdraw Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _availableBalance() > 0 ? _openWithdrawSheet : null,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Request Withdrawal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Pending Payments Section
            if (_pendingPayments.isNotEmpty) ...[
              Text(
                'Pending Payments (Awaiting Admin Verification)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._pendingPayments.map((payment) => _PendingPaymentCard(
                payment: payment,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailsScreen(bookingId: payment['booking_id']),
                    ),
                  );
                },
              )),
              const SizedBox(height: 24),
            ],
            
            // Payment Structure Info
            _PaymentStructureCard(),
            
            const SizedBox(height: 24),
            
            // Cancellation Policies
            _CancellationPoliciesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment transactions will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TransactionCard(tx: _transactions[index]),
      ),
    );
  }

  Widget _buildWithdrawalsTab() {
    if (_withdrawals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No withdrawal requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Your withdrawal requests will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _WithdrawalCard(w: _withdrawals[index]),
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  final double balance;
  final double pending;
  final double total;
  final double available;
  final double pendingPayments;

  const _WalletSummaryCard({
    required this.balance,
    required this.pending,
    required this.total,
    required this.available,
    required this.pendingPayments,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet Balance',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₹${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Available',
                    value: '₹${available.toStringAsFixed(2)}',
                    color: Colors.white,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
                Expanded(
                  child: _SummaryItem(
                    label: 'Pending',
                    value: '₹${pending.toStringAsFixed(2)}',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Awaiting Release',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${pendingPayments.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onTap;

  const _PendingPaymentCard({
    required this.payment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final milestone = payment['milestone'] as Map<String, dynamic>;
    final milestoneType = milestone['milestone_type'] as String? ?? '';
    final escrowTransactions = milestone['escrow_transactions'] as List<dynamic>? ?? [];
    final bookingAmount = (payment['booking_amount'] as num?)?.toDouble() ?? 0.0;
    
    // Calculate display amount
    double amount = 0.0;
    int percentage = 0;
    
    if (milestoneType == 'completion') {
      // For completion, show vendor amount (20% of total), not gross (30%)
      final et = escrowTransactions.firstWhere(
        (et) => (et['transaction_type'] == 'release' || et['transaction_type'] == 'commission_deduct') &&
                et['status'] == 'completed',
        orElse: () => null,
      );
      if (et != null && et['vendor_amount'] != null) {
        amount = (et['vendor_amount'] as num).toDouble();
        percentage = 20; // Vendor gets 20%
      } else {
        // If not yet released, calculate 20% of booking amount
        amount = bookingAmount * 0.20;
        percentage = 20;
      }
    } else {
      // For advance (20%) and arrival (50%), show full amount
      amount = (milestone['amount'] as num?)?.toDouble() ?? 0.0;
      percentage = milestone['percentage'] as int? ?? 0;
    }
    
    final serviceName = payment['service_name'] as String? ?? 'Service';
    final bookingDate = payment['booking_date'] as String?;

    String milestoneLabel = '';
    IconData milestoneIcon = Icons.payment;
    
    switch (milestoneType) {
      case 'advance':
        milestoneLabel = 'Advance Payment';
        milestoneIcon = Icons.shopping_cart;
        break;
      case 'arrival':
        milestoneLabel = 'Arrival Payment';
        milestoneIcon = Icons.location_on;
        break;
      case 'completion':
        milestoneLabel = 'Completion Payment';
        milestoneIcon = Icons.check_circle;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(milestoneIcon, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestoneLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bookingDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy').format(DateTime.parse(bookingDate)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (milestoneType == 'completion') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '10% commission',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[700],
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentStructureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Payment Structure',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PaymentMilestoneItem(
              percentage: 20,
              label: 'Advance Payment',
              description: 'Paid at booking',
              icon: Icons.shopping_cart,
            ),
            const SizedBox(height: 12),
            _PaymentMilestoneItem(
              percentage: 50,
              label: 'Arrival Payment',
              description: 'Paid when vendor arrives (customer confirmation required)',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 12),
            _PaymentMilestoneItem(
              percentage: 30,
              label: 'Completion Payment',
              description: 'Paid after setup completion (customer confirmation required)',
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Important: Completion Payment Commission',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For the 30% completion payment, 10% goes to Saral Events as commission and 20% is credited to your wallet. The 10% commission is not shown in your "awaiting release" amount.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All payments are held in escrow until admin verification. Payment gateway charges are deducted before crediting your wallet.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMilestoneItem extends StatelessWidget {
  final int percentage;
  final String label;
  final String description;
  final IconData icon;

  const _PaymentMilestoneItem({
    required this.percentage,
    required this.label,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CancellationPoliciesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Cancellation & Refund Policies',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CategoryPolicyItem(
              category: 'Food & Catering',
              policy: 'More than 7 days: 100% refund\n3-7 days: 50% refund\nLess than 72 hours: No refund',
              icon: Icons.restaurant,
            ),
            const SizedBox(height: 12),
            _CategoryPolicyItem(
              category: 'Venues',
              policy: 'More than 30 days: 75% refund\n15-30 days: 50% refund\n7-15 days: 25% refund\nLess than 7 days: No refund',
              icon: Icons.business,
            ),
            const SizedBox(height: 12),
            _CategoryPolicyItem(
              category: 'DJs, Musicians & Live Performers',
              policy: 'More than 7 days: 75% refund\n3-7 days: 50% refund\nLess than 72 hours: No refund',
              icon: Icons.music_note,
            ),
            const SizedBox(height: 12),
            _CategoryPolicyItem(
              category: 'Decorators & Event Essentials',
              policy: 'More than 48 hours: 75% refund\n24-48 hours: 50% refund\nLess than 24 hours: No refund',
              icon: Icons.celebration,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, size: 20, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vendor Cancellation: 100% refund to customer. Wallet freeze and penalties apply.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPolicyItem extends StatelessWidget {
  final String category;
  final String policy;
  final IconData icon;

  const _CategoryPolicyItem({
    required this.category,
    required this.policy,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  policy,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final WalletTransaction tx;

  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.txnType == 'credit';
    final color = isCredit ? Colors.green : Colors.red;
    
    String sourceLabel = tx.source;
    IconData sourceIcon = Icons.payment;
    
    switch (tx.source) {
      case 'milestone_release':
        sourceLabel = 'Milestone Release';
        sourceIcon = Icons.check_circle;
        break;
      case 'withdrawal':
        sourceLabel = 'Withdrawal';
        sourceIcon = Icons.account_balance_wallet_outlined;
        break;
      case 'refund':
        sourceLabel = 'Refund';
        sourceIcon = Icons.refresh;
        break;
      case 'adjustment':
        sourceLabel = 'Adjustment';
        sourceIcon = Icons.tune;
        break;
      case 'admin_adjustment':
        sourceLabel = 'Admin Adjustment';
        sourceIcon = Icons.admin_panel_settings;
        break;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(sourceIcon, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        tx.txnType.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(tx.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                Text(
                  'Balance: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final WithdrawalRequest w;

  const _WithdrawalCard({required this.w});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(w.status);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${w.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(w.requestedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Text(
                    w.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (w.processedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Processed: ${DateFormat('MMM dd, yyyy • hh:mm a').format(w.processedAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (w.rejectionReason != null && w.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w.rejectionReason!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (w.bankSnapshot != null) ...[
              const SizedBox(height: 12),
              Divider(),
              const SizedBox(height: 8),
              Text(
                'Bank Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${w.bankSnapshot!['account_holder_name'] ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${w.bankSnapshot!['bank_name'] ?? 'N/A'} • ${w.bankSnapshot!['account_number']?.toString().substring(w.bankSnapshot!['account_number'].toString().length - 4) ?? '****'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
