import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'checkout_state.dart';
import 'widgets.dart';
import '../services/payment_service.dart';
import '../services/booking_draft_service.dart';

// Shared button style
ButtonStyle _primaryBtn(BuildContext context) => ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFFFDBB42),
  foregroundColor: Colors.black87,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

class CartPage extends StatelessWidget {
  final VoidCallback onNext;
  const CartPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutState>();
    final items = state.items;
    final savedItems = state.savedItems;
    final installments = state.installmentBreakdown;
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          InstallmentCard(installments: installments, total: state.totalPrice),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Active cart items
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No items in cart')),
                  )
                else
                  ...List.generate(
                    items.length,
                    (i) => _cartTile(context, items[i], i),
                  ),

                // Saved for later section
                if (savedItems.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Saved for later',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    savedItems.length,
                    (i) => _savedTile(context, savedItems[i], i),
                  ),
                ],
              ],
            ),
          ),
          _userDetailsSummary(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(onPressed: onNext, style: _primaryBtn(context), child: const Text('Next')),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cartTile(BuildContext context, CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.subtitle ?? item.category),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    final state = context.read<CheckoutState>();
                    state.saveItemForLater(index);
                  },
                  child: const Text(
                    'Save for later',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove from cart',
                  onPressed: () {
                    final state = context.read<CheckoutState>();
                    state.removeItemAt(index);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tile for saved-for-later items
  Widget _savedTile(BuildContext context, CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.subtitle ?? item.category),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${item.price.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    final state = context.read<CheckoutState>();
                    state.moveSavedItemToCart(index);
                  },
                  child: const Text(
                    'Move to cart',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove',
                  onPressed: () {
                    final state = context.read<CheckoutState>();
                    state.removeSavedItemAt(index);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _userDetailsSummary() {
    return Consumer<CheckoutState>(builder: (context, state, _) {
      final details = state.billingDetails;
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                details == null
                    ? 'No billing details yet'
                    : '${details.name} • ${details.phone}\n${details.email}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('Total: ₹${state.totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    });
  }
}

class PaymentDetailsPage extends StatelessWidget {
  final VoidCallback onChoosePayment;
  final VoidCallback onNext;
  PaymentDetailsPage({super.key, required this.onChoosePayment, required this.onNext});

  final GlobalKey<BillingFormState> _billingFormKey = GlobalKey<BillingFormState>();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InstallmentCard(installments: state.installmentBreakdown, total: state.totalPrice),
          const SizedBox(height: 8),
          BillingForm(
            key: _billingFormKey,
            initial: state.billingDetails,
            onSave: (d) async {
              final checkoutState = context.read<CheckoutState>();
              checkoutState.saveBillingDetails(d);
              
              // Create or update draft when billing details are saved
              if (checkoutState.items.isNotEmpty) {
                final item = checkoutState.items.first;
                final draftService = BookingDraftService(Supabase.instance.client);
                
                // Get service details to find vendor_id
                try {
                  final serviceResult = await Supabase.instance.client
                      .from('services')
                      .select('vendor_id')
                      .eq('id', item.id)
                      .maybeSingle();
                  
                  if (serviceResult != null) {
                    final draftId = await draftService.saveDraftFromCheckout(
                      serviceId: item.id,
                      vendorId: serviceResult['vendor_id'] as String,
                      amount: item.price,
                      billingName: d.name,
                      billingEmail: d.email,
                      billingPhone: d.phone,
                      eventDate: d.eventDate,
                      messageToVendor: d.messageToVendor,
                    );
                    
                    if (draftId != null) {
                      checkoutState.setDraftId(draftId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Details saved and draft created'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Details saved')),
                        );
                      }
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Details saved')),
                      );
                    }
                  }
                } catch (e) {
                  print('Error creating draft from billing details: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Details saved')),
                    );
                  }
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Details saved')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final formState = _billingFormKey.currentState;
                    final ok = formState?.validateAndSave() ?? false;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required details before choosing payment method')),
                      );
                      return;
                    }
                    onChoosePayment();
                  },
                  style: _primaryBtn(context),
                  child: const Text('Choose Payment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final formState = _billingFormKey.currentState;
                    final ok = formState?.validateAndSave() ?? false;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required details before continuing')),
                      );
                      return;
                    }
                    onNext();
                  },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PaymentSummaryPage extends StatelessWidget {
  final VoidCallback onNext;
  const PaymentSummaryPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutState>();
    final d = state.billingDetails;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (d == null) const Text('No details saved') else ...[
                  _buildDetailRow('Name', d.name),
                  _buildDetailRow('Email', d.email),
                  _buildDetailRow('Phone', d.phone),
                  if (d.eventDate != null) 
                    _buildDetailRow(
                      'Event', 
                      '${d.eventDate!.day}/${d.eventDate!.month}/${d.eventDate!.year}'
                    ),
                  if (d.messageToVendor != null)
                    _buildDetailRow(
                      'Message', 
                      d.messageToVendor!,
                      maxLines: 3,
                    ),
                ],
                const SizedBox(height: 12),
                InstallmentCard(installments: state.installmentBreakdown, total: state.totalPrice, margin: EdgeInsets.zero),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: onNext, style: _primaryBtn(context), child: const Text('Next'))),
          ]),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodPage extends StatefulWidget {
  final VoidCallback onNext;
  const PaymentMethodPage({super.key, required this.onNext});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  SelectedPaymentMethod? _method;
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;
  bool _acceptedPolicies = false;

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Method')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InstallmentCard(installments: state.installmentBreakdown, total: state.totalPrice),
          PaymentMethodSelector(
            initial: state.paymentMethod,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 12),
          // Cancellation & refund policies block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancellation & Refund Policy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Refunds for cancellations depend on the service type and how many days before the event you cancel.\n'
                  '• In general, cancelling closer to the event date results in a lower or no refund.\n'
                  '• Platform fees and applicable taxes are non‑refundable.\n'
                  '• Detailed refund will be shown at the time of cancellation in the bookings section.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _acceptedPolicies,
                  onChanged: (v) => setState(() => _acceptedPolicies = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text(
                    'I have read and agree to the cancellation and refund policy for this order.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  final state = context.read<CheckoutState>();

                  // Require explicit acceptance of policies before payment
                  if (!_acceptedPolicies) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please agree to the cancellation and refund policy before paying.'),
                      ),
                    );
                    return;
                  }

                  // Hard guard: do not allow payment if billing details are missing
                  if (state.billingDetails == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill your billing details before making a payment.'),
                      ),
                    );
                    Navigator.of(context).pop(); // Go back to previous step
                    return;
                  }

                  final m = _method ?? SelectedPaymentMethod(type: PaymentMethodType.upi);

                  // Basic validation for payment methods
                  if (m.type == PaymentMethodType.upi) {
                    if (m.upiId == null || m.upiId!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid UPI ID.')),
                      );
                      return;
                    }
                  } else if (m.type == PaymentMethodType.card) {
                    if ((m.cardNumber == null || m.cardNumber!.trim().length < 8) ||
                        (m.cardName == null || m.cardName!.trim().isEmpty) ||
                        (m.cardExpiry == null || m.cardExpiry!.trim().isEmpty) ||
                        (m.cardCvv == null || m.cardCvv!.trim().length < 3)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all card details correctly.')),
                      );
                      return;
                    }
                  } else if (m.type == PaymentMethodType.netBanking) {
                    if (m.bankName == null || m.bankName!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a bank for net banking.')),
                      );
                      return;
                    }
                  }

                  state.savePaymentMethod(m);

                  // Process payment using the comprehensive payment service
                  setState(() => _isProcessing = true);
                  
                  try {
                    await _paymentService.processPayment(
                      context: context,
                      checkoutState: state,
                      draftId: state.draftId, // Pass draft ID for booking creation
                      onSuccess: () {
                        setState(() => _isProcessing = false);
                        // Payment success is handled by PaymentResultScreen
                        // Don't call widget.onNext() here as it will be called from PaymentResultScreen's onContinue
                      },
                      onFailure: () {
                        setState(() => _isProcessing = false);
                        // Stay on current screen for retry
                      },
                    );
                  } catch (e) {
                    setState(() => _isProcessing = false);
                    if (kDebugMode) {
                      debugPrint('Payment processing error: $e');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment failed: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                },
                style: _primaryBtn(context),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : const Text('Pay Now'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}


