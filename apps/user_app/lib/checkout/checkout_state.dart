import 'package:flutter/material.dart';

/// Data model representing an item in the cart
class CartItem {
  final String id;
  final String title;
  final String category; // e.g., Venue, Decoration, Catering
  final double price;
  final String? subtitle;

  const CartItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    this.subtitle,
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

  List<CartItem> get items => List.unmodifiable(_items);
  List<CartItem> get savedItems => List.unmodifiable(_savedItems);
  BillingDetails? get billingDetails => _billingDetails;
  SelectedPaymentMethod? get paymentMethod => _paymentMethod;
  String? get draftId => _draftId;

  double get totalPrice => _items.fold(0.0, (sum, i) => sum + i.price);

  /// Returns a 3-length list representing amounts for each installment
  List<double> get installmentBreakdown {
    final total = totalPrice;
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

  void addItem(CartItem item) {
    _items.add(item);
    notifyListeners();
  }

  /// Add item directly to saved-for-later list
  void addSavedItem(CartItem item) {
    _savedItems.add(item);
    notifyListeners();
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
  void removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  /// Move an active cart item to the saved-for-later list.
  void saveItemForLater(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items.removeAt(index);
    _savedItems.add(item);
    notifyListeners();
  }

  /// Move a saved-for-later item back into the active cart.
  void moveSavedItemToCart(int index) {
    if (index < 0 || index >= _savedItems.length) return;
    final item = _savedItems.removeAt(index);
    _items.add(item);
    notifyListeners();
  }

  /// Remove a single saved-for-later item.
  void removeSavedItemAt(int index) {
    if (index < 0 || index >= _savedItems.length) return;
    _savedItems.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _savedItems.clear();
    notifyListeners();
  }

  void saveBillingDetails(BillingDetails details) {
    _billingDetails = details;
    notifyListeners();
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


