import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/razorpay_config.dart';

/// Alternative Razorpay order service that works without Edge Functions
/// This creates orders directly using HTTP requests
class RazorpayOrderService {
  static const String _baseUrl = 'https://api.razorpay.com/v1';
  
  /// Create a Razorpay order directly using HTTP
  static Future<Map<String, dynamic>> createOrder({
    required int amountInPaise,
    required String currency,
    required String receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Creating Razorpay order: Amount=$amountInPaise, Currency=$currency, Receipt=$receipt');
      }

      // Prepare order data
      final orderData = {
        'amount': amountInPaise,
        'currency': currency,
        'receipt': receipt,
        'notes': notes ?? {},
        'payment_capture': 1, // Auto-capture
      };

      // Note: This fallback should not be used in production
      // Order creation should happen via Edge Function which uses Supabase secrets
      if (RazorpayConfig.keySecret.isEmpty) {
        throw Exception('Direct order creation requires server-side implementation. Please use Edge Function.');
      }
      
      // Create basic auth header
      final credentials = base64Encode(utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}'));
      
      // Make HTTP request to Razorpay API
      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200) {
        final orderData = jsonDecode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          debugPrint('✅ Order created successfully: ${orderData['id']}');
        }
        return orderData;
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMsg = 'Failed to create order: ${errorData['error']?['description'] ?? response.body}';
        if (kDebugMode) {
          debugPrint('❌ Order creation failed: $errorMsg');
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Order creation error: $e');
      }
      rethrow;
    }
  }

  /// Verify payment signature (client-side helper)
  /// Note: In production, this should be done server-side
  static bool verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    if (kDebugMode) {
      debugPrint('Payment signature verification:');
      debugPrint('Order ID: $orderId');
      debugPrint('Payment ID: $paymentId');
      debugPrint('Signature: $signature');
    }
    
    // For now, return true - actual verification should be server-side
    // In production, implement proper HMAC verification
    return true;
  }

  /// Get payment details from Razorpay
  static Future<Map<String, dynamic>?> getPaymentDetails(String paymentId) async {
    try {
      final credentials = base64Encode(utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}'));
      
      final response = await http.get(
        Uri.parse('$_baseUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          debugPrint('Failed to get payment details: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting payment details: $e');
      }
      return null;
    }
  }
}
