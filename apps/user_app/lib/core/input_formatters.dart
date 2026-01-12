import 'package:flutter/services.dart';

/// Blocks emoji and most non-text pictographic symbols.
/// Allows letters, numbers, punctuation, spaces, and common diacritics.
class NoEmojiTextInputFormatter extends TextInputFormatter {
  // Unicode property regex is not supported; use a conservative BMP range and exclude surrogate/private use.
  static final RegExp _disallowed = RegExp(
    r"[\uD800-\uDFFF\uE000-\uF8FF]", // surrogates and private-use (commonly emojis)
  );

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final filtered = newValue.text.replaceAll(_disallowed, '');
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: _updateSelection(newValue.selection, newValue.text, filtered),
      composing: TextRange.empty,
    );
  }

  TextSelection _updateSelection(TextSelection sel, String before, String after) {
    final int diff = before.length - after.length;
    final int base = (sel.baseOffset - diff).clamp(0, after.length);
    final int extent = (sel.extentOffset - diff).clamp(0, after.length);
    return TextSelection(baseOffset: base, extentOffset: extent);
  }
}

/// Allows only ASCII letters and spaces. Blocks digits, punctuation, emojis, symbols.
class LettersSpacesTextInputFormatter extends TextInputFormatter {
  static final RegExp _allowed = RegExp(r"[A-Za-z ]");

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < newValue.text.length; i++) {
      final String ch = newValue.text[i];
      if (_allowed.hasMatch(ch)) sb.write(ch);
    }
    final filtered = sb.toString();
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

/// Phone number formatter allowing leading '+', digits only after it,
/// and limiting total length to 15 (E.164 max digits incl. country code without separators).
class E164PhoneInputFormatter extends TextInputFormatter {
  final int maxLength;
  E164PhoneInputFormatter({this.maxLength = 15});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    // Keep only leading '+', strip others.
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (i == 0 && ch == '+') {
        sb.write(ch);
      } else if (_isAsciiDigit(ch)) {
        sb.write(ch);
      }
      // ignore everything else
    }

    String normalized = sb.toString();
    if (normalized.length > maxLength) {
      normalized = normalized.substring(0, maxLength);
    }

    // Prevent just '+' with no digits beyond a short length? Keep as is; validation can enforce.
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  bool _isAsciiDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
}

/// Simple validators
class Validators {
  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  /// Validates an E.164-like phone: optional '+', followed by 10-15 digits total.
  /// Enforces at least 10 digits (common local length) and max 15 as per E.164.
  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter phone number';
    final hasPlus = v.startsWith('+');
    final digits = v.replaceAll(RegExp(r"[^0-9]"), '');
    if (digits.length < 10) return 'Enter at least 10 digits';
    if (digits.length > 15) return 'Enter at most 15 digits';
    final RegExp pattern = hasPlus
        ? RegExp(r"^\+[0-9]{10,15}$")
        : RegExp(r"^[0-9]{10,15}$");
    if (!pattern.hasMatch(v)) {
      // fallback check to ensure shape is consistent
      return 'Invalid phone format';
    }
    return null;
  }

  /// Letters, spaces, hyphens and apostrophes; length 1..50
  static String? personName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter a name';
    if (v.length > 50) return 'Name is too long';
    if (!RegExp(r"^[A-Za-z][A-Za-z\s\-']{0,49}").hasMatch(v)) return 'Enter a valid name';
    return null;
  }

  /// Strict person name: only letters and spaces; length 1..50; single spaces between words
  static String? personNameLettersSpaces(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter a name';
    if (v.length > 50) return 'Name is too long';
    if (!RegExp(r"^[A-Za-z]+(?: [A-Za-z]+){0,9}").hasMatch(v)) {
      return 'Use letters and spaces only';
    }
    return null;
  }

  /// Basic email pattern; rely on backend for definitive validation.
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter email';
    final ok = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$").hasMatch(v);
    return ok ? null : 'Enter a valid email';
  }

  /// Validates card number: 13-19 digits (after removing spaces)
  static String? cardNumber(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter card number';
    final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 13 || digitsOnly.length > 19) {
      return 'Card number must be 13-19 digits';
    }
    // Basic Luhn algorithm check (optional but recommended)
    if (!_luhnCheck(digitsOnly)) {
      return 'Invalid card number';
    }
    return null;
  }

  /// Validates card expiry: MM/YY format, MM must be 01-12, YY must be current year or later
  static String? cardExpiry(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter expiry date';
    
    // Check format MM/YY
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) {
      return 'Enter expiry as MM/YY';
    }
    
    final parts = v.split('/');
    final mm = int.tryParse(parts[0]);
    final yy = int.tryParse(parts[1]);
    
    if (mm == null || yy == null) {
      return 'Invalid expiry date';
    }
    
    // Validate month (01-12)
    if (mm < 1 || mm > 12) {
      return 'Month must be 01-12';
    }
    
    // Validate year (not expired)
    final now = DateTime.now();
    final currentYear = now.year % 100; // Last 2 digits
    final currentMonth = now.month;
    
    if (yy < currentYear || (yy == currentYear && mm < currentMonth)) {
      return 'Card has expired';
    }
    
    // Check if year is too far in future (e.g., more than 20 years)
    if (yy > currentYear + 20) {
      return 'Invalid expiry year';
    }
    
    return null;
  }

  /// Validates CVV: 3-4 digits
  static String? cardCvv(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter CVV';
    if (!RegExp(r'^\d{3,4}$').hasMatch(v)) {
      return 'CVV must be 3-4 digits';
    }
    return null;
  }

  /// Validates cardholder name: letters and spaces only, 2-50 characters
  static String? cardName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter name on card';
    if (v.length < 2) return 'Name too short';
    if (v.length > 50) return 'Name too long';
    if (!RegExp(r'^[A-Za-z\s]+$').hasMatch(v)) {
      return 'Use letters and spaces only';
    }
    return null;
  }

  /// Luhn algorithm for card number validation
  static bool _luhnCheck(String cardNumber) {
    int sum = 0;
    bool alternate = false;
    
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);
      
      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }
      
      sum += digit;
      alternate = !alternate;
    }
    
    return (sum % 10) == 0;
  }
}

/// Currency input formatter for price fields with ₹ symbol.
/// Allows only numbers with optional ₹ prefix.
class CurrencyInputFormatter extends TextInputFormatter {
  final double? maxValue;
  
  CurrencyInputFormatter({this.maxValue});
  
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    // Allow ₹ symbol
    String text = newValue.text.replaceAll('₹', '').trim();
    
    // Allow only digits
    text = text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Apply max value limit if specified
    if (maxValue != null && text.isNotEmpty) {
      final double? value = double.tryParse(text);
      if (value != null && value > maxValue!) {
        text = maxValue!.toStringAsFixed(0);
      }
    }
    
    // Build the new text with ₹ prefix
    final newText = text.isEmpty ? '' : '₹ $text';
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Card number formatter: adds spaces every 4 digits, max 19 characters (16 digits + 3 spaces)
/// Example: "1234567812345678" -> "1234 5678 1234 5678"
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove all non-digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 16 digits (standard card length)
    if (digitsOnly.length > 16) {
      digitsOnly = digitsOnly.substring(0, 16);
    }
    
    // Add spaces every 4 digits
    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted.write(' ');
      }
      formatted.write(digitsOnly[i]);
    }
    
    String newText = formatted.toString();
    
    // Calculate cursor position
    int cursorPosition = newText.length;
    if (oldValue.text.length < newValue.text.length) {
      // User is typing forward
      cursorPosition = newText.length;
    } else {
      // User is deleting
      cursorPosition = newValue.selection.baseOffset.clamp(0, newText.length);
    }
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

/// Expiry date formatter: formats as MM/YY, auto-inserts '/', validates MM <= 12
/// Example: "1225" -> "12/25"
class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove all non-digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 4 digits (MMYY)
    if (digitsOnly.length > 4) {
      digitsOnly = digitsOnly.substring(0, 4);
    }
    
    String formatted = digitsOnly;
    
    // Validate and format MM
    if (digitsOnly.length >= 2) {
      final mm = int.tryParse(digitsOnly.substring(0, 2));
      if (mm != null) {
        // If MM > 12, cap it at 12
        if (mm > 12) {
          formatted = '12${digitsOnly.length > 2 ? digitsOnly.substring(2) : ''}';
        }
        // If MM is 0, set to 01
        if (mm == 0) {
          formatted = '01${digitsOnly.length > 2 ? digitsOnly.substring(2) : ''}';
        }
      }
      
      // Add '/' after MM if we have at least 2 digits
      if (formatted.length >= 2) {
        formatted = '${formatted.substring(0, 2)}/${formatted.length > 2 ? formatted.substring(2) : ''}';
      }
    }
    
    // Calculate cursor position
    int cursorPosition = formatted.length;
    if (oldValue.text.length > newValue.text.length) {
      // User is deleting - maintain cursor position relative to the change
      int deletedChars = oldValue.text.length - newValue.text.length;
      cursorPosition = (oldValue.selection.baseOffset - deletedChars).clamp(0, formatted.length);
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

/// CVV formatter: allows only 3-4 digits
class CardCvvInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove all non-digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Limit to 4 digits (some cards have 4-digit CVV)
    if (digitsOnly.length > 4) {
      digitsOnly = digitsOnly.substring(0, 4);
    }
    
    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}