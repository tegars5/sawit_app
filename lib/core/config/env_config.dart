
class EnvConfig {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Backend API Base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://unpensionable-zander-unmotioned.ngrok-free.dev/api',
  );

  /// Check if all required environment variables are set
  static bool get isConfigured {
    return googleMapsApiKey.isNotEmpty;
  }

  /// Validate configuration and throw error if missing required values
  static void validate() {
    if (googleMapsApiKey.isEmpty) {
      throw Exception(
        'GOOGLE_MAPS_API_KEY is not set. Please check your .env file.',
      );
    }
  }
}
