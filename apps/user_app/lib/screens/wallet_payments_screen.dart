import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class WalletPaymentsScreen extends StatefulWidget {
  const WalletPaymentsScreen({super.key});

  @override
  State<WalletPaymentsScreen> createState() => _WalletPaymentsScreenState();
}

class _WalletPaymentsScreenState extends State<WalletPaymentsScreen> {
  bool _loading = true;
  double? _walletBalance;
  List<_WalletTransaction> _transactions = const <_WalletTransaction>[];
  List<_PaymentMethod> _paymentMethods = const <_PaymentMethod>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (!mounted) return;
    setState(() => _loading = true);

    double? balance;
    List<_WalletTransaction> transactions = <_WalletTransaction>[];
    List<_PaymentMethod> methods = <_PaymentMethod>[];

    if (userId == null) {
      balance = 0;
    } else {
      try {
        final balanceRow = await client
            .from('wallet_balances')
            .select('balance')
            .eq('user_id', userId)
            .maybeSingle();
        balance = (balanceRow?['balance'] as num?)?.toDouble();
      } catch (e) {
        debugPrint('Wallet balance fetch skipped: $e');
      }

      try {
        final rows = await client
            .from('wallet_transactions')
            .select('id, amount, status, created_at, service_name, vendor_name, meta')
            .eq('user_id', userId)
            .order('created_at', ascending: false) as List<dynamic>;
        transactions = rows
            .map((dynamic row) => _WalletTransaction.fromMap(Map<String, dynamic>.from(row as Map<String, dynamic>)))
            .toList();
      } catch (e) {
        debugPrint('Wallet transactions fetch skipped: $e');
        transactions = _WalletTransaction.sample();
      }

      try {
        final rows = await client
            .from('payment_methods')
            .select('id, type, last4, is_default, label')
            .eq('user_id', userId)
            .order('is_default', ascending: false) as List<dynamic>;
        methods = rows
            .map((dynamic row) => _PaymentMethod.fromMap(Map<String, dynamic>.from(row as Map<String, dynamic>)))
            .toList();
      } catch (e) {
        debugPrint('Payment methods fetch skipped: $e');
        methods = _PaymentMethod.sample();
      }
    }

    if (!mounted) return;
    setState(() {
      _walletBalance = balance;
      _transactions = transactions;
      _paymentMethods = methods;
      _loading = false;
    });
  }

  void _showAddMethodSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String? selectedType = 'upi';
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add payment method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  ],
                  onChanged: (value) => selectedType = value,
                  decoration: const InputDecoration(labelText: 'Method type'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: selectedType == 'card' ? 'Card number (last 4 digits)' : 'Identifier',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Payment method saved. Integration pending.')),
                      );
                    },
                    child: const Text('Save method'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = _walletBalance != null ? NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(_walletBalance) : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet & Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMethodSheet,
        icon: const Icon(Icons.add_card),
        label: const Text('Add Method'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for cart button
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: const Color(0xFF121212),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallet Balance', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            balanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Top-up flow coming soon.')),
                                ),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add funds'),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Transfer flow coming soon.')),
                                ),
                                child: const Text('Transfer out'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Payment methods', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_paymentMethods.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No saved methods yet. Add UPI IDs, cards or wallets to speed up checkout.'),
                      ),
                    )
                  else
                    ..._paymentMethods.map((method) => Card(
                          child: ListTile(
                            leading: Icon(method.icon, color: Colors.blueGrey),
                            title: Text(method.displayLabel),
                            subtitle: Text(method.subtitle),
                            trailing: method.isDefault
                                ? const Chip(label: Text('Default'), backgroundColor: Color(0xFFE8F5E9))
                                : TextButton(
                                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Default method update coming soon.')),
                                    ),
                                    child: const Text('Make default'),
                                  ),
                          ),
                        )),
                  const SizedBox(height: 24),
                  Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No transactions yet. Once you book services, they will appear here with payment status.'),
                      ),
                    )
                  else
                    ..._transactions.map((transaction) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: transaction.statusColor.withOpacity(0.15),
                              child: Icon(transaction.statusIcon, color: transaction.statusColor),
                            ),
                            title: Text(transaction.serviceName ?? 'Service'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${transaction.vendorName ?? 'Vendor'} • ${transaction.formattedDate}'),
                                Text(transaction.statusLabel, style: TextStyle(color: transaction.statusColor)),
                              ],
                            ),
                            trailing: Text(transaction.formattedAmount, style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => _showTransactionDetails(transaction),
                          ),
                        )),
                  const SizedBox(height: 24),
                  const Text(
                    'Refunds & verification',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Need help with a payment? Tap a transaction to request a refund or verify its status. Our support team works with the payment gateway to resolve issues promptly.',
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  void _showTransactionDetails(_WalletTransaction transaction) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.serviceName ?? 'Service', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(transaction.vendorName ?? 'Vendor', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount'),
                  Text(transaction.formattedAmount, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status'),
                  Chip(
                    label: Text(transaction.statusLabel),
                    backgroundColor: transaction.statusColor.withOpacity(0.12),
                    labelStyle: TextStyle(color: transaction.statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Date'),
                  Text(transaction.formattedDate),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Refund flow coming soon.')),);
                },
                child: const Text('Request refund'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Verification with payment gateway is being implemented.')),
                  );
                },
                child: const Text('Verify with gateway'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletTransaction {
  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String? serviceName;
  final String? vendorName;
  final Map<String, dynamic>? meta;

  _WalletTransaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.serviceName,
    this.vendorName,
    this.meta,
  });

  factory _WalletTransaction.fromMap(Map<String, dynamic> map) {
    return _WalletTransaction(
      id: map['id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      serviceName: map['service_name'] as String?,
      vendorName: map['vendor_name'] as String?,
      meta: map['meta'] is Map<String, dynamic> ? map['meta'] as Map<String, dynamic> : null,
    );
  }

  static List<_WalletTransaction> sample() {
    final now = DateTime.now();
    return [
      _WalletTransaction(
        id: 'sample-1',
        amount: 12999,
        status: 'paid',
        createdAt: now.subtract(const Duration(days: 3)),
        serviceName: 'Wedding Photography',
        vendorName: 'Lens Craft Studios',
      ),
      _WalletTransaction(
        id: 'sample-2',
        amount: 5500,
        status: 'pending',
        createdAt: now.subtract(const Duration(days: 8)),
        serviceName: 'Catering Advance',
        vendorName: 'Spice Route Caterers',
      ),
      _WalletTransaction(
        id: 'sample-3',
        amount: 2499,
        status: 'refunded',
        createdAt: now.subtract(const Duration(days: 15)),
        serviceName: 'Décor Booking',
        vendorName: 'Bloom & Co Events',
      ),
    ];
  }

  String get formattedAmount => NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount / 100);

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toLocal());

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'refunded':
        return 'Refunded';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'refunded':
        return Icons.refresh;
      case 'failed':
        return Icons.error;
      default:
        return Icons.schedule;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green.shade600;
      case 'refunded':
        return Colors.blue.shade600;
      case 'failed':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade700;
    }
  }
}

class _PaymentMethod {
  final String id;
  final String type;
  final String? last4;
  final bool isDefault;
  final String? label;

  _PaymentMethod({
    required this.id,
    required this.type,
    this.last4,
    this.isDefault = false,
    this.label,
  });

  factory _PaymentMethod.fromMap(Map<String, dynamic> map) {
    return _PaymentMethod(
      id: map['id'].toString(),
      type: (map['type'] as String?) ?? 'upi',
      last4: map['last4'] as String?,
      isDefault: (map['is_default'] as bool?) ?? false,
      label: map['label'] as String?,
    );
  }

  static List<_PaymentMethod> sample() {
    return [
      _PaymentMethod(id: 'sample-upi', type: 'upi', label: 'Primary UPI', last4: 'saral@upi', isDefault: true),
      _PaymentMethod(id: 'sample-card', type: 'card', label: 'Visa ending 1234', last4: '1234'),
    ];
  }

  IconData get icon {
    switch (type) {
      case 'card':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.phone_iphone;
    }
  }

  String get displayLabel {
    if (label != null && label!.isNotEmpty) {
      return label!;
    }
    switch (type) {
      case 'card':
        return 'Card ending ${last4 ?? 'XXXX'}';
      case 'wallet':
        return 'Wallet';
      default:
        return 'UPI';
    }
  }

  String get subtitle {
    switch (type) {
      case 'card':
        return 'Automatic billing enabled';
      case 'wallet':
        return 'Linked digital wallet';
      default:
        return 'Instant UPI payments';
    }
  }
}
