class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final Map<String, dynamic>? errors;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errors,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? true,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      errors: json['errors'] as Map<String, dynamic>?,
      statusCode: json['statusCode'] as int?,
    );
  }

  bool get isSuccess => success && statusCode != null && statusCode! < 400;
  bool get hasData => data != null;
}

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dataList = (json['data'] as List?)
            ?.map((item) => fromJsonT(item as Map<String, dynamic>))
            .toList() ??
        [];

    return PaginatedResponse<T>(
      data: dataList,
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 10,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  bool get hasMore => page < totalPages;
  bool get isEmpty => data.isEmpty;
}
