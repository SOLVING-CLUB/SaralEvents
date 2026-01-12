import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/refund_service.dart';

class RefundDetailsScreen extends StatefulWidget {
  final String bookingId;

  const RefundDetailsScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<RefundDetailsScreen> createState() => _RefundDetailsScreenState();
}

class _RefundDetailsScreenState extends State<RefundDetailsScreen> {
  final RefundService _refundService = RefundService(Supabase.instance.client);
  
  Map<String, dynamic>? _refundDetails;
  List<Map<String, dynamic>> _refundMilestones = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefundDetails();
  }

  Future<void> _loadRefundDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get refund details
      final refundDetails = await _refundService.getRefundDetails(widget.bookingId);
      
      if (refundDetails != null) {
        // Get refund milestones
        final milestonesResult = await Supabase.instance.client
            .from('refund_milestones')
            .select('''
              *,
              payment_milestones!inner(milestone_type, percentage, amount)
            ''')
            .eq('refund_id', refundDetails['id']);

        setState(() {
          _refundDetails = refundDetails;
          _refundMilestones = List<Map<String, dynamic>>.from(milestonesResult);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No refund found for this booking';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.pending;
      case 'failed':
      case 'rejected':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Refund Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _refundDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Refund Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error ?? 'No refund details available',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRefundDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _refundDetails!['status'] as String;
    final refundAmount = (_refundDetails!['refund_amount'] as num).toDouble();
    final nonRefundableAmount = (_refundDetails!['non_refundable_amount'] as num).toDouble();
    final refundPercentage = (_refundDetails!['refund_percentage'] as num).toDouble();
    final reason = _refundDetails!['reason'] as String;
    final cancelledBy = _refundDetails!['cancelled_by'] as String;
    final createdAt = _refundDetails!['created_at'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Details'),
        backgroundColor: Colors.green.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _getStatusColor(status).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Refund Status',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Refund Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildAmountRow(
                      'Refundable Amount',
                      '₹${refundAmount.toStringAsFixed(2)}',
                      Colors.green,
                      true,
                    ),
                    const Divider(),
                    _buildAmountRow(
                      'Non-refundable Amount',
                      '₹${nonRefundableAmount.toStringAsFixed(2)}',
                      Colors.grey,
                      false,
                    ),
                    const Divider(),
                    _buildAmountRow(
                      'Refund Percentage',
                      '${refundPercentage.toStringAsFixed(1)}%',
                      Colors.blue,
                      false,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Cancelled By', cancelledBy == 'customer' ? 'You' : 'Vendor'),
                    const SizedBox(height: 12),
                    _buildDetailRow('Reason', reason),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Requested On',
                      DateTime.parse(createdAt).toString().split('.')[0],
                    ),
                  ],
                ),
              ),
            ),

            // Refund Milestones
            if (_refundMilestones.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund Breakdown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ..._refundMilestones.map((milestone) {
                        final pm = milestone['payment_milestones'] as Map<String, dynamic>;
                        final milestoneType = pm['milestone_type'] as String;
                        final originalAmount = (pm['amount'] as num).toDouble();
                        final refundAmount = (milestone['refund_amount'] as num).toDouble();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      milestoneType.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Original: ₹${originalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${refundAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Support Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Help?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact support for refund inquiries',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to support screen
                        Navigator.pushNamed(context, '/support');
                      },
                      child: const Text('Contact Support'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, Color color, bool isBold) {
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
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
}

