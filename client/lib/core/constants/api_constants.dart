import 'dart:io';

/// API Configuration for Backend
class ApiConstants {
  // Base URL - Backend running on localhost (10.0.2.2 for Android Emulator)
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/v1';
    }
    return 'http://localhost:8000/v1';
  }

  // Auth Endpoints
  static const String login = '/auth/machine-login';  // Machine login for client app
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Service Endpoints
  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';

  // Payment Endpoints
  static const String payments = '/payments';
  static String paymentById(String id) => '/payments/$id';

  // Product Endpoints
  static const String products = '/products';

  // Analytics Endpoints
  static const String analytics = '/analytics';
  static const String dashboard = '/dashboard';

  // Logs Endpoints
  static const String logs = '/logs';
  static const String catalogHistory = '/catalog-history';

  // Headers
  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
}
