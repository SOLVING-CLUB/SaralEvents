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
  final List<CartItem> _items = <CartItem>[];
  BillingDetails? _billingDetails;
  SelectedPaymentMethod? _paymentMethod;
  String? _draftId; // Booking draft ID for creating booking after payment

  // Installment policy: 3 installments - Today, +30, +60 days
  // Percentages can be tuned if needed; default equal thirds
  final List<double> _installmentPercentages = const [0.34, 0.33, 0.33];

  List<CartItem> get items => List.unmodifiable(_items);
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

  void removeItem(String itemId) {
    _items.removeWhere((e) => e.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
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


