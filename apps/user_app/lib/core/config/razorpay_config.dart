/// Razorpay configuration constants
/// 
/// IMPORTANT SECURITY NOTES:
/// - For testing: Use test keys (rzp_test_*)
/// - For production: Use live keys (rzp_live_*)
/// - The keySecret should NEVER be exposed client-side in production
/// - Server-side order creation uses Supabase secrets (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET)
class RazorpayConfig {
  // Test keys for development/testing
  static const String keyId = 'rzp_test_S2uH90Th96A4h7';
  // Note: keySecret is not used client-side - order creation happens server-side via Edge Function
  // The Edge Function uses RAZORPAY_KEY_SECRET from Supabase secrets
  static const String keySecret = ''; // Not used client-side
  
  // App configuration
  static const String appName = 'Saral Events';
  static const String currency = 'INR';
  static const String themeColor = '#FDBB42';
  
  // Payment configuration
  static const bool autoCapture = true;
  static const int timeout = 300; // 5 minutes
  
  // Validation
  // Note: keySecret is not validated here as it's only used server-side
  static bool get isConfigured => keyId.isNotEmpty;
  
  /// Validates the configuration
  static void validate() {
    if (!isConfigured) {
      throw Exception('Razorpay configuration is incomplete: keyId is required');
    }
    
    if (!keyId.startsWith('rzp_test_') && !keyId.startsWith('rzp_live_')) {
      throw Exception('Invalid Razorpay Key ID format. Must start with rzp_test_ or rzp_live_');
    }
  }
}
