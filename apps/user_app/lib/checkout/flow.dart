import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'checkout_state.dart';
import 'screens.dart';

class CheckoutFlow extends StatelessWidget {
  /// The checkout flow now relies on a global [CheckoutState] provided at app
  /// level. The [initialItem] and other arguments are kept for compatibility
  /// but are no longer used directly inside the flow; callers should populate
  /// the global cart before navigating here.
  final CartItem initialItem;
  final String? draftId;
  final DateTime? bookingDate;
  final TimeOfDay? bookingTime;
  final String? notes;
  
  CheckoutFlow({
    super.key, 
    required this.initialItem,
    this.draftId,
    this.bookingDate,
    this.bookingTime,
    this.notes,
  });

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  static Route<void> routeWithItem(CartItem item) {
    return MaterialPageRoute<void>(
      builder: (context) {
        // Add the item to the global cart and open the checkout flow
        final state = Provider.of<CheckoutState>(context, listen: false);
        state.addItem(item);
        return CheckoutFlow(initialItem: item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the globally provided CheckoutState; all children can access it via
    // Provider/Consumer without re-wrapping here.
    context.watch<CheckoutState>();
    return Navigator(
      key: _navKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (innerCtx) {
          return CartPage(
            onNext: () {
              _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx2) {
                return PaymentDetailsPage(
                  onChoosePayment: () {
                    _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx3) {
                      return PaymentMethodPage(onNext: () {
                        _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx4) {
                          return PaymentSummaryPage(onNext: () {
                            _navKey.currentState!..pop()..pop()..pop()..pop();
                          });
                        }));
                      });
                    }));
                  },
                  onNext: () {
                    _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx5) {
                      return PaymentSummaryPage(onNext: () {
                        _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx6) {
                          return PaymentMethodPage(onNext: () {
                            _navKey.currentState!..pop()..pop()..pop()..pop();
                          });
                        }));
                      });
                    }));
                  },
                );
              }));
            },
          );
        });
      },
    );
  }
}

/// Checkout flow with draft information for booking creation after payment
class CheckoutFlowWithDraft extends StatefulWidget {
  final CartItem initialItem;
  final String draftId;
  final DateTime? bookingDate;
  final TimeOfDay? bookingTime;
  final String? notes;
  final String? billingName;
  final String? billingEmail;
  final String? billingPhone;
  final DateTime? eventDate;
  final String? messageToVendor;

  const CheckoutFlowWithDraft({
    super.key,
    required this.initialItem,
    required this.draftId,
    this.bookingDate,
    this.bookingTime,
    this.notes,
    this.billingName,
    this.billingEmail,
    this.billingPhone,
    this.eventDate,
    this.messageToVendor,
  });

  @override
  State<CheckoutFlowWithDraft> createState() => _CheckoutFlowWithDraftState();
}

class _CheckoutFlowWithDraftState extends State<CheckoutFlowWithDraft> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = Provider.of<CheckoutState>(context, listen: false);
    // Start a fresh cart for this draft-based checkout
    state.clearCart();
    state.addItem(widget.initialItem);
    state.setDraftId(widget.draftId);

    // Load billing details from draft if available
    if (widget.billingName != null &&
        widget.billingEmail != null &&
        widget.billingPhone != null) {
      state.saveBillingDetails(BillingDetails(
        name: widget.billingName!,
        email: widget.billingEmail!,
        phone: widget.billingPhone!,
        eventDate: widget.eventDate,
        messageToVendor: widget.messageToVendor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutFlow(
      initialItem: widget.initialItem,
      draftId: widget.draftId,
      bookingDate: widget.bookingDate,
      bookingTime: widget.bookingTime,
      notes: widget.notes,
    );
  }
}

