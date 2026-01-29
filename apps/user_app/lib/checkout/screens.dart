import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'checkout_state.dart';
import 'widgets.dart';
import '../services/payment_service.dart';
import '../services/booking_draft_service.dart';
import '../services/billing_details_service.dart';

// Shared button style
ButtonStyle _primaryBtn(BuildContext context) => ElevatedButton.styleFrom(
  backgroundColor: Theme.of(context).colorScheme.primary,
  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Active cart items
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No items in cart',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    items.length,
                    (i) => _cartTile(context, items[i], i),
                  ),

                // Saved for later section
                if (savedItems.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Divider(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved for later',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                child: ElevatedButton(
                  onPressed: items.isEmpty ? null : onNext,
                  style: _primaryBtn(context),
                  child: const Text('Next'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cartTile(BuildContext context, CartItem item, int index) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05), 
            blurRadius: 8, 
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close, 
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      tooltip: 'Remove from cart',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final state = context.read<CheckoutState>();
                        await state.removeItemAt(index);
                      },
                    ),
                  ],
                ),
              ],
            ),
            
            // Date and Time information
            if (item.bookingDate != null || item.bookingTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.bookingDate != null)
                            Text(
                              _formatDate(item.bookingDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (item.bookingDate != null && item.bookingTime != null)
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          if (item.bookingTime != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(item.bookingTime!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final state = context.read<CheckoutState>();
                    await state.saveItemForLater(index);
                  },
                  icon: Icon(
                    Icons.bookmark_border,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Save for later',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 
        ? 12 
        : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Tile for saved-for-later items
  Widget _savedTile(BuildContext context, CartItem item, int index) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close, 
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      tooltip: 'Remove',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final state = context.read<CheckoutState>();
                        await state.removeSavedItemAt(index);
                      },
                    ),
                  ],
                ),
              ],
            ),
            
            // Date and Time information (if available)
            if (item.bookingDate != null || item.bookingTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.bookingDate != null)
                            Text(
                              _formatDate(item.bookingDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (item.bookingDate != null && item.bookingTime != null)
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          if (item.bookingTime != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(item.bookingTime!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final state = context.read<CheckoutState>();
                    await state.moveSavedItemToCart(index);
                  },
                  icon: Icon(
                    Icons.shopping_cart_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Move to cart',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
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
      final theme = Theme.of(context);
      final details = state.billingDetails;
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05), 
              blurRadius: 8, 
              offset: const Offset(0, 2),
            ),
          ],
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

class PaymentDetailsPage extends StatefulWidget {
  final VoidCallback onChoosePayment;
  final VoidCallback onNext;
  const PaymentDetailsPage({super.key, required this.onChoosePayment, required this.onNext});

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  final GlobalKey<BillingFormState> _billingFormKey = GlobalKey<BillingFormState>();
  final BillingDetailsService _billingService = BillingDetailsService(Supabase.instance.client);
  List<Map<String, dynamic>> _savedDetails = [];
  bool _isLoadingSaved = true;
  String? _selectedSavedId;
  bool _showNewForm = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
  }

  Future<void> _loadSavedDetails() async {
    setState(() {
      _isLoadingSaved = true;
    });
    final saved = await _billingService.getSavedBillingDetails();
    if (mounted) {
      setState(() {
        _savedDetails = saved;
        _isLoadingSaved = false;
        // Auto-select default if available
        if (saved.isNotEmpty) {
          final defaultDetail = saved.firstWhere(
            (d) => d['is_default'] == true,
            orElse: () => saved.first,
          );
          _selectedSavedId = defaultDetail['id'] as String;
          _loadSelectedDetails();
        }
      });
    }
  }

  void _loadSelectedDetails() {
    if (_selectedSavedId == null) return;
    final selected = _savedDetails.firstWhere(
      (d) => d['id'] == _selectedSavedId,
      orElse: () => {},
    );
    if (selected.isNotEmpty) {
      final details = _billingService.mapToBillingDetails(selected);
      
      // Get event date from cart item's booking date if available
      final checkoutState = context.read<CheckoutState>();
      DateTime? eventDate = details.eventDate;
      if (eventDate == null && checkoutState.items.isNotEmpty) {
        final itemWithDate = checkoutState.items.firstWhere(
          (item) => item.bookingDate != null,
          orElse: () => checkoutState.items.first,
        );
        if (itemWithDate.bookingDate != null) {
          eventDate = itemWithDate.bookingDate;
          debugPrint('✅ PaymentDetailsPage: Using booking date as event date: $eventDate');
        }
      }
      
      // Create billing details with event date from booking date
      final billingDetails = BillingDetails(
        name: details.name,
        email: details.email,
        phone: details.phone,
        eventDate: eventDate ?? details.eventDate,
        messageToVendor: details.messageToVendor,
      );
      
      _billingFormKey.currentState?.loadDetails(billingDetails);
      checkoutState.saveBillingDetails(billingDetails);
      debugPrint('✅ Loaded saved billing details into CheckoutState: ${billingDetails.name}');
      if (billingDetails.eventDate != null) {
        debugPrint('   Event date: ${billingDetails.eventDate}');
      }
    } else {
      debugPrint('⚠️ Selected saved detail not found');
    }
  }

  Future<void> _saveCurrentDetails() async {
    final formState = _billingFormKey.currentState;
    if (formState == null || !formState.validateAndSave()) {
      return;
    }

    final checkoutState = context.read<CheckoutState>();
    final details = checkoutState.billingDetails;
    if (details == null) return;

    final savedId = await _billingService.saveBillingDetails(
      name: details.name,
      email: details.email,
      phone: details.phone,
      messageToVendor: details.messageToVendor,
      isDefault: _savedDetails.isEmpty, // First saved detail becomes default
    );

    if (savedId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billing details saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadSavedDetails();
      setState(() {
        _selectedSavedId = savedId;
        _showNewForm = false;
      });
      _loadSelectedDetails();
    }
  }

  Future<void> _deleteSavedDetail(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Details'),
        content: const Text('Are you sure you want to delete these saved billing details?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _billingService.deleteBillingDetails(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved details deleted'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadSavedDetails();
        if (_selectedSavedId == id) {
          setState(() {
            _selectedSavedId = null;
            _showNewForm = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CheckoutState>();
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: _isLoadingSaved
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InstallmentCard(installments: state.installmentBreakdown, total: state.totalPrice),
                const SizedBox(height: 16),
                
                // Saved Details Section
                if (_savedDetails.isNotEmpty) ...[
                  Text(
                    'Saved Billing Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._savedDetails.map((saved) {
                    final isSelected = _selectedSavedId == saved['id'];
                    final isDefault = saved['is_default'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSavedId = saved['id'] as String;
                            _showNewForm = false;
                          });
                          _loadSelectedDetails();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            saved['name'] as String? ?? '',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (isDefault)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Default',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      saved['email'] as String? ?? '',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      saved['phone'] as String? ?? '',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                      size: 24,
                                    ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteSavedDetail(saved['id'] as String);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: theme.colorScheme.error,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: theme.colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showNewForm = !_showNewForm;
                              if (_showNewForm) {
                                _selectedSavedId = null;
                                _billingFormKey.currentState?.loadDetails(BillingDetails(
                                  name: '',
                                  email: '',
                                  phone: '',
                                ));
                              }
                            });
                          },
                          icon: Icon(_showNewForm ? Icons.arrow_upward : Icons.add),
                          label: Text(_showNewForm ? 'Hide New Details' : 'Add New Details'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // New Details Form
                if (_showNewForm || _savedDetails.isEmpty) ...[
                  if (_savedDetails.isNotEmpty)
                    Text(
                      'New Billing Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (_savedDetails.isNotEmpty) const SizedBox(height: 12),
                  BillingForm(
              key: _billingFormKey,
              initial: state.billingDetails,
                    onSave: (d) async {
                      final checkoutState = context.read<CheckoutState>();
                      
                      // Get event date from cart item's booking date if not provided
                      DateTime? eventDate = d.eventDate;
                      if (eventDate == null && checkoutState.items.isNotEmpty) {
                        final itemWithDate = checkoutState.items.firstWhere(
                          (item) => item.bookingDate != null,
                          orElse: () => checkoutState.items.first,
                        );
                        if (itemWithDate.bookingDate != null) {
                          eventDate = itemWithDate.bookingDate;
                          debugPrint('✅ PaymentDetailsPage: Using booking date as event date: $eventDate');
                        }
                      }
                      
                      // Create billing details with event date from booking date
                      final billingDetails = BillingDetails(
                        name: d.name,
                        email: d.email,
                        phone: d.phone,
                        eventDate: eventDate,
                        messageToVendor: d.messageToVendor,
                      );
                      
                      checkoutState.saveBillingDetails(billingDetails);
                      
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
                              eventDate: eventDate, // Use event date from booking date
                              messageToVendor: d.messageToVendor,
                            );
                            
                            if (draftId != null) {
                              checkoutState.setDraftId(draftId);
                            }
                          }
                        } catch (e) {
                          print('Error creating draft from billing details: $e');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Save Details Button (only show when form is visible and has content)
                  if (_showNewForm || _savedDetails.isEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveCurrentDetails,
                            icon: const Icon(Icons.save),
                            label: const Text('Save These Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: theme.colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                ],
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // If saved detail is selected, ensure it's loaded into CheckoutState
                          if (_selectedSavedId != null && !_showNewForm) {
                            final checkoutState = context.read<CheckoutState>();
                            // Ensure saved details are loaded
                            if (checkoutState.billingDetails == null) {
                              _loadSelectedDetails();
                              // Wait a bit for state to update
                              await Future.delayed(const Duration(milliseconds: 100));
                            }
                            
                            if (checkoutState.billingDetails != null) {
                              debugPrint('✅ Using saved billing details, navigating to payment method...');
                              if (mounted) {
                                widget.onChoosePayment();
                              }
                              return;
                            } else {
                              debugPrint('⚠️ Saved details not loaded, falling back to form validation');
                            }
                          }
                          
                          // Otherwise validate form
                          final formState = _billingFormKey.currentState;
                          if (formState == null) {
                            debugPrint('⚠️ BillingFormState is null');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Form not initialized. Please try again.')),
                              );
                            }
                            return;
                          }
                          
                          debugPrint('🔍 Validating billing form...');
                          final ok = formState.validateAndSave();
                          debugPrint('✅ Form validation result: $ok');
                          
                          if (!ok) {
                            debugPrint('❌ Form validation failed');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all required details before choosing payment method'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                            return;
                          }
                          
                          // Wait a bit for billing details to be saved
                          await Future.delayed(const Duration(milliseconds: 200));
                          
                          debugPrint('✅ Form validated, navigating to payment method...');
                          if (mounted) {
                            widget.onChoosePayment();
                          }
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
                        onPressed: () async {
                          // If saved detail is selected, ensure it's loaded into CheckoutState
                          if (_selectedSavedId != null && !_showNewForm) {
                            final checkoutState = context.read<CheckoutState>();
                            // Ensure saved details are loaded
                            if (checkoutState.billingDetails == null) {
                              _loadSelectedDetails();
                              // Wait a bit for state to update
                              await Future.delayed(const Duration(milliseconds: 100));
                            }
                            
                            if (checkoutState.billingDetails != null) {
                              debugPrint('✅ Using saved billing details, navigating to payment summary...');
                              if (mounted) {
                                widget.onNext();
                              }
                              return;
                            } else {
                              debugPrint('⚠️ Saved details not loaded, falling back to form validation');
                            }
                          }
                          
                          // Otherwise validate form
                          final formState = _billingFormKey.currentState;
                          if (formState == null) {
                            debugPrint('⚠️ BillingFormState is null');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Form not initialized. Please try again.')),
                              );
                            }
                            return;
                          }
                          
                          debugPrint('🔍 Validating billing form...');
                          final ok = formState.validateAndSave();
                          debugPrint('✅ Form validation result: $ok');
                          
                          if (!ok) {
                            debugPrint('❌ Form validation failed');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all required details before continuing'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                            return;
                          }
                          
                          // Wait a bit for billing details to be saved
                          await Future.delayed(const Duration(milliseconds: 200));
                          
                          debugPrint('✅ Form validated, navigating to payment summary...');
                          if (mounted) {
                            widget.onNext();
                          }
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05), 
                  blurRadius: 8, 
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (d == null) const Text('No details saved') else ...[
                  _buildDetailRow(context, 'Name', d.name),
                  _buildDetailRow(context, 'Email', d.email),
                  _buildDetailRow(context, 'Phone', d.phone),
                  if (d.messageToVendor != null)
                    _buildDetailRow(
                      context,
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

  Widget _buildDetailRow(BuildContext context, String label, String value, {int maxLines = 1}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.04),
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


