import '../core/config/app_config.dart';

/// Helper class for generating deep links in various formats
class DeepLinkHelper {
  static const String packageName = 'com.mycompany.saralevents';
  static const String customScheme = 'saralevents';

  /// Generate invitation universal link (https://)
  static String invitationUniversalLink(String slug) {
    return '${AppConfig.baseUrl}/invite/$slug';
  }

  /// Generate referral universal link (https://)
  static String referralUniversalLink(String code) {
    return '${AppConfig.baseUrl}/refer?code=$code';
  }

  /// Generate service universal link (https://)
  static String serviceUniversalLink(String serviceId) {
    return '${AppConfig.baseUrl}/service/$serviceId';
  }

  /// Generate invitation deep link (custom scheme)
  static String invitationLink(String slug) {
    return '$customScheme://invite/$slug';
  }

  /// Generate referral deep link (custom scheme)
  static String referralLink(String code) {
    return '$customScheme://refer/$code';
  }

  /// Generate service deep link (custom scheme)
  static String serviceLink(String serviceId) {
    return '$customScheme://service/$serviceId';
  }

  /// Generate Android Intent URL (works better in Chrome)
  /// Format: intent://path#Intent;scheme=customScheme;package=packageName;end
  static String androidIntentUrl(String path, {String? fallbackUrl}) {
    final intent = StringBuffer('intent://$path#Intent;');
    intent.write('scheme=$customScheme;');
    intent.write('package=$packageName;');
    if (fallbackUrl != null) {
      intent.write('S.browser_fallback_url=${Uri.encodeComponent(fallbackUrl)};');
    }
    intent.write('end');
    return intent.toString();
  }

  /// Generate invitation Android Intent URL
  static String invitationIntentUrl(String slug, {String? fallbackUrl}) {
    return androidIntentUrl('invite/$slug', fallbackUrl: fallbackUrl);
  }

  /// Generate referral Android Intent URL
  static String referralIntentUrl(String code, {String? fallbackUrl}) {
    return androidIntentUrl('refer/$code', fallbackUrl: fallbackUrl);
  }

  /// Generate service Android Intent URL
  static String serviceIntentUrl(String serviceId, {String? fallbackUrl}) {
    return androidIntentUrl('service/$serviceId', fallbackUrl: fallbackUrl);
  }

  /// Generate shareable text with universal link (works everywhere)
  static String shareableText({
    required String title,
    String? date,
    String? time,
    String? venue,
    required String universalLink,
    String? deepLink,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🎉 $title');
    buffer.writeln();
    
    if (date != null) buffer.writeln('Date: $date');
    if (time != null) buffer.writeln('Time: $time');
    if (venue != null) buffer.writeln('Venue: $venue');
    
    buffer.writeln();
    buffer.writeln('Open invitation:');
    buffer.writeln(universalLink);
    
    if (deepLink != null) {
      buffer.writeln();
      buffer.writeln('Or open directly in app:');
      buffer.writeln(deepLink);
    }
    
    buffer.writeln();
    buffer.writeln('Tap the link above to open in Saral Events app!');
    
    return buffer.toString();
  }
}

