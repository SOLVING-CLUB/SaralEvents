import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'checkout_state.dart';
import 'widgets.dart';
import '../services/payment_service.dart';
import '../services/billing_details_service.dart';

/// Clean, linear booking flow: Cart → Payment Details → Summary → Payment Gateway
class BookingFlow extends StatefulWidget {
  const BookingFlow({super.key});

  // GlobalKey for Navigator to ensure proper navigation within the flow
  // Using static so it can be accessed from child screens
  // Made non-final so it can be updated per instance
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<BookingFlow> createState() => _BookingFlowState();
}

class _BookingFlowState extends State<BookingFlow> {
  // Instance-level Navigator key to prevent issues with static key reuse
  late final GlobalKey<NavigatorState> _navigatorKey;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 BookingFlow: initState called');
    // Create a new key for this instance to avoid conflicts
    _navigatorKey = GlobalKey<NavigatorState>();
    // Also update the static key so child screens can access it
    // But use the instance key for the Navigator itself
    BookingFlow.navigatorKey = _navigatorKey;
  }

  @override
  void dispose() {
    debugPrint('🔄 BookingFlow: dispose called - THIS SHOULD NOT HAPPEN DURING PAYMENT FLOW!');
    debugPrint('🔄 BookingFlow: Stack trace: ${StackTrace.current}');
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🔄 BookingFlow: didChangeDependencies called');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 BookingFlow: build() called');
    
    // Ensure Navigator is built and key is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_navigatorKey.currentState != null) {
        debugPrint('✅ BookingFlow Navigator ready');
      } else {
        debugPrint('⚠️ BookingFlow Navigator key not attached');
      }
    });
    
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        debugPrint('🔄 BookingFlow: Generating route: ${settings.name ?? "initial"}');
        return MaterialPageRoute(
          builder: (_) => const CartScreen(),
          settings: settings,
        );
      },
      observers: [
        _NavigatorObserver(),
      ],
    );
  }
}

/// Step 1: Cart Screen
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checkoutState = context.watch<CheckoutState>();

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
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // If this is the first route in BookingFlow Navigator, pop the entire BookingFlow
        // to return to the homepage. Otherwise, pop within the BookingFlow Navigator.
        final navigator = BookingFlow.navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return false; // Prevent default back behavior
        } else {
          // This is the first route, so pop the entire BookingFlow to return to homepage
          Navigator.of(context, rootNavigator: true).pop();
          return false; // Prevent default back behavior
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cart'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // If this is the first route in BookingFlow Navigator, pop the entire BookingFlow
              // to return to the homepage. Otherwise, pop within the BookingFlow Navigator.
              final navigator = BookingFlow.navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.pop();
              } else {
                // This is the first route, so pop the entire BookingFlow to return to homepage
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...checkoutState.items.asMap().entries.map((entry) {
                    return _CartItemTile(
                      item: entry.value,
                      index: entry.key,
                    );
                  }),
                  const SizedBox(height: 16),
                  _TotalSummary(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () async {
                  debugPrint('🛒 CartScreen: "Proceed to Payment Details" button pressed');
                  
                  // Validate cart is not empty
                  final checkoutState = context.read<CheckoutState>();
                  if (checkoutState.items.isEmpty) {
                    debugPrint('❌ CartScreen: Cart is empty!');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cart is empty. Please add items to cart.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  // Always use the BookingFlow Navigator key
                  final navigator = BookingFlow.navigatorKey.currentState;
                  if (navigator == null) {
                    debugPrint('❌ CartScreen: BookingFlow Navigator not ready! Cannot navigate.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Navigation not ready. Please try again.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  
                  // Always navigate to PaymentDetailsScreen - it handles both saved details and new form
                  debugPrint('✅ CartScreen: Navigating to PaymentDetailsScreen');
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Proceed to Payment Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;

  const _CartItemTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(item.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.subtitle != null) Text(item.subtitle!),
            if (item.bookingDate != null || item.bookingTime != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  if (item.bookingDate != null)
                    Chip(
                      label: Text('Date: ${_formatDate(item.bookingDate!)}'),
                      padding: EdgeInsets.zero,
                    ),
                  if (item.bookingTime != null)
                    Chip(
                      label: Text('Time: ${_formatTime(item.bookingTime!)}'),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${item.price.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                textAlign: TextAlign.end,
              ),
              InkWell(
                onTap: () {
                  context.read<CheckoutState>().removeItemAt(index);
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _TotalSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final checkoutState = context.watch<CheckoutState>();
    final items = checkoutState.items;
    final total = checkoutState.totalPrice;
    
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show breakdown if multiple services
            if (items.length > 1) ...[
              Text(
                'Payment Breakdown',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 24),
            ],
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (items.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${items.length} service${items.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Step 2: Payment Details Screen
class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _formKey = GlobalKey<BillingFormState>();
  final _billingService = BillingDetailsService(Supabase.instance.client);
  List<Map<String, dynamic>> _savedDetails = [];
  String? _selectedSavedId;
  bool _showNewForm = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📝 PaymentDetailsScreen: initState called');
    // Defer loading to avoid issues during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSavedDetails();
      }
    });
  }

  Future<void> _loadSavedDetails() async {
    debugPrint('📝 PaymentDetailsScreen: Loading saved billing details...');
    try {
      final saved = await _billingService.getSavedBillingDetails();
      debugPrint('📝 PaymentDetailsScreen: Loaded ${saved.length} saved details');
      
      // Check if cart is still valid
      final checkoutState = context.read<CheckoutState>();
      debugPrint('📝 PaymentDetailsScreen: Cart has ${checkoutState.items.length} item(s)');
      if (checkoutState.items.isEmpty) {
        debugPrint('⚠️ PaymentDetailsScreen: Cart is empty! Popping back to cart.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            BookingFlow.navigatorKey.currentState?.pop();
          }
        });
        return;
      }
      
      if (mounted) {
        setState(() {
          _savedDetails = saved;
          if (saved.isNotEmpty && !_showNewForm) {
            _selectedSavedId = saved.first['id'] as String;
            // Defer loading selected details to avoid notifyListeners during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loadSelectedDetails();
              }
            });
          }
        });
        debugPrint('📝 PaymentDetailsScreen: State updated successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ PaymentDetailsScreen: Error loading saved details: $e');
      debugPrint('❌ PaymentDetailsScreen: Stack trace: $stackTrace');
    }
  }

  void _loadSelectedDetails() {
    if (_selectedSavedId == null) return;
    debugPrint('📝 PaymentDetailsScreen: Loading selected details for ID: $_selectedSavedId');
    final selected = _savedDetails.firstWhere(
      (d) => d['id'] == _selectedSavedId,
      orElse: () => {},
    );
    if (selected.isNotEmpty) {
      debugPrint('📝 PaymentDetailsScreen: Found selected details, mapping...');
      final details = _billingService.mapToBillingDetails(selected);
      final checkoutState = context.read<CheckoutState>();
      final cartEventDate = checkoutState.items.isNotEmpty 
          ? checkoutState.items.first.bookingDate 
          : null;
      debugPrint('📝 PaymentDetailsScreen: Saving billing details to CheckoutState...');
      // Use a microtask to defer the notifyListeners call
      Future.microtask(() {
        if (mounted) {
          checkoutState.saveBillingDetails(details.copyWith(eventDate: cartEventDate));
          _formKey.currentState?.loadDetails(details.copyWith(eventDate: cartEventDate));
          debugPrint('📝 PaymentDetailsScreen: Billing details saved successfully');
        }
      });
    } else {
      debugPrint('⚠️ PaymentDetailsScreen: Selected details not found');
    }
  }

  // Removed _goToSavedDetailsAndProceed - no longer needed as PaymentDetailsScreen handles everything

  Future<void> _onNext() async {
    debugPrint('➡️ PaymentDetailsScreen: Next button pressed');
    
    // Check if cart is still valid
    final checkoutState = context.read<CheckoutState>();
    if (checkoutState.items.isEmpty) {
      debugPrint('⚠️ PaymentDetailsScreen: Cart is empty! Popping back.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cart is empty. Please add items to cart.'),
            backgroundColor: Colors.red,
          ),
        );
        BookingFlow.navigatorKey.currentState?.pop();
      }
      return;
    }
    
    // If using saved details, ensure they're loaded
    if (_selectedSavedId != null && !_showNewForm) {
      debugPrint('📝 PaymentDetailsScreen: Using saved details, ensuring they are loaded');
      if (checkoutState.billingDetails == null) {
        _loadSelectedDetails();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } else if (_showNewForm || _savedDetails.isEmpty) {
      // Validate and save form
      final formState = _formKey.currentState;
      if (formState == null) {
        debugPrint('❌ PaymentDetailsScreen: Form state is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form not initialized. Please try again.')),
          );
        }
        return;
      }
      
      debugPrint('🔍 PaymentDetailsScreen: Validating form...');
      final isValid = await formState.validateAndSave();
      if (!isValid) {
        debugPrint('❌ PaymentDetailsScreen: Form validation failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all required details')),
          );
        }
        return;
      }
      
      // Wait for billing details to be saved
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Final check for billing details
    final finalCheckoutState = context.read<CheckoutState>();
    if (finalCheckoutState.billingDetails == null) {
      debugPrint('❌ PaymentDetailsScreen: Billing details still null after validation');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required details')),
        );
      }
      return;
    }

    // Ensure Navigator is ready before navigating
    final navigator = BookingFlow.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('⚠️ BookingFlow Navigator not ready yet');
      // Fallback: use context Navigator if BookingFlow Navigator isn't ready
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentSummaryScreen()),
        );
      }
      return;
    }
    
    debugPrint('✅ PaymentDetailsScreen: Navigating to PaymentSummaryScreen');
    // Use the Navigator key from BookingFlow to ensure correct navigation
    navigator.push(
      MaterialPageRoute(builder: (_) => const PaymentSummaryScreen()),
    );
  }

  Future<void> _onSavePressed() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final checkoutState = context.read<CheckoutState>();

      // Validate cart
      if (checkoutState.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cart is empty. Please add items to cart.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate + save form into CheckoutState
      final formState = _formKey.currentState;
      if (formState == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form not initialized. Please try again.')),
          );
        }
        return;
      }

      final ok = await formState.validateAndSave();
      if (!ok) return;

      // Wait a bit for CheckoutState to be updated by onSave callback
      await Future.delayed(const Duration(milliseconds: 150));

      final details = checkoutState.billingDetails;
      if (details == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save details. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Persist into Saved Billing Details
      final savedId = await _billingService.saveBillingDetails(
        name: details.name,
        email: details.email,
        phone: details.phone,
        messageToVendor: details.messageToVendor,
        isDefault: _savedDetails.isEmpty,
      );

      if (mounted) {
        await _loadSavedDetails();
        setState(() {
          _selectedSavedId = savedId;
          _showNewForm = false;
        });
        // Reload selected details to ensure they're in CheckoutState
        _loadSelectedDetails();
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Navigate to payment summary after saving
        final navigator = BookingFlow.navigatorKey.currentState;
        if (navigator != null) {
          navigator.push(
            MaterialPageRoute(builder: (_) => const PaymentSummaryScreen()),
          );
        } else if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentSummaryScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📝 PaymentDetailsScreen: build() called');
    
    // Use read instead of watch to avoid rebuilds when CheckoutState changes
    // We only need to check cart state, not rebuild on every change
    final checkoutState = context.read<CheckoutState>();
    debugPrint('📝 PaymentDetailsScreen: Cart state - ${checkoutState.items.length} item(s)');
    
    // Check if cart is empty
    if (checkoutState.items.isEmpty) {
      debugPrint('⚠️ PaymentDetailsScreen: Cart is empty! Popping back.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          BookingFlow.navigatorKey.currentState?.pop();
        }
      });
    }
    
    return WillPopScope(
      onWillPop: () async {
        debugPrint('📝 PaymentDetailsScreen: Back button pressed');
        // Allow back navigation
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final navigator = BookingFlow.navigatorKey.currentState;
              if (navigator != null && navigator.canPop()) {
                navigator.pop();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savedDetails.isNotEmpty && !_showNewForm) ...[
              Text(
                'Saved Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._savedDetails.map((detail) => Card(
                    child: RadioListTile<String>(
                      title: Text('${detail['name']}'),
                      subtitle: Text('${detail['email']} • ${detail['phone']}'),
                      value: detail['id'] as String,
                      groupValue: _selectedSavedId,
                      onChanged: (value) {
                        setState(() {
                          _selectedSavedId = value;
                        });
                        _loadSelectedDetails();
                      },
                      secondary: PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await _billingService.deleteBillingDetails(detail['id'] as String);
                            _loadSavedDetails();
                          }
                        },
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showNewForm = true;
                    _selectedSavedId = null;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Use Another Address'),
              ),
              const SizedBox(height: 24),
            ],
            if (_showNewForm || _savedDetails.isEmpty) ...[
              BillingForm(
                key: _formKey,
                initial: checkoutState.billingDetails,
                showSaveButton: false,
                onSave: (details) async {
                  try {
                    debugPrint('💾 PaymentDetailsScreen: onSave callback called');
                    final checkoutState = context.read<CheckoutState>();
                    
                    // Check if cart is still valid
                    if (checkoutState.items.isEmpty) {
                      debugPrint('⚠️ PaymentDetailsScreen: Cart is empty in onSave');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cart is empty. Please add items to cart.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    
                    final cartEventDate = checkoutState.items.isNotEmpty 
                        ? checkoutState.items.first.bookingDate 
                        : null;
                    
                    debugPrint('💾 PaymentDetailsScreen: Saving billing details to CheckoutState');
                    checkoutState.saveBillingDetails(details.copyWith(eventDate: cartEventDate));
                    
                    // Wait a bit for state to update
                    await Future.delayed(const Duration(milliseconds: 100));
                    
                    debugPrint('✅ PaymentDetailsScreen: Billing details saved to CheckoutState');
                  } catch (e, stackTrace) {
                    debugPrint('❌ PaymentDetailsScreen: Error in onSave: $e');
                    debugPrint('❌ PaymentDetailsScreen: Stack trace: $stackTrace');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving details: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              // Save button: saves details to database and navigates to summary
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _onSavePressed,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save & Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onNext,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Continue to Summary'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Step 3: Payment Summary Screen
class PaymentSummaryScreen extends StatefulWidget {
  const PaymentSummaryScreen({super.key});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _policyKey = GlobalKey();
  bool _policyAgreed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPolicy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_policyKey.currentContext != null) {
        Scrollable.ensureVisible(
          _policyKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = context.watch<CheckoutState>();
    final billingDetails = checkoutState.billingDetails;
    final items = checkoutState.items;

    if (billingDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Summary')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Billing details not found'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  BookingFlow.navigatorKey.currentState?.pop();
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order Summary')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle('Order Items (${items.length} ${items.length == 1 ? 'service' : 'services'})'),
                  // Show detailed breakdown for each service
                  ...items.asMap().entries.map((entry) {
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                            if (item.bookingDate != null || item.bookingTime != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (item.bookingDate != null)
                                    Chip(
                                      label: Text('Date: ${_formatDate(item.bookingDate!)}'),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (item.bookingTime != null)
                                    Chip(
                                      label: Text('Time: ${_formatTime(item.bookingTime!)}'),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '₹${checkoutState.totalPrice.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Payment Breakdown'),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Milestone-Based Payment Structure',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _PaymentMilestoneRow(
                            label: 'Advance Payment',
                            percentage: 20,
                            amount: checkoutState.totalPrice * 0.20,
                            description: 'To initiate booking',
                            icon: Icons.payment,
                          ),
                          const Divider(height: 24),
                          _PaymentMilestoneRow(
                            label: 'Arrival Payment',
                            percentage: 50,
                            amount: checkoutState.totalPrice * 0.50,
                            description: 'After vendor arrival confirmation',
                            icon: Icons.location_on,
                          ),
                          const Divider(height: 24),
                          _PaymentMilestoneRow(
                            label: 'Completion Payment',
                            percentage: 30,
                            amount: checkoutState.totalPrice * 0.30,
                            description: 'After setup completion confirmation',
                            icon: Icons.check_circle,
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                '₹${checkoutState.totalPrice.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Billing Details'),
                  _SummaryRow(label: 'Name', value: billingDetails.name),
                  _SummaryRow(label: 'Email', value: billingDetails.email),
                  _SummaryRow(label: 'Phone', value: billingDetails.phone),
                  if (billingDetails.messageToVendor != null) ...[
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Message',
                      value: billingDetails.messageToVendor!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _PolicyCard(
                    key: _policyKey,
                    agreed: _policyAgreed,
                    onChanged: (value) {
                      setState(() {
                        _policyAgreed = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                debugPrint('🔘 PaymentSummaryScreen: "Proceed to Payment" button pressed');
                if (!_policyAgreed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please read and agree to the cancellation and refund policy to proceed'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  _scrollToPolicy();
                  return;
                }
                _processPayment(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Proceed to Payment'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _processPayment(BuildContext context) {
    debugPrint('💳 PaymentSummaryScreen: Starting payment process...');
    
    final checkoutState = context.read<CheckoutState>();
    final paymentService = PaymentService();

    debugPrint('💳 PaymentSummaryScreen: CheckoutState items: ${checkoutState.items.length}');
    debugPrint('💳 PaymentSummaryScreen: Total price: ₹${checkoutState.totalPrice}');
    debugPrint('💳 PaymentSummaryScreen: Billing details: ${checkoutState.billingDetails != null ? "Present" : "Missing"}');

    // Validate cart
    if (checkoutState.items.isEmpty) {
      debugPrint('❌ PaymentSummaryScreen: Cart is empty!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Please add items to cart.'),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to cart
      BookingFlow.navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    // Validate billing details
    if (checkoutState.billingDetails == null) {
      debugPrint('❌ PaymentSummaryScreen: Billing details missing!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billing details are required. Please fill in all details.'),
          backgroundColor: Colors.red,
        ),
      );
      // Navigate back to payment details
      BookingFlow.navigatorKey.currentState?.pop();
      return;
    }

    // Validate that all items have valid data
    try {
      for (final item in checkoutState.items) {
        if (item.id.isEmpty || item.title.isEmpty) {
          throw Exception('Invalid cart item found');
        }
      }
    } catch (e) {
      debugPrint('❌ PaymentSummaryScreen: Invalid cart items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid cart items. Please refresh and try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      paymentService.processPayment(
        context: context,
        checkoutState: checkoutState,
        onSuccess: () {
          debugPrint('✅ PaymentSummaryScreen: Payment success callback called');
          // Pop all routes in BookingFlow Navigator, then pop BookingFlow itself
          BookingFlow.navigatorKey.currentState?.popUntil((route) => route.isFirst);
          // Pop BookingFlow from main Navigator
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        },
        onFailure: () {
          debugPrint('❌ PaymentSummaryScreen: Payment failure callback called');
          // Stay on current screen for retry - don't pop
        },
      );
      debugPrint('✅ PaymentSummaryScreen: processPayment called successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ PaymentSummaryScreen: Exception in _processPayment: $e');
      debugPrint('❌ PaymentSummaryScreen: Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating payment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _NavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint('🧭 BookingFlow Navigator: Pushed route: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    debugPrint('🧭 BookingFlow Navigator: Popped route: ${route.settings.name ?? route.runtimeType}');
    debugPrint('🧭 BookingFlow Navigator: Stack trace: ${StackTrace.current}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    debugPrint('🧭 BookingFlow Navigator: Removed route: ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    debugPrint('🧭 BookingFlow Navigator: Replaced route');
  }
}

// SavedBillingDetailsScreen removed - PaymentDetailsScreen now handles both saved details and new form entry

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : null,
          ),
          Text(
            value,
            style: isBold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

class _PaymentMilestoneRow extends StatelessWidget {
  final String label;
  final int percentage;
  final double amount;
  final String description;
  final IconData icon;

  const _PaymentMilestoneRow({
    required this.label,
    required this.percentage,
    required this.amount,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$percentage%',
                      style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;

  const _PolicyCard({
    super.key,
    required this.agreed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cancellation & Refund Policy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              'Cancellations made 7+ days before event: Full refund',
              'Cancellations made 3-7 days before event: 50% refund',
              'Cancellations made less than 3 days before event: No refund',
              'Refunds will be processed within 5-7 business days',
            ].map((policy) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          policy,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: agreed ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: agreed ? Colors.green.shade300 : Colors.red.shade300,
                  width: 2,
                ),
              ),
              child: CheckboxListTile(
                value: agreed,
                onChanged: (value) {
                  onChanged(value ?? false);
                },
                title: Text(
                  'I have read and agree to the cancellation and refund policy',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.green.shade700,
                checkColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
