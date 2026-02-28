class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;
  final int? statusCode;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
    this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.success(
      {required String message, T? data, int? statusCode}) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      statusCode: statusCode ?? 200,
    );
  }

  factory ApiResponse.error(
      {required String message, dynamic error, int? statusCode, T? data}) {
    return ApiResponse<T>(
      success: false,
      message: message,
      error: error,
      statusCode: statusCode ?? 500,
      data: data,
    );
  }

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic) fromJson) {
    try {
      return ApiResponse<T>(
        success: json['success'] ?? false,
        message: json['message']?.toString() ?? '',
        data: json['data'] != null ? fromJson(json['data']) : null,
        error: json['error'],
        statusCode: json['statusCode'],
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Failed to parse response: $e',
        error: e,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'error': error,
      'statusCode': statusCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get hasData => data != null;
  bool get hasError => error != null;

  ApiResponse<R> map<R>(R Function(T) mapper) {
    if (data == null) {
      return ApiResponse<R>(
        success: success,
        message: message,
        error: error,
        statusCode: statusCode,
        timestamp: timestamp,
      );
    }

    return ApiResponse<R>(
      success: success,
      message: message,
      data: mapper(data as T),
      error: error,
      statusCode: statusCode,
      timestamp: timestamp,
    );
  }

  T getDataOrThrow() {
    if (!success) throw ApiError.fromResponse(this);
    if (data == null) throw ApiError(message: 'No data available');
    return data as T;
  }

  T? getDataOrNull() => success ? data : null;

  @override
  String toString() =>
      'ApiResponse{success: $success, message: $message, hasData: ${data != null}, statusCode: $statusCode}';
}

class ApiError {
  final String message;
  final int? statusCode;
  final dynamic data;
  final String? action;
  final DateTime timestamp;

  ApiError({
    required this.message,
    this.statusCode,
    this.data,
    this.action,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ApiError: $message (${statusCode ?? 'No status code'})';

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message']?.toString() ?? 'Unknown error',
      statusCode: json['statusCode'],
      data: json['data'],
      action: json['action'],
    );
  }

  factory ApiError.fromResponse(ApiResponse response) {
    return ApiError(
      message: response.message,
      statusCode: response.statusCode,
      data: response.data,
    );
  }

  factory ApiError.networkError() {
    return ApiError(
        message: 'Network error. Please check your connection.', statusCode: 0);
  }

  factory ApiError.timeoutError() {
    return ApiError(
        message: 'Request timeout. Please try again.', statusCode: 408);
  }

  factory ApiError.unauthorized() {
    return ApiError(
        message: 'Unauthorized. Please login again.', statusCode: 401);
  }

  factory ApiError.notFound() {
    return ApiError(message: 'Resource not found.', statusCode: 404);
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'statusCode': statusCode,
      'data': data,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isNetworkError => statusCode == 0 || message.contains('Network');
  bool get isTimeout => statusCode == 408 || message.contains('timeout');
  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  String get userFriendlyMessage {
    if (isNetworkError)
      return 'Network error. Please check your internet connection.';
    if (isTimeout) return 'Request took too long. Please try again.';
    if (isUnauthorized) return 'Your session has expired. Please login again.';
    if (isNotFound) return 'The requested resource was not found.';
    if (isServerError) return 'Server error. Please try again later.';
    return message;
  }

  bool requiresAction() => action != null && action!.isNotEmpty;
}

class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrevious;

  PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginatedResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic) fromJson) {
    final itemsData = json['items'] ?? json['data'] ?? [];
    final items = List<T>.from(itemsData.map((x) => fromJson(x)));

    return PaginatedResponse<T>(
      items: items,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalItems: json['total_items'] ?? items.length,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }

  Map<String, dynamic> toJson(T Function(T) toJson) {
    return {
      'items': items.map((x) => toJson(x)).toList(),
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;
}
