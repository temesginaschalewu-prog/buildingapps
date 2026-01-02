class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJson(json['data']) : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'error': error,
    };
  }
}

class ApiError implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final String? action;

  ApiError({
    required this.message,
    this.statusCode,
    this.data,
    this.action,
  });

  @override
  String toString() => 'ApiError: $message (${statusCode ?? 'No status code'})';

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message'] ?? 'Unknown error',
      statusCode: json['statusCode'],
      data: json['data'],
      action: json['action'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'statusCode': statusCode,
      'data': data,
      'action': action,
    };
  }
}
