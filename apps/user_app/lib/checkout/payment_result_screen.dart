import 'package:flutter/material.dart';
/// Screen to display payment result (success or failure)
class PaymentResultScreen extends StatelessWidget {
  final bool isSuccess;
  final String? paymentId;
  final String? errorMessage;
  final Map<String, dynamic>? responseData;
  final double? amount;
  final int? itemsCount;
  final String? bookingId;
  final String? orderId;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  const PaymentResultScreen({
    super.key,
    required this.isSuccess,
    this.paymentId,
    this.errorMessage,
    this.responseData,
    this.amount,
    this.itemsCount,
    this.bookingId,
    this.orderId,
    this.onRetry,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSuccess ? 'Payment Successful' : 'Payment Failed'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                size: 60,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status Text
            Text(
              isSuccess ? 'Payment Successful!' : 'Payment Failed',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Description
            Text(
              isSuccess 
                ? 'Your payment has been processed successfully. You will receive a confirmation email shortly.'
                : errorMessage ?? 'Something went wrong with your payment. Please try again.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            
            if (isSuccess && paymentId != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Payment ID', paymentId!),
                    if (amount != null)
                      _buildDetailRow('Amount', '₹${amount!.toStringAsFixed(0)}'),
                    if (itemsCount != null)
                      _buildDetailRow('Items', '$itemsCount item(s)'),
                    if (responseData?['timestamp'] != null)
                      _buildDetailRow('Time', _formatTimestamp(responseData!['timestamp'])),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Action Buttons
            if (isSuccess) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDBB42),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDBB42),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Retry Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
