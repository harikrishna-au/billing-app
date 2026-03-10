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
    // Only log in debug builds — avoids sensitive data in production logs.
    assert(() {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
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
    // Don't retry if this is already a login or refresh request
    if (err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.path.contains('/auth/machine-login')) {
      // Clear tokens on auth failure
      await _tokenManager.clearAll();
      return handler.next(err);
    }

    // Handle 401 Unauthorized - try to refresh token
    if (err.response?.statusCode == 401) {
      final refreshToken = _tokenManager.getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Attempt to refresh token
          final response = await _dio.post(
            ApiConstants.refresh,
            data: {'refresh_token': refreshToken},
          );

          if (response.statusCode == 200) {
            final newAccessToken = response.data['accessToken'] as String?;
            final newRefreshToken = response.data['refreshToken'] as String?;

            if (newAccessToken != null) {
              await _tokenManager.saveAccessToken(newAccessToken);
              if (newRefreshToken != null) {
                await _tokenManager.saveRefreshToken(newRefreshToken);
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
          // Refresh failed, clear tokens
          await _tokenManager.clearAll();
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
          message: err.message ?? 'Network error occurred',
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
