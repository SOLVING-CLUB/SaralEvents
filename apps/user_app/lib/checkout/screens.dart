import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'checkout_state.dart';
import 'widgets.dart';
import '../services/payment_service.dart';

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
    final installments = state.installmentBreakdown;
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          InstallmentCard(installments: installments, total: state.totalPrice),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) => _cartTile(context, items[i]),
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

  Widget _cartTile(BuildContext context, CartItem item) {
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
        trailing: Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            onSave: (d) {
              context.read<CheckoutState>().saveBillingDetails(d);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details saved')));
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
                  Text('Name: ${d.name}') ,
                  Text('Email: ${d.email}') ,
                  Text('Phone: ${d.phone}') ,
                  if (d.eventDate != null) Text('Event: ${d.eventDate!.day}/${d.eventDate!.month}/${d.eventDate!.year}') ,
                  if (d.messageToVendor != null)
                    Text(
                      'Message: ${d.messageToVendor}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () async {
                  final state = context.read<CheckoutState>();

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

                  final m = _method ?? SelectedPaymentMethod(type: PaymentMethodType.cash);

                  // Basic validation for non-cash payment methods
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

                  if (m.type == PaymentMethodType.cash) {
                    widget.onNext();
                    return;
                  }

                  // Process payment using the comprehensive payment service
                  setState(() => _isProcessing = true);
                  
                  try {
                    await _paymentService.processPayment(
                      context: context,
                      checkoutState: state,
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


