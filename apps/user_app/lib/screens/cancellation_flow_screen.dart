import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/booking_service.dart';
import '../services/refund_service.dart';

class CancellationFlowScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingDetails;

  const CancellationFlowScreen({
    super.key,
    required this.bookingId,
    this.bookingDetails,
  });

  @override
  State<CancellationFlowScreen> createState() => _CancellationFlowScreenState();
}

class _CancellationFlowScreenState extends State<CancellationFlowScreen> {
  final BookingService _bookingService = BookingService(Supabase.instance.client);
  final RefundService _refundService = RefundService(Supabase.instance.client);
  
  RefundCalculation? _refundPreview;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _bookingInfo;

  @override
  void initState() {
    super.initState();
    _loadBookingAndRefundPreview();
  }

  Future<void> _loadBookingAndRefundPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get booking details
      final bookingResult = await Supabase.instance.client
          .from('bookings')
          .select('''
            *,
            services!inner(name, description),
            vendor_profiles!inner(business_name, category)
          ''')
          .eq('id', widget.bookingId)
          .single();

      _bookingInfo = Map<String, dynamic>.from(bookingResult);

      // Get refund preview
      final preview = await _bookingService.getRefundPreview(
        bookingId: widget.bookingId,
        isVendorCancellation: false,
      );

      setState(() {
        _refundPreview = preview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            if (_refundPreview != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Refundable: ₹${_refundPreview!.refundableAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Non-refundable: ₹${_refundPreview!.nonRefundableAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _refundPreview!.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _bookingService.cancelBookingWithRefund(
        bookingId: widget.bookingId,
        isVendorCancellation: false,
      );

      if (mounted) {
        if (result['success'] == true) {
          Navigator.of(context).pop(true); // Return success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Booking cancelled. Refund of ₹${result['refund_amount']?.toStringAsFixed(2) ?? '0.00'} will be processed.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cancellation failed: ${result['error']}'),
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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cancel Booking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cancel Booking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBookingAndRefundPreview,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final serviceName = _bookingInfo?['services']?['name'] ?? 'Service';
    final vendorName = _bookingInfo?['vendor_profiles']?['business_name'] ?? 'Vendor';
    final bookingDate = _bookingInfo?['booking_date'] ?? '';
    final amount = (_bookingInfo?['amount'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancel Booking'),
        backgroundColor: Colors.red.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Details Card
            Card(
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
                    _buildInfoRow(Icons.event, 'Service', serviceName),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.business, 'Vendor', vendorName),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.calendar_today, 'Date', bookingDate),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.currency_rupee,
                      'Total Amount',
                      '₹${amount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Refund Preview Card
            if (_refundPreview != null) ...[
              Card(
                color: _refundPreview!.refundableAmount > 0
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _refundPreview!.refundableAmount > 0
                                ? Icons.check_circle
                                : Icons.info,
                            color: _refundPreview!.refundableAmount > 0
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Refund Preview',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRefundRow(
                        'Refundable Amount',
                        '₹${_refundPreview!.refundableAmount.toStringAsFixed(2)}',
                        Colors.green,
                        true,
                      ),
                      const SizedBox(height: 8),
                      _buildRefundRow(
                        'Non-refundable Amount',
                        '₹${_refundPreview!.nonRefundableAmount.toStringAsFixed(2)}',
                        Colors.grey,
                        false,
                      ),
                      const SizedBox(height: 8),
                      _buildRefundRow(
                        'Refund Percentage',
                        '${_refundPreview!.refundPercentage.toStringAsFixed(1)}%',
                        Colors.blue,
                        false,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _refundPreview!.reason,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Warning Card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Once cancelled, this booking cannot be restored. Refund will be processed according to the policy.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isProcessing ? null : _confirmCancellation,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Cancel Booking',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildRefundRow(String label, String value, Color color, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 18 : 16,
          ),
        ),
      ],
    );
  }
}

