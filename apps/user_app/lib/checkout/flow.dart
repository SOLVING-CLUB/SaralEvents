import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'checkout_state.dart';
import 'screens.dart';

class CheckoutFlow extends StatelessWidget {
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
      builder: (_) => ChangeNotifierProvider(
        create: (_) {
          final state = CheckoutState();
          state.addItem(item);
          return state;
        },
        child: CheckoutFlow(initialItem: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = context.watch<CheckoutState>();
    return ChangeNotifierProvider.value(
      value: checkoutState,
      child: Navigator(
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
      ),
    );
  }
}

/// Checkout flow with draft information for booking creation after payment
class CheckoutFlowWithDraft extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = CheckoutState();
        state.addItem(initialItem);
        state.setDraftId(draftId);
        
        // Load billing details from draft if available
        if (billingName != null && billingEmail != null && billingPhone != null) {
          state.saveBillingDetails(BillingDetails(
            name: billingName!,
            email: billingEmail!,
            phone: billingPhone!,
            eventDate: eventDate,
            messageToVendor: messageToVendor,
          ));
        }
        
        return state;
      },
      child: CheckoutFlow(
        initialItem: initialItem,
        draftId: draftId,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        notes: notes,
      ),
    );
  }
}

