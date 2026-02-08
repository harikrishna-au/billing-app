class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
    this.originalError,
  });

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return 'ApiException: $message (${errors!.keys.join(', ')})';
    }
    return 'ApiException: $message';
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => statusCode == null;
}

class NetworkException extends ApiException {
  NetworkException({String? message})
      : super(
          message: message ?? 'No internet connection',
          statusCode: null,
        );
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message})
      : super(
          message: message ?? 'Unauthorized access',
          statusCode: 401,
        );
}

class ValidationException extends ApiException {
  ValidationException({
    String? message,
    super.errors,
  }) : super(
          message: message ?? 'Validation failed',
          statusCode: 400,
        );
}
