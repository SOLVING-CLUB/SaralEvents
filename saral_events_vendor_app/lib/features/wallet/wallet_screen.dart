import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/state/session.dart';
import '../../services/vendor_wallet_service.dart';
import '../vendor_setup/vendor_models.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final VendorWalletService _walletService = VendorWalletService(Supabase.instance.client);
  bool _isLoading = true;
  VendorWallet? _wallet;
  List<WalletTransaction> _transactions = [];
  List<WithdrawalRequest> _withdrawals = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      setState(() {
        _wallet = wallet;
        _transactions = txns;
        _withdrawals = withdrawals;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _availableBalance() {
    if (_wallet == null) return 0;
    return _wallet!.balance - _wallet!.pendingWithdrawal;
  }

  Future<void> _openWithdrawSheet() async {
    final vendor = context.read<AppSession>().vendorProfile;
    if (vendor == null || vendor.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor profile missing. Complete setup first.')),
      );
      return;
    }
    // Require bank fields
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
                    Navigator.pop(ctx);
                    await _requestWithdrawal(amount, vendor);
                  },
                  child: const Text('Submit Request'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Withdrawal requests are sent to Saral Events admin for approval. Funds are paid out after review.',
                style: TextStyle(color: Colors.grey[700]),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
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
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _WalletSummary(
                            balance: _wallet!.balance,
                            pending: _wallet!.pendingWithdrawal,
                            total: _wallet!.totalEarned,
                            available: _availableBalance(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _availableBalance() > 0 ? _openWithdrawSheet : null,
                              icon: const Icon(Icons.account_balance_wallet_outlined),
                              label: const Text('Request Withdrawal'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (_transactions.isEmpty)
                            const Text('No transactions yet')
                          else
                            ..._transactions.map((t) => _TransactionTile(tx: t)),
                          const SizedBox(height: 24),
                          const Text('Withdrawal Requests', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (_withdrawals.isEmpty)
                            const Text('No withdrawal requests')
                          else
                            ..._withdrawals.map((w) => _WithdrawalTile(w: w)),
                        ],
                      ),
                    ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  final double balance;
  final double pending;
  final double total;
  final double available;
  const _WalletSummary({
    required this.balance,
    required this.pending,
    required this.total,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('₹${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Available: ₹${available.toStringAsFixed(2)}'),
          Text('Pending withdrawal: ₹${pending.toStringAsFixed(2)}'),
          Text('Total earned: ₹${total.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.txnType == 'credit';
    final color = isCredit ? Colors.green : Colors.red;
    return ListTile(
      leading: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color),
      title: Text('${tx.source} • ₹${tx.amount.toStringAsFixed(2)}'),
      subtitle: Text('${tx.txnType.toUpperCase()} • Balance: ₹${tx.balanceAfter.toStringAsFixed(2)}'),
      trailing: Text(
        '${tx.createdAt}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  final WithdrawalRequest w;
  const _WithdrawalTile({required this.w});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text('₹${w.amount.toStringAsFixed(2)}'),
      subtitle: Text('Status: ${w.status}'),
      trailing: Text(
        '${w.requestedAt}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }
}

