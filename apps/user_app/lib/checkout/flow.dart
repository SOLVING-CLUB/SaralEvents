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
        // Add item asynchronously without blocking navigation
        state.addItem(item).catchError((e) {
          print('Error adding item to cart: $e');
        });
        return CheckoutFlow(initialItem: item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the globally provided CheckoutState; all children can access it via
    // Provider/Consumer without re-wrapping here.
    final checkoutState = context.watch<CheckoutState>();
    
    // If cart is empty, show empty state
    if (checkoutState.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add items to your cart to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Navigator(
      key: _navKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (innerCtx) {
          return CartPage(
            onNext: () {
              try {
                debugPrint('🛒 CartPage: Next button pressed');
                
                // Ensure cart is not empty before proceeding
                final state = Provider.of<CheckoutState>(innerCtx, listen: false);
                debugPrint('🛒 CartPage: Cart has ${state.items.length} item(s)');
                
                if (state.items.isEmpty) {
                  debugPrint('⚠️ CartPage: Cart is empty, showing error');
                  ScaffoldMessenger.of(innerCtx).showSnackBar(
                    const SnackBar(content: Text('Your cart is empty. Please add items to continue.')),
                  );
                  return;
                }
                
                // Check if Navigator is ready
                final navState = _navKey.currentState;
                if (navState == null) {
                  debugPrint('❌ CartPage: Navigator key is null! Waiting for Navigator to initialize...');
                  // Wait a frame and try again
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final navState2 = _navKey.currentState;
                    if (navState2 == null) {
                      debugPrint('❌ CartPage: Navigator still null after waiting!');
                      if (innerCtx.mounted) {
                        ScaffoldMessenger.of(innerCtx).showSnackBar(
                          const SnackBar(content: Text('Navigation error. Please try again.')),
                        );
                      }
                      return;
                    }
                    debugPrint('✅ CartPage: Navigator ready after wait, navigating...');
                    _navigateToPaymentDetails(navState2, innerCtx);
                  });
                  return;
                }
                
                debugPrint('✅ CartPage: Navigator ready, navigating to PaymentDetailsPage...');
                _navigateToPaymentDetails(navState, innerCtx);
              } catch (e, stackTrace) {
                debugPrint('❌ CartPage: Exception in onNext: $e');
                debugPrint('❌ CartPage: Stack trace: $stackTrace');
                if (innerCtx.mounted) {
                  ScaffoldMessenger.of(innerCtx).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          );
        });
      },
    );
  }
  
  void _navigateToPaymentDetails(NavigatorState navState, BuildContext context) {
    try {
      navState.push(MaterialPageRoute(builder: (innerCtx2) {
                  debugPrint('✅ CartPage: PaymentDetailsPage route created');
                  return PaymentDetailsPage(
                  onChoosePayment: () {
                    _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx3) {
                      return PaymentMethodPage(onNext: () {
                        _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx4) {
                          return PaymentSummaryPage(onNext: () {
                            // After payment summary, go to payment method
                            _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx5) {
                              return PaymentMethodPage(onNext: () {
                                // After payment, pop all the way back
                                _navKey.currentState!..pop()..pop()..pop()..pop()..pop();
                              });
                            }));
                          });
                        }));
                      });
                    }));
                  },
                  onNext: () {
                    // Direct path: Payment Details → Payment Summary → Payment Method
                    _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx6) {
                      return PaymentSummaryPage(onNext: () {
                        _navKey.currentState!.push(MaterialPageRoute(builder: (innerCtx7) {
                          return PaymentMethodPage(onNext: () {
                            // After payment, pop all the way back
                            _navKey.currentState!..pop()..pop()..pop()..pop();
                          });
                        }));
                      });
                    }));
                  },
                );
      })).then((_) {
        debugPrint('✅ CartPage: Navigation to PaymentDetailsPage completed');
      }).catchError((error) {
        debugPrint('❌ CartPage: Navigation error: $error');
        debugPrint('❌ CartPage: Error stack: ${StackTrace.current}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigation error: ${error.toString()}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ CartPage: Exception in _navigateToPaymentDetails: $e');
      debugPrint('❌ CartPage: Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
  void initState() {
    super.initState();
    // Initialize cart immediately when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final state = Provider.of<CheckoutState>(context, listen: false);
        // Start a fresh cart for this draft-based checkout
        await state.clearCart();
        await state.addItem(widget.initialItem);
        state.setDraftId(widget.draftId);
        
        debugPrint('✅ CheckoutFlowWithDraft: Added item to cart: ${widget.initialItem.title}');
        debugPrint('   Cart now has ${state.items.length} item(s)');
        debugPrint('   Draft ID: ${widget.draftId}');
        debugPrint('   Booking Date: ${widget.bookingDate}');

        // Set event date from booking date if available
        final eventDate = widget.bookingDate ?? widget.initialItem.bookingDate;
        
        // Load billing details from draft if available, otherwise use booking date as event date
        if (widget.billingName != null &&
            widget.billingEmail != null &&
            widget.billingPhone != null) {
          state.saveBillingDetails(BillingDetails(
            name: widget.billingName!,
            email: widget.billingEmail!,
            phone: widget.billingPhone!,
            eventDate: widget.eventDate ?? eventDate, // Use provided eventDate or bookingDate
            messageToVendor: widget.messageToVendor,
          ));
        } else if (eventDate != null) {
          // If no billing details but we have a booking date, set event date
          // This will be used when user enters billing details
          debugPrint('   Setting event date from booking date: $eventDate');
          // Store event date in a temporary billing details if none exists
          final currentDetails = state.billingDetails;
          if (currentDetails != null) {
            state.saveBillingDetails(BillingDetails(
              name: currentDetails.name,
              email: currentDetails.email,
              phone: currentDetails.phone,
              eventDate: eventDate,
              messageToVendor: currentDetails.messageToVendor,
            ));
          }
        }
        _initialized = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fallback: ensure cart is initialized if initState didn't run
    if (!_initialized && mounted) {
      _initializeCart();
    }
  }

  Future<void> _initializeCart() async {
    if (_initialized) return;
    
    final state = Provider.of<CheckoutState>(context, listen: false);
    if (state.items.isEmpty || !state.items.any((item) => item.id == widget.initialItem.id)) {
      await state.clearCart();
      await state.addItem(widget.initialItem);
      state.setDraftId(widget.draftId);
      debugPrint('✅ CheckoutFlowWithDraft (didChangeDependencies): Added item to cart: ${widget.initialItem.title}');
      debugPrint('   Cart now has ${state.items.length} item(s)');
    }
    _initialized = true;
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

