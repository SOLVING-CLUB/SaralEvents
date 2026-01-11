import 'package:supabase_flutter/supabase_flutter.dart';

class VendorWallet {
  final String id;
  final String vendorId;
  final double balance;
  final double pendingWithdrawal;
  final double totalEarned;

  VendorWallet({
    required this.id,
    required this.vendorId,
    required this.balance,
    required this.pendingWithdrawal,
    required this.totalEarned,
  });

  factory VendorWallet.fromMap(Map<String, dynamic> map) {
    return VendorWallet(
      id: map['id'].toString(),
      vendorId: map['vendor_id'].toString(),
      balance: (map['balance'] as num).toDouble(),
      pendingWithdrawal: (map['pending_withdrawal'] as num).toDouble(),
      totalEarned: (map['total_earned'] as num).toDouble(),
    );
  }
}

class WalletTransaction {
  final String id;
  final String vendorId;
  final String txnType;
  final String source;
  final double amount;
  final double balanceAfter;
  final String? bookingId;
  final String? milestoneId;
  final String? escrowTransactionId;
  final String? notes;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.vendorId,
    required this.txnType,
    required this.source,
    required this.amount,
    required this.balanceAfter,
    this.bookingId,
    this.milestoneId,
    this.escrowTransactionId,
    this.notes,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'].toString(),
      vendorId: map['vendor_id'].toString(),
      txnType: map['txn_type'].toString(),
      source: map['source'].toString(),
      amount: (map['amount'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      bookingId: map['booking_id']?.toString(),
      milestoneId: map['milestone_id']?.toString(),
      escrowTransactionId: map['escrow_transaction_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class WithdrawalRequest {
  final String id;
  final String vendorId;
  final String walletId;
  final double amount;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? rejectionReason;
  final Map<String, dynamic>? bankSnapshot;

  WithdrawalRequest({
    required this.id,
    required this.vendorId,
    required this.walletId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.rejectionReason,
    this.bankSnapshot,
  });

  factory WithdrawalRequest.fromMap(Map<String, dynamic> map) {
    return WithdrawalRequest(
      id: map['id'].toString(),
      vendorId: map['vendor_id'].toString(),
      walletId: map['wallet_id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      status: map['status'].toString(),
      requestedAt: DateTime.parse(map['requested_at']),
      processedAt: map['processed_at'] != null ? DateTime.parse(map['processed_at']) : null,
      rejectionReason: map['rejection_reason']?.toString(),
      bankSnapshot: map['bank_snapshot'] as Map<String, dynamic>?,
    );
  }
}

/// Vendor wallet service for balance, transactions, and withdrawal requests.
class VendorWalletService {
  final SupabaseClient _supabase;

  VendorWalletService(this._supabase);

  Future<VendorWallet?> getWallet(String vendorId) async {
    try {
      final res = await _supabase
          .from('vendor_wallets')
          .select('*')
          .eq('vendor_id', vendorId)
          .maybeSingle();

      if (res == null) return null;
      return VendorWallet.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  /// Create wallet if missing and return it.
  Future<VendorWallet?> ensureWallet(String vendorId) async {
    final existing = await getWallet(vendorId);
    if (existing != null) return existing;

    try {
      final inserted = await _supabase
          .from('vendor_wallets')
          .insert({'vendor_id': vendorId})
          .select()
          .maybeSingle();
      if (inserted == null) return null;
      return VendorWallet.fromMap(Map<String, dynamic>.from(inserted));
    } catch (e) {
      return null;
    }
  }

  Future<List<WalletTransaction>> getTransactions(String vendorId, {int limit = 50}) async {
    try {
      final res = await _supabase
          .from('wallet_transactions')
          .select('*')
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((row) => WalletTransaction.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Credit wallet after admin verification of a milestone release.
  Future<bool> creditFromMilestone({
    required String vendorId,
    required double amount,
    String? bookingId,
    String? milestoneId,
    String? escrowTransactionId,
    String notes = 'Milestone released',
  }) async {
    final wallet = await ensureWallet(vendorId);
    if (wallet == null) return false;

    final newBalance = wallet.balance + amount;
    final newTotal = wallet.totalEarned + amount;

    try {
      await _supabase.from('vendor_wallets').update({
        'balance': newBalance,
        'total_earned': newTotal,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', wallet.id);

      await _supabase.from('wallet_transactions').insert({
        'wallet_id': wallet.id,
        'vendor_id': vendorId,
        'txn_type': 'credit',
        'source': 'milestone_release',
        'amount': amount,
        'balance_after': newBalance,
        'booking_id': bookingId,
        'milestone_id': milestoneId,
        'escrow_transaction_id': escrowTransactionId,
        'notes': notes,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  double _availableBalance(VendorWallet wallet) =>
      wallet.balance - wallet.pendingWithdrawal;

  /// Create a withdrawal request (sent to admin for approval).
  Future<WithdrawalRequest?> createWithdrawalRequest({
    required String vendorId,
    required double amount,
    required Map<String, dynamic> bankSnapshot,
  }) async {
    final wallet = await ensureWallet(vendorId);
    if (wallet == null) return null;

    // available = balance - pending_withdrawal
    final available = _availableBalance(wallet);
    if (amount <= 0 || amount > available) {
      throw Exception('Invalid amount. Available for withdrawal: $available');
    }

    final pending = wallet.pendingWithdrawal + amount;
    try {
      await _supabase.from('vendor_wallets').update({
        'pending_withdrawal': pending,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', wallet.id);

      final inserted = await _supabase.from('withdrawal_requests').insert({
        'vendor_id': vendorId,
        'wallet_id': wallet.id,
        'amount': amount,
        'status': 'pending',
        'bank_snapshot': bankSnapshot,
      }).select().maybeSingle();

      if (inserted == null) return null;
      return WithdrawalRequest.fromMap(Map<String, dynamic>.from(inserted));
    } catch (e) {
      return null;
    }
  }

  /// Fetch withdrawal requests for vendor
  Future<List<WithdrawalRequest>> getWithdrawalRequests(String vendorId) async {
    try {
      final res = await _supabase
          .from('withdrawal_requests')
          .select('*')
          .eq('vendor_id', vendorId)
          .order('requested_at', ascending: false);

      return (res as List<dynamic>)
          .map((row) => WithdrawalRequest.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

