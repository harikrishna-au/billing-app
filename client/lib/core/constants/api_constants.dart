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
  static const String login = '/auth/login';
  static const String machineLogin = '/auth/machine-login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Machine Endpoints
  static const String machines = '/machines';
  static String machineById(String id) => '/machines/$id';
  static String machineServices(String machineId) =>
      '/machines/$machineId/services';
  static String machineServicesActive(String machineId) =>
      '/machines/$machineId/services/active';
  static String machinePayments(String machineId) =>
      '/machines/$machineId/payments';

  // Service Endpoints
  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';

  // Payment Endpoints
  static const String payments = '/payments';
  static String paymentById(String id) => '/payments/$id';
  static String paymentsByMachine(String machineId) =>
      '/machines/$machineId/payments';

  // Analytics Endpoints
  static const String analytics = '/analytics';
  static const String dashboard = '/dashboard';

  // Logs Endpoints
  static const String logs = '/logs';
  static const String catalogHistory = '/catalog-history';
  static String catalogue(String machineId) => '/machines/$machineId/catalogue';

  // Headers
  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
}
