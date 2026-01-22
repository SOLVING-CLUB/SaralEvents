import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/razorpay_config.dart';

/// Enhanced Razorpay service with production-ready features
/// 
/// Features:
/// - Secure credential management
/// - Comprehensive error handling
/// - Payment verification
/// - Order management
/// - Logging and debugging
class RazorpayService {
  Razorpay? _razorpay;
  void Function(String paymentId, Map<String, dynamic> response)? onSuccess;
  void Function(String code, String message, Map<String, dynamic>? response)? onError;
  void Function(String walletName)? onExternalWallet;

  bool get isInitialized => _razorpay != null;

  /// Initialize Razorpay with enhanced callback handling
  void init({
    required void Function(String paymentId, Map<String, dynamic> response) onSuccess,
    required void Function(String code, String message, Map<String, dynamic>? response) onError,
    void Function(String walletName)? onExternalWallet,
  }) {
    try {
      // Validate configuration before initialization
      RazorpayConfig.validate();
      
      dispose();
      _razorpay = Razorpay();
      this.onSuccess = onSuccess;
      this.onError = onError;
      this.onExternalWallet = onExternalWallet;

      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      
      if (kDebugMode) {
        debugPrint('Razorpay initialized successfully with key: ${RazorpayConfig.keyId}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize Razorpay: $e');
      }
      rethrow;
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Create order using Edge Function (server-side)
  Future<Map<String, dynamic>> createOrderOnServer({
    required int amountInPaise,
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final client = Supabase.instance.client;
      final res = await client.functions.invoke(
        'create_razorpay_order',
        body: jsonEncode({
          'amount': amountInPaise,
          'currency': currency,
          'receipt': receipt,
          'notes': notes ?? {},
          'payment_capture': RazorpayConfig.autoCapture ? 1 : 0,
        }),
      );
      
      if (res.status == 200) {
        final orderData = res.data as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('✅ Order created via Edge Function: ${orderData['id']}');
        }
        return orderData;
      } else {
        // Edge Function returned an error status
        final errorData = res.data;
        final errorMessage = errorData is Map<String, dynamic>
            ? (errorData['error'] as String? ?? errorData['details'] as String? ?? 'Unknown error')
            : 'Edge Function returned status ${res.status}';
        
        if (kDebugMode) {
          debugPrint('❌ Edge Function error (status ${res.status}): $errorMessage');
          debugPrint('Response data: $errorData');
        }
        
        throw Exception('Failed to create payment order: $errorMessage');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating order via Edge Function: $e');
      }
      // Re-throw with a more helpful message
      if (e.toString().contains('Edge Function')) {
        rethrow;
      }
      throw Exception('Failed to create payment order. Please check your internet connection and try again. Error: ${e.toString()}');
    }
  }

  /// Open Razorpay checkout with enhanced configuration
  void openCheckout({
    required int amountInPaise,
    required String name,
    required String description,
    required String orderId,
    String? currency,
    String? prefillName,
    String? prefillEmail,
    String? prefillContact,
    Map<String, dynamic>? notes,
  }) {
    if (_razorpay == null) {
      throw StateError('Razorpay not initialized. Call init() first.');
    }
    
    try {
      final options = {
        'key': RazorpayConfig.keyId,
        'amount': amountInPaise,
        'currency': currency ?? RazorpayConfig.currency,
        'name': name,
        'description': description,
        'order_id': orderId,
        'prefill': {
          if (prefillName != null && prefillName.isNotEmpty) 'name': prefillName,
          if (prefillEmail != null && prefillEmail.isNotEmpty) 'email': prefillEmail,
          if (prefillContact != null && prefillContact.isNotEmpty) 'contact': prefillContact,
        },
        'notes': notes ?? {},
        'theme': {'color': RazorpayConfig.themeColor},
        'timeout': RazorpayConfig.timeout,
      };
      
      if (kDebugMode) {
        debugPrint('Opening Razorpay checkout with options: ${jsonEncode(options)}');
      }
      
      _razorpay!.open(options);
      
      if (kDebugMode) {
        debugPrint('✅ Razorpay.open() called successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error opening Razorpay checkout: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Handle payment success with enhanced response data
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    try {
      if (kDebugMode) {
        debugPrint('Payment successful: ${response.paymentId}');
        debugPrint('Order ID: ${response.orderId}');
        debugPrint('Signature: ${response.signature}');
      }
      
      final responseData = {
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      onSuccess?.call(response.paymentId ?? '', responseData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling payment success: $e');
      }
      onError?.call('SUCCESS_HANDLER_ERROR', 'Failed to process payment success', null);
    }
  }

  /// Handle payment error with enhanced error information
  void _handlePaymentError(PaymentFailureResponse response) {
    try {
      if (kDebugMode) {
        debugPrint('Payment failed: Code=${response.code}, Message=${response.message}');
      }
      
      final errorData = {
        'code': response.code,
        'message': response.message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      onError?.call('${response.code}', response.message ?? 'Payment failed', errorData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling payment failure: $e');
      }
      onError?.call('ERROR_HANDLER_ERROR', 'Failed to process payment error', null);
    }
  }

  /// Handle external wallet selection
  void _handleExternalWallet(ExternalWalletResponse response) {
    try {
      if (kDebugMode) {
        debugPrint('External wallet selected: ${response.walletName}');
      }
      
      onExternalWallet?.call(response.walletName ?? 'Unknown Wallet');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling external wallet: $e');
      }
    }
  }
  
  /// Verify payment signature (should be called on server side)
  /// This is a client-side helper - actual verification should be done server-side
  static bool verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    // Note: In production, this verification should be done on the server
    // This is just a placeholder for client-side validation
    if (kDebugMode) {
      debugPrint('Payment signature verification (client-side):');
      debugPrint('Order ID: $orderId');
      debugPrint('Payment ID: $paymentId');
      debugPrint('Signature: $signature');
    }
    
    // Return true for now - actual verification should be server-side
    return true;
  }
}


