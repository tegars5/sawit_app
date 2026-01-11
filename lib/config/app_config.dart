class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://192.168.1.7:8000/api';

  static const int requestTimeout = 30;
  static const int pageSize = 15;
  static const int trackingPollInterval = 10; // seconds

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String fcmTokenKey = 'fcm_token';

  // App Info
  static const String appName = 'Cangkang Sawit';
  static const String appVersion = '1.0.0';

  // Warehouse Location (for distance calculation)
  static const double warehouseLat = -6.200000;
  static const double warehouseLng = 106.800000;
}
