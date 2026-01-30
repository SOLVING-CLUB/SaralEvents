import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_item_service.dart';


/// Data model representing an item in the cart
class CartItem {
  final String id;
  final String title;
  final String category; // e.g., Venue, Decoration, Catering
  final double price;
  final String? subtitle;
  final DateTime? bookingDate;
  final TimeOfDay? bookingTime;
  final String? locationLink; // Google Maps location link for destination

  const CartItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    this.subtitle,
    this.bookingDate,
    this.bookingTime,
    this.locationLink,
  });
}

/// Data model representing billing details collected in the flow
class BillingDetails {
  final String name;
  final String email;
  final String phone;
  final DateTime? eventDate;
  final String? messageToVendor;

  const BillingDetails({
    required this.name,
    required this.email,
    required this.phone,
    this.eventDate,
    this.messageToVendor,
  });

  BillingDetails copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? eventDate,
    String? messageToVendor,
  }) {
    return BillingDetails(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      eventDate: eventDate ?? this.eventDate,
      messageToVendor: messageToVendor ?? this.messageToVendor,
    );
  }
}

enum PaymentMethodType {
  cash,
  upi,
  card,
  netBanking,
}

class SelectedPaymentMethod {
  final PaymentMethodType type;
  final String? upiId;
  final String? cardNumber;
  final String? cardName;
  final String? cardExpiry; // MM/YY
  final String? cardCvv;
  final String? bankName; // for net banking

  const SelectedPaymentMethod({
    required this.type,
    this.upiId,
    this.cardNumber,
    this.cardName,
    this.cardExpiry,
    this.cardCvv,
    this.bankName,
  });

  SelectedPaymentMethod copyWith({
    PaymentMethodType? type,
    String? upiId,
    String? cardNumber,
    String? cardName,
    String? cardExpiry,
    String? cardCvv,
    String? bankName,
  }) {
    return SelectedPaymentMethod(
      type: type ?? this.type,
      upiId: upiId ?? this.upiId,
      cardNumber: cardNumber ?? this.cardNumber,
      cardName: cardName ?? this.cardName,
      cardExpiry: cardExpiry ?? this.cardExpiry,
      cardCvv: cardCvv ?? this.cardCvv,
      bankName: bankName ?? this.bankName,
    );
  }
}

/// Provider-backed state for the checkout flow
/// Now syncs with Supabase database for persistence and cross-device sync
class CheckoutState extends ChangeNotifier {
  // Active items that will be included in the current checkout
  final List<CartItem> _items = <CartItem>[];
  // Items saved for later (not included in totals or current booking)
  final List<CartItem> _savedItems = <CartItem>[];
  BillingDetails? _billingDetails;
  SelectedPaymentMethod? _paymentMethod;
  String? _draftId; // Booking draft ID for creating booking after payment

  // Installment policy: 3 installments - Today, +30, +60 days
  // Percentages can be tuned if needed; default equal thirds
  final List<double> _installmentPercentages = const [0.34, 0.33, 0.33];

  // Database service and real-time subscription
  CartItemService? _cartService;
  RealtimeChannel? _cartChannel;
  bool _isLoading = false;
  bool _isInitialized = false;

  List<CartItem> get items => List.unmodifiable(_items);
  List<CartItem> get savedItems => List.unmodifiable(_savedItems);
  BillingDetails? get billingDetails => _billingDetails;
  SelectedPaymentMethod? get paymentMethod => _paymentMethod;
  String? get draftId => _draftId;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  double get totalPrice => _items.fold(0.0, (sum, i) => sum + i.price);

  /// Coupon applied at checkout (validated via RPC)
  String? get appliedCouponCode => _appliedCouponCode;
  String? get appliedCouponId => _appliedCouponId;
  double get discountAmount => _discountAmount;
  /// Total after discount (never below 0)
  double get totalAfterDiscount => (totalPrice - _discountAmount).clamp(0.0, double.infinity);

  String? _appliedCouponCode;
  String? _appliedCouponId;
  double _discountAmount = 0;

  /// Validate and apply a coupon. Returns error message or null on success.
  Future<String?> applyCoupon(String code, String? phone) async {
    final codeTrim = code.trim();
    if (codeTrim.isEmpty) return 'Enter a coupon code';
    final total = totalPrice;
    if (total <= 0) return 'Add items to cart first';
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return 'Please sign in to use a coupon';
      final serviceIds = _items.map((i) => i.id).toList();
      final res = await Supabase.instance.client.rpc(
        'validate_coupon',
        params: {
          'p_code': codeTrim,
          'p_user_id': userId,
          'p_phone': phone ?? '',
          'p_order_total_rs': total,
          'p_service_ids': serviceIds.isNotEmpty ? serviceIds : null,
        },
      );
      if (res == null) return 'Invalid response';
      final valid = res['valid'] as bool? ?? false;
      final message = res['message'] as String? ?? 'Invalid coupon';
      if (!valid) return message;
      _appliedCouponCode = res['code'] as String? ?? codeTrim;
      _appliedCouponId = res['coupon_id'] as String?;
      _discountAmount = (res['discount_amount'] as num?)?.toDouble() ?? 0;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not validate coupon';
    }
  }

  void clearCoupon() {
    _appliedCouponCode = null;
    _appliedCouponId = null;
    _discountAmount = 0;
    notifyListeners();
  }

  /// Initialize cart service and load cart from database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _isInitialized = true;
        return;
      }

      _cartService = CartItemService(Supabase.instance.client);
      await _loadCartFromDatabase();
      _setupRealtimeSubscription();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing cart: $e');
      _isInitialized = true;
    }
  }

  /// Load cart from database
  Future<void> _loadCartFromDatabase() async {
    if (_cartService == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final cartItems = await _cartService!.loadCartItems();
      final savedItems = await _cartService!.loadSavedItems();

      _items.clear();
      _items.addAll(cartItems);
      _savedItems.clear();
      _savedItems.addAll(savedItems);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading cart from database: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Setup real-time subscription for cross-device sync
  void _setupRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _cartService == null) return;

    try {
      // Unsubscribe from previous channel if exists
      _cartChannel?.unsubscribe();

      // Subscribe to cart_items changes for this user
      _cartChannel = Supabase.instance.client
          .channel('cart_items_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cart_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              // Reload cart when changes occur (from other devices)
              _loadCartFromDatabase();
            },
          )
          .subscribe();
    } catch (e) {
      print('Error setting up real-time subscription: $e');
    }
  }

  /// Clear cart and unsubscribe when user logs out
  void clearAndDispose() {
    _cartChannel?.unsubscribe();
    _cartChannel = null;
    _cartService = null;
    _items.clear();
    _savedItems.clear();
    _billingDetails = null;
    _paymentMethod = null;
    _draftId = null;
    _appliedCouponCode = null;
    _appliedCouponId = null;
    _discountAmount = 0;
    _isInitialized = false;
    notifyListeners();
  }

  /// Returns a 3-length list representing amounts for each installment (based on total after discount)
  List<double> get installmentBreakdown {
    final total = totalAfterDiscount;
    if (total <= 0) return const [0, 0, 0];
    return _installmentPercentages
        .map((p) => (total * p))
        .toList(growable: false);
  }

  void setInstallmentPercentages(List<double> percentages) {
    if (percentages.length != 3) return;
    final sum = percentages.fold(0.0, (s, p) => s + p);
    if (sum <= 0) return;
    _installmentPercentages
      ..clear()
      ..addAll(percentages);
    notifyListeners();
  }

  Future<void> addItem(CartItem item) async {
    // Add to local state immediately for responsive UI
    _items.add(item);
    
    // If cart item has a booking date, set it as event date in billing details
    if (item.bookingDate != null) {
      final currentDetails = _billingDetails;
      if (currentDetails != null) {
        // Update existing billing details with event date from booking date
        _billingDetails = BillingDetails(
          name: currentDetails.name,
          email: currentDetails.email,
          phone: currentDetails.phone,
          eventDate: item.bookingDate, // Set event date from booking date
          messageToVendor: currentDetails.messageToVendor,
        );
      } else {
        // If no billing details exist yet, we'll set event date when billing details are first saved
        // For now, just store it - it will be used when user enters billing details
      }
    }
    
    notifyListeners();

    // Sync to database
    if (_cartService != null) {
      try {
        // Get vendor_id from service
        final serviceResult = await Supabase.instance.client
            .from('services')
            .select('vendor_id')
            .eq('id', item.id)
            .maybeSingle();

        if (serviceResult != null) {
          final vendorId = serviceResult['vendor_id'] as String;
          await _cartService!.addToCart(
            serviceId: item.id,
            vendorId: vendorId,
            title: item.title,
            category: item.category,
            price: item.price,
            subtitle: item.subtitle,
            bookingDate: item.bookingDate,
            bookingTime: item.bookingTime,
            status: 'active',
          );
        }
      } catch (e) {
        print('Error syncing item to database: $e');
        // Remove from local state if sync fails
        _items.removeLast();
        notifyListeners();
        rethrow;
      }
    }
  }

  /// Add item directly to saved-for-later list
  Future<void> addSavedItem(CartItem item) async {
    // Add to local state immediately
    _savedItems.add(item);
    notifyListeners();

    // Sync to database
    if (_cartService != null) {
      try {
        // Get vendor_id from service
        final serviceResult = await Supabase.instance.client
            .from('services')
            .select('vendor_id')
            .eq('id', item.id)
            .maybeSingle();

        if (serviceResult != null) {
          final vendorId = serviceResult['vendor_id'] as String;
          await _cartService!.addToCart(
            serviceId: item.id,
            vendorId: vendorId,
            title: item.title,
            category: item.category,
            price: item.price,
            subtitle: item.subtitle,
            bookingDate: item.bookingDate,
            bookingTime: item.bookingTime,
            status: 'saved_for_later',
          );
        }
      } catch (e) {
        print('Error syncing saved item to database: $e');
        // Remove from local state if sync fails
        _savedItems.removeLast();
        notifyListeners();
        rethrow;
      }
    }
  }

  /// Remove all items with the given id (used when you want to clear a
  /// particular service from the cart everywhere).
  void removeItem(String itemId) {
    _items.removeWhere((e) => e.id == itemId);
    notifyListeners();
  }

  /// Remove a single cart entry at the given index. This is useful when there
  /// are multiple entries for the same service and only one line item should
  /// be removed.
  Future<void> removeItemAt(int index) async {
    if (index < 0 || index >= _items.length) return;

    // Get cart item ID from database before removing
    String? cartItemId;
    if (_cartService != null) {
      try {
        final cartItems = await _cartService!.getCartItems();
        if (index < cartItems.length) {
          cartItemId = cartItems[index]['id'] as String?;
        }
      } catch (e) {
        print('Error getting cart item ID: $e');
      }
    }

    // Remove from local state
    _items.removeAt(index);
    notifyListeners();

    // Remove from database
    if (_cartService != null && cartItemId != null) {
      try {
        await _cartService!.removeFromCart(cartItemId);
      } catch (e) {
        print('Error removing item from database: $e');
        // Reload from database to sync
        await _loadCartFromDatabase();
      }
    }
  }

  /// Move an active cart item to the saved-for-later list.
  Future<void> saveItemForLater(int index) async {
    if (index < 0 || index >= _items.length) return;

    // Get cart item ID from database
    String? cartItemId;
    if (_cartService != null) {
      try {
        final cartItems = await _cartService!.getCartItems();
        if (index < cartItems.length) {
          cartItemId = cartItems[index]['id'] as String?;
        }
      } catch (e) {
        print('Error getting cart item ID: $e');
      }
    }

    // Move in local state
    final item = _items.removeAt(index);
    _savedItems.add(item);
    notifyListeners();

    // Update in database
    if (_cartService != null && cartItemId != null) {
      try {
        await _cartService!.updateCartItemStatus(cartItemId, 'saved_for_later');
      } catch (e) {
        print('Error updating item status in database: $e');
        // Reload from database to sync
        await _loadCartFromDatabase();
      }
    }
  }

  /// Move a saved-for-later item back into the active cart.
  Future<void> moveSavedItemToCart(int index) async {
    if (index < 0 || index >= _savedItems.length) return;

    // Get cart item ID from database
    String? cartItemId;
    if (_cartService != null) {
      try {
        final savedItems = await _cartService!.getSavedForLater();
        if (index < savedItems.length) {
          cartItemId = savedItems[index]['id'] as String?;
        }
      } catch (e) {
        print('Error getting saved item ID: $e');
      }
    }

    // Move in local state
    final item = _savedItems.removeAt(index);
    _items.add(item);
    notifyListeners();

    // Update in database
    if (_cartService != null && cartItemId != null) {
      try {
        await _cartService!.updateCartItemStatus(cartItemId, 'active');
      } catch (e) {
        print('Error updating item status in database: $e');
        // Reload from database to sync
        await _loadCartFromDatabase();
      }
    }
  }

  /// Remove a single saved-for-later item.
  Future<void> removeSavedItemAt(int index) async {
    if (index < 0 || index >= _savedItems.length) return;

    // Get cart item ID from database
    String? cartItemId;
    if (_cartService != null) {
      try {
        final savedItems = await _cartService!.getSavedForLater();
        if (index < savedItems.length) {
          cartItemId = savedItems[index]['id'] as String?;
        }
      } catch (e) {
        print('Error getting saved item ID: $e');
      }
    }

    // Remove from local state
    _savedItems.removeAt(index);
    notifyListeners();

    // Remove from database
    if (_cartService != null && cartItemId != null) {
      try {
        await _cartService!.removeFromCart(cartItemId);
      } catch (e) {
        print('Error removing saved item from database: $e');
        // Reload from database to sync
        await _loadCartFromDatabase();
      }
    }
  }

  Future<void> clearCart() async {
    // Clear local state
    _items.clear();
    _savedItems.clear();
    notifyListeners();

    // Clear from database
    if (_cartService != null) {
      try {
        await _cartService!.clearCart();
      } catch (e) {
        print('Error clearing cart from database: $e');
      }
    }
  }

  void saveBillingDetails(BillingDetails details) {
    // If event date is not provided in details, try to get it from cart items
    DateTime? eventDate = details.eventDate;
    if (eventDate == null && _items.isNotEmpty) {
      // Get booking date from the first cart item (or any item with a booking date)
      final itemWithDate = _items.firstWhere(
        (item) => item.bookingDate != null,
        orElse: () => _items.first,
      );
      if (itemWithDate.bookingDate != null) {
        eventDate = itemWithDate.bookingDate;
      }
    }
    
    // Create billing details with event date from cart if not provided
    final newBillingDetails = eventDate != null && eventDate != details.eventDate
        ? BillingDetails(
            name: details.name,
            email: details.email,
            phone: details.phone,
            eventDate: eventDate,
            messageToVendor: details.messageToVendor,
          )
        : details;
    
    // Only notify if billing details actually changed
    if (_billingDetails?.name != newBillingDetails.name ||
        _billingDetails?.email != newBillingDetails.email ||
        _billingDetails?.phone != newBillingDetails.phone ||
        _billingDetails?.eventDate != newBillingDetails.eventDate ||
        _billingDetails?.messageToVendor != newBillingDetails.messageToVendor) {
      _billingDetails = newBillingDetails;
      // Defer notifyListeners with a longer delay to ensure we're completely out of build phase
      // This prevents issues with Navigator being disposed during widget tree finalization
      Future.delayed(const Duration(milliseconds: 200), () {
        notifyListeners();
      });
    } else {
      // Update without notifying if nothing changed
      _billingDetails = newBillingDetails;
    }
  }

  void savePaymentMethod(SelectedPaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setDraftId(String? draftId) {
    _draftId = draftId;
    notifyListeners();
  }
}


