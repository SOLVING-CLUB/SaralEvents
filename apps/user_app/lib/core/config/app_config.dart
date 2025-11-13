/// App configuration for deep linking and universal links
class AppConfig {
  // Update this to your actual domain when deploying
  // For development: use ngrok or your local server
  // For production: use your actual domain (e.g., saralevents.vercel.app)
  static const String baseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'https://saralevents.vercel.app',
  );

  static String get inviteBaseUrl => '$baseUrl/invite';
  static String get referBaseUrl => '$baseUrl/refer';
  static String get serviceBaseUrl => '$baseUrl/service';
}

