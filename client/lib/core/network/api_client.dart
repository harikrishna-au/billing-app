import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'token_manager.dart';
import 'api_exception.dart';

class ApiClient {
  late final Dio _dio;
  final TokenManager _tokenManager;

  ApiClient(this._tokenManager) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        // Generous timeouts to handle Render cold-starts (30–60s).
        connectTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          ApiConstants.contentType: ApiConstants.applicationJson,
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(_tokenManager, _dio));
    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(_ErrorInterceptor());
    // Debug-only: never log bodies — login/password and tokens would appear in Logcat.
    assert(() {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ));
      return true;
    }());
  }

  Dio get dio => _dio;

  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }
}

/// Retry Interceptor — retries idempotent GET requests on transient failures.
/// POST/PUT/PATCH/DELETE are never retried to avoid duplicate side-effects.
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const _maxRetries = 2;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final method = err.requestOptions.method.toUpperCase();
    final isGet = method == 'GET';
    final isTransient = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.unknown;

    if (!isGet || !isTransient) return handler.next(err);

    final retries = (err.requestOptions.extra['_retries'] as int? ?? 0);
    if (retries >= _maxRetries) return handler.next(err);

    // Exponential backoff: 1s, 2s
    await Future.delayed(Duration(seconds: retries + 1));
    err.requestOptions.extra['_retries'] = retries + 1;

    try {
      final response = await _dio.fetch(err.requestOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}

String _friendlyConnectionMessage(DioException err) {
  final raw = err.message ?? '';
  final inner = err.error?.toString() ?? '';
  if (raw.contains('Failed host lookup') ||
      inner.contains('Failed host lookup')) {
    return 'Cannot find server host. Check Wi‑Fi/mobile data, DNS, and API URL '
        '(${ApiConstants.baseUrl}).';
  }
  if (raw.contains('Network is unreachable') ||
      inner.contains('Network is unreachable')) {
    return 'Network unreachable. Turn on Wi‑Fi or mobile data and try again.';
  }
  if (raw.contains('CERTIFICATE_VERIFY_FAILED') ||
      raw.contains('HandshakeException')) {
    return 'Secure connection failed. Check this device’s date and time.';
  }
  if (raw.isNotEmpty) return raw;
  return 'Network error occurred';
}

/// Parses `{ success, data: { access_token, ... } }` or flat `{ access_token }`.
Map<String, dynamic>? _parseJsonMap(dynamic body) {
  if (body is! Map) return null;
  final map = Map<String, dynamic>.from(body);
  final inner = map['data'];
  if (inner is Map) return Map<String, dynamic>.from(inner);
  return map;
}

/// Auth Interceptor - Adds token to requests and handles token refresh
class _AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;
  final Dio _dio;

  _AuthInterceptor(this._tokenManager, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Skip auth for login and refresh endpoints
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/machine-login') ||
        options.path.contains('/auth/refresh')) {
      return handler.next(options);
    }

    final token = _tokenManager.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[ApiConstants.authHeader] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Auth endpoints: only wipe the session on real auth rejection (401/403),
    // not on timeouts/network blips — otherwise one failed Razorpay/order call
    // could leave the user "logged out" for Cash/UPI on the same checkout.
    if (err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.path.contains('/auth/machine-login')) {
      final code = err.response?.statusCode;
      if (code == 401 || code == 403) {
        await _tokenManager.clearAll();
      }
      return handler.next(err);
    }

    // Handle 401 Unauthorized - try to refresh token
    if (err.response?.statusCode == 401) {
      final refreshToken = _tokenManager.getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Attempt to refresh token (must match backend: data.access_token)
          final response = await _dio.post(
            ApiConstants.refresh,
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200) {
            final data = _parseJsonMap(response.data);
            final newAccessToken = data?['access_token'] as String? ??
                data?['accessToken'] as String?;
            final newRefreshToken = data?['refresh_token'] as String? ??
                data?['refreshToken'] as String?;
            final expiresIn = data?['expires_in'] as int?;

            if (newAccessToken != null) {
              await _tokenManager.saveAccessToken(newAccessToken);
              if (newRefreshToken != null) {
                await _tokenManager.saveRefreshToken(newRefreshToken);
              }
              if (expiresIn != null) {
                await _tokenManager.saveTokenExpiry(
                  DateTime.now().add(Duration(seconds: expiresIn)),
                );
              }

              // Retry the original request
              final opts = Options(
                method: err.requestOptions.method,
                headers: {
                  ...err.requestOptions.headers,
                  ApiConstants.authHeader: 'Bearer $newAccessToken',
                },
              );

              final cloneReq = await _dio.request(
                err.requestOptions.path,
                options: opts,
                data: err.requestOptions.data,
                queryParameters: err.requestOptions.queryParameters,
              );

              return handler.resolve(cloneReq);
            }
          }
        } catch (e) {
          if (e is DioException &&
              (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
            await _tokenManager.clearAll();
          }
        }
      } else {
        // No refresh token available, clear all tokens
        await _tokenManager.clearAll();
      }
    }

    handler.next(err);
  }
}

/// Error Interceptor - Converts Dio errors to custom exceptions
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ApiException exception;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = NetworkException(message: 'Connection timeout');
        break;

      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        // FastAPI uses 'detail' for error messages; some backends use 'message'
        final responseData = err.response?.data;
        final message = (responseData is Map)
            ? (responseData['message'] as String? ??
                responseData['detail'] as String? ??
                'Request failed')
            : 'Request failed';
        final errors = (responseData is Map)
            ? responseData['errors'] as Map<String, dynamic>?
            : null;

        if (statusCode == 401) {
          exception = UnauthorizedException(message: message);
        } else if (statusCode == 400) {
          exception = ValidationException(message: message, errors: errors);
        } else {
          exception = ApiException(
            message: message,
            statusCode: statusCode,
            errors: errors,
          );
        }
        break;

      case DioExceptionType.cancel:
        exception = ApiException(message: 'Request cancelled');
        break;

      case DioExceptionType.unknown:
      default:
        exception = NetworkException(
          message: _friendlyConnectionMessage(err),
        );
        break;
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        response: err.response,
        type: err.type,
      ),
    );
  }
}
