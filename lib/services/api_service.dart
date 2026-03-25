import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:familyacademyclient/utils/platform_helper.dart';

import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/exam_question_model.dart';
import 'package:familyacademyclient/models/exam_result_model.dart';
import 'package:familyacademyclient/models/notification_model.dart';
import 'package:familyacademyclient/models/parent_link_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/models/setting_model.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/utils/constants.dart' show AppConstants;
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/services/offline_queue_manager.dart';

import '../models/chapter_model.dart';
import '../models/course_model.dart';
import '../models/note_model.dart';
import '../models/question_model.dart';
import '../models/video_model.dart';
import '../models/chatbot_model.dart';
import '../utils/api_response.dart';

class _HttpJsonResult {
  final int statusCode;
  final dynamic data;

  const _HttpJsonResult({
    required this.statusCode,
    required this.data,
  });
}

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRefreshingToken = false;
  SharedPreferences? _prefs;
  Future<void>? _prefsInitFuture;
  final HttpClient _httpClient = HttpClient();

  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;
  static const int _baseRetryDelaySeconds = 2;

  final StreamController<Map<String, dynamic>> _deviceDeactivationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceDeactivationStream =>
      _deviceDeactivationController.stream;

  bool _hasNetworkConnection = true;
  bool get hasNetworkConnection => _hasNetworkConnection;

  OfflineQueueManager? _offlineQueueManager;

  Dio get dio => _dio;

  static const int _connectTimeout = 45;
  static const int _receiveTimeout = 45;
  static const int _sendTimeout = 45;

  static const String _apiPrefix = '/api/v1';

  ApiService() {
    _httpClient.connectionTimeout = const Duration(seconds: _connectTimeout);
    _httpClient.idleTimeout = const Duration(seconds: _receiveTimeout);

    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: _connectTimeout),
        receiveTimeout: const Duration(seconds: _receiveTimeout),
        sendTimeout: const Duration(seconds: _sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': AppConstants.appVersion,
          'X-Client-Platform': 'mobile',
        },
        validateStatus: (status) => status! < 500,
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  void setOfflineQueueManager(OfflineQueueManager manager) {
    _offlineQueueManager = manager;
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs != null) return _prefs!;
    _prefsInitFuture ??= _initSharedPreferences();
    await _prefsInitFuture;
    return _prefs!;
  }

  Future<String?> _readToken() async {
    if (!PlatformHelper.isMobile) {
      final prefs = await _ensurePrefs();
      return prefs.getString(AppConstants.tokenKey);
    }
    return _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> _writeToken(String token) async {
    if (!PlatformHelper.isMobile) {
      final prefs = await _ensurePrefs();
      await prefs.setString(AppConstants.tokenKey, token);
      return;
    }
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> _readRefreshToken() async {
    if (!PlatformHelper.isMobile) {
      final prefs = await _ensurePrefs();
      return prefs.getString(AppConstants.refreshTokenKey);
    }
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> _writeRefreshToken(String refreshToken) async {
    if (!PlatformHelper.isMobile) {
      final prefs = await _ensurePrefs();
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
      return;
    }
    await _secureStorage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<void> _clearStoredTokens() async {
    if (!PlatformHelper.isMobile) {
      final prefs = await _ensurePrefs();
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove(AppConstants.refreshTokenKey);
      return;
    }
    await _secureStorage.deleteAll();
  }

  Future<String?> _getDeviceId() async {
    try {
      final prefs = await _ensurePrefs();
      if (Hive.isBoxOpen('device_info_box')) {
        final deviceInfoBox = Hive.box<Map<String, dynamic>>('device_info_box');
        if (deviceInfoBox.containsKey('current_device')) {
          final deviceInfo = deviceInfoBox.get('current_device');
          return deviceInfo?['device_id'] as String?;
        }
      } else {
        final deviceInfoBox =
            await Hive.openBox<Map<String, dynamic>>('device_info_box');
        if (deviceInfoBox.containsKey('current_device')) {
          final deviceInfo = deviceInfoBox.get('current_device');
          return deviceInfo?['device_id'] as String?;
        }
      }
      return prefs.getString(AppConstants.persistentDeviceIdKey);
    } catch (e) {
      debugLog('ApiService', 'Error getting device ID: $e');
      return null;
    }
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await _ensurePrefs();
    final token = await _readToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final deviceId = await _getDeviceId();
    if (deviceId != null && deviceId.isNotEmpty) {
      options.headers['X-Device-ID'] = deviceId;
    }

    final userData = prefs.getString(AppConstants.userDataKey);
    if (userData != null) {
      try {
        final userJson = json.decode(userData);
        final userId = userJson['id'];
        if (userId != null) options.headers['X-User-ID'] = userId.toString();
      } catch (e) {}
    }

    options.extra['retryCount'] = 0;

    if (kDebugMode) {
      debugLog('ApiService', '${options.method} ${options.path}');
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    _retryCounts.remove(response.requestOptions.path);
    _hasNetworkConnection = true;
    handler.next(response);
  }

  Future<void> _onError(
      DioException error, ErrorInterceptorHandler handler) async {
    debugLog('ApiService', '${error.type} - ${error.message}');

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      final options = error.requestOptions;
      final retryCount = options.extra['retryCount'] as int? ?? 0;

      if (retryCount < _maxRetries) {
        options.extra['retryCount'] = retryCount + 1;
        final delaySeconds = _baseRetryDelaySeconds * (1 << retryCount);

        debugLog('ApiService',
            '⏱️ Timeout, retrying (${retryCount + 1}/$_maxRetries) in ${delaySeconds}s');

        await Future.delayed(Duration(seconds: delaySeconds));

        try {
          final response = await _dio.fetch(options);
          handler.resolve(response);
          return;
        } catch (retryError) {
          debugLog('ApiService', 'Retry failed: $retryError');
        }
      }

      handler.resolve(Response(
        requestOptions: error.requestOptions,
        statusCode: -1,
        data: {
          'success': false,
          'message': getUserFriendlyErrorMessage(
              'Request timed out. Please check your connection and try again.'),
          'timeout': true,
        },
      ));
      return;
    }

    if (error.type == DioExceptionType.connectionError) {
      _hasNetworkConnection = false;

      if (_isWriteMethod(error.requestOptions.method)) {
        await _queueOfflineRequest(error.requestOptions);
        handler.resolve(Response(
          requestOptions: error.requestOptions,
          statusCode: 202,
          data: {
            'success': true,
            'message': 'Request queued for offline sync',
            'queued': true,
            'offline': true,
          },
        ));
        return;
      }

      handler.resolve(Response(
        requestOptions: error.requestOptions,
        statusCode: -1,
        data: {
          'success': false,
          'message': getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'),
          'offline': true,
        },
      ));
      return;
    }

    final path = error.requestOptions.path;
    final currentRetryCount = _retryCounts[path] ?? 0;

    if (error.response?.statusCode == 403) {
      final responseData = error.response?.data;
      if (responseData is Map &&
          responseData['action'] == 'device_deactivated') {
        _deviceDeactivationController.add({
          'message': responseData['message'] ?? 'Device deactivated',
          'action': 'device_deactivated',
          'forceLogout': true,
        });
        await _clearUserDataOnly();
        handler.resolve(Response(
          requestOptions: error.requestOptions,
          statusCode: 403,
          data: {
            'success': false,
            'message': responseData['message'] ?? 'Device deactivated',
            'action': 'device_deactivated',
            'forceLogout': true
          },
        ));
        return;
      }
    }

    if (error.response?.statusCode == 401) {
      if (!_isRefreshingToken) {
        _isRefreshingToken = true;
        try {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            final newToken = await _readToken();
            final newHeaders =
                Map<String, dynamic>.from(error.requestOptions.headers);
            newHeaders['Authorization'] = 'Bearer $newToken';
            try {
              final retryResponse = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: Options(
                  method: error.requestOptions.method,
                  headers: newHeaders,
                  contentType: error.requestOptions.contentType,
                  responseType: error.requestOptions.responseType,
                  receiveTimeout: error.requestOptions.receiveTimeout,
                  sendTimeout: error.requestOptions.sendTimeout,
                  extra: error.requestOptions.extra,
                  validateStatus: error.requestOptions.validateStatus,
                  followRedirects: error.requestOptions.followRedirects,
                  maxRedirects: error.requestOptions.maxRedirects,
                ),
              );
              handler.resolve(retryResponse);
              return;
            } catch (retryError) {
              debugLog('ApiService',
                  'Retry after token refresh failed: $retryError');
            }
          }
        } catch (e) {
          debugLog('ApiService', 'Error refreshing token: $e');
        } finally {
          _isRefreshingToken = false;
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        handler.next(error);
        return;
      }
    }

    if (error.response?.statusCode == 429 && currentRetryCount < _maxRetries) {
      _retryCounts[path] = currentRetryCount + 1;
      final delaySeconds = _baseRetryDelaySeconds * (1 << currentRetryCount);
      await Future.delayed(Duration(seconds: delaySeconds));
      try {
        final response = await _dio.request(
          error.requestOptions.path,
          data: error.requestOptions.data,
          queryParameters: error.requestOptions.queryParameters,
          options: Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers),
        );
        handler.resolve(response);
        return;
      } catch (retryError) {
        debugLog('ApiService', 'Retry failed after rate limit: $retryError');
      }
    }

    handler.next(error);
  }

  bool _isWriteMethod(String method) {
    return method.toUpperCase() == 'POST' ||
        method.toUpperCase() == 'PUT' ||
        method.toUpperCase() == 'PATCH' ||
        method.toUpperCase() == 'DELETE';
  }

  Future<void> _queueOfflineRequest(RequestOptions request) async {
    if (_offlineQueueManager == null) return;

    final prefs = await _ensurePrefs();
    final userId = await _readToken()
        .then((_) => prefs.getString(AppConstants.currentUserIdKey));

    if (userId == null) return;

    String actionType;
    switch (request.path) {
      case final path when path.contains('/progress/save'):
        actionType = AppConstants.queueActionSaveProgress;
        break;
      case final path when path.contains('/submit-exam'):
        actionType = AppConstants.queueActionSubmitExam;
        break;
      case final path when path.contains('/payments/submit'):
        actionType = AppConstants.queueActionSubmitPayment;
        break;
      case final path when path.contains('/notifications/read'):
        actionType = AppConstants.queueActionMarkNotificationRead;
        break;
      case final path when path.contains('/users/update-profile'):
        actionType = AppConstants.queueActionUpdateProfile;
        break;
      case final path when path.contains('/practice/check-answer'):
        actionType = AppConstants.queueActionSaveAnswer;
        break;
      case final path when path.contains('/chatbot/chat'):
        actionType = AppConstants.queueActionSendChatMessage;
        break;
      case final path when path.contains('/streak/update'):
        actionType = AppConstants.queueActionUpdateStreak;
        break;
      case final path when path.contains('/videos/'):
        actionType = AppConstants.queueActionIncrementViewCount;
        break;
      default:
        actionType = 'unknown';
    }

    _offlineQueueManager!.addItem(
      type: actionType,
      data: {
        'path': request.path,
        'method': request.method,
        'data': request.data,
        'queryParameters': request.queryParameters,
        'headers': request.headers,
        'userId': userId,
      },
    );
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _readRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '$_apiPrefix/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        await _writeToken(newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearUserDataOnly() async {
    final prefs = await _ensurePrefs();
    await _clearStoredTokens();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('user_') ||
          key == AppConstants.userDataKey ||
          key == AppConstants.sessionStartKey) {
        await prefs.remove(key);
      }
    }
  }

  Uri _buildApiUri(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final baseUri = Uri.parse(_dio.options.baseUrl);
    final resolved = baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );

    if (queryParameters == null || queryParameters.isEmpty) {
      return resolved;
    }

    final normalizedQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        normalizedQuery[key] = value.toString();
      }
    });

    return resolved.replace(queryParameters: normalizedQuery);
  }

  Future<Map<String, String>> _buildRequestHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Version': AppConstants.appVersion,
      'X-Client-Platform': 'mobile',
      'Connection': 'close',
    };

    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final deviceId = await _getDeviceId();
    if (deviceId != null && deviceId.isNotEmpty) {
      headers['X-Device-ID'] = deviceId;
    }

    final prefs = await _ensurePrefs();
    final userData = prefs.getString(AppConstants.userDataKey);
    if (userData != null) {
      try {
        final userJson = json.decode(userData) as Map<String, dynamic>;
        final userId = userJson['id'];
        if (userId != null) {
          headers['X-User-ID'] = userId.toString();
        }
      } catch (_) {}
    }

    return headers;
  }

  Future<_HttpJsonResult> _performHttpGetJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration timeout = const Duration(seconds: _receiveTimeout),
  }) async {
    final uri = _buildApiUri(path, queryParameters: queryParameters);
    final headers = await _buildRequestHeaders();

    debugLog('ApiService', 'HTTP GET $uri');

    final request = await _httpClient.getUrl(uri).timeout(timeout);
    headers.forEach(request.headers.set);

    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);

    debugLog(
      'ApiService',
      'HTTP GET $path completed with ${response.statusCode} and ${body.length} chars',
    );

    final decoded = _decodePlainJsonResponse(body, requestPath: path);

    final result = _HttpJsonResult(
      statusCode: response.statusCode,
      data: decoded,
    );
    debugLog(
      'ApiService',
      'HTTP GET $path returning result object with status ${result.statusCode}',
    );
    return result;
  }

  dynamic _decodePlainJsonResponse(
    dynamic rawData, {
    required String requestPath,
  }) {
    if (rawData == null) {
      debugLog('ApiService', 'Plain JSON decode for $requestPath got null body');
      return null;
    }

    if (rawData is Map || rawData is List) {
      return rawData;
    }

    if (rawData is String) {
      final trimmed = rawData.trim();
      debugLog(
        'ApiService',
        'Plain JSON decode for $requestPath received ${trimmed.length} chars',
      );

      if (trimmed.isEmpty) {
        return null;
      }

      return jsonDecode(trimmed);
    }

    if (rawData is List<int>) {
      final decoded = utf8.decode(rawData);
      return _decodePlainJsonResponse(decoded, requestPath: requestPath);
    }

    debugLog(
      'ApiService',
      'Plain JSON decode for $requestPath received unexpected type ${rawData.runtimeType}',
    );
    return rawData;
  }

  String _extractApiErrorMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      final rawMessage = data['message']?.toString();
      final errors = data['errors'];

      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;
        if (firstError is Map) {
          final msg = firstError['msg']?.toString() ??
              firstError['message']?.toString() ??
              firstError['error']?.toString();
          if (msg != null && msg.isNotEmpty) return msg;
        } else if (firstError != null) {
          final msg = firstError.toString();
          if (msg.isNotEmpty) return msg;
        }
      } else if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          final msg = firstValue.first.toString();
          if (msg.isNotEmpty) return msg;
        } else if (firstValue != null) {
          final msg = firstValue.toString();
          if (msg.isNotEmpty) return msg;
        }
      }

      if (rawMessage != null && rawMessage.isNotEmpty) {
        if (rawMessage.toLowerCase() == 'validation failed') {
          return 'Please check your details and try again.';
        }
        return rawMessage;
      }
    }

    return fallback;
  }

  // ===== AUTH ENDPOINTS =====
  Future<ApiResponse<Map<String, dynamic>>> register(String username,
      String password, String deviceId, String? fcmToken) async {
    try {
      final payload = <String, dynamic>{
        'username': username.trim(),
        'password': password,
      };
      final normalizedDeviceId = deviceId.trim();
      if (normalizedDeviceId.isNotEmpty) {
        payload['deviceId'] = normalizedDeviceId;
      }
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        payload['fcmToken'] = fcmToken.trim();
      }

      final response = await _dio.post(
        '$_apiPrefix/auth/register',
        data: payload,
      );

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Registration successful',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: _extractApiErrorMessage(
            response.data,
            'Registration failed',
          ),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'),
        );
      }
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: _extractApiErrorMessage(
          e.response?.data,
          'Registration failed',
        ),
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> studentLogin(String username,
      String password, String deviceId, String? fcmToken) async {
    try {
      final payload = <String, dynamic>{
        'username': username.trim(),
        'password': password,
      };
      final normalizedDeviceId = deviceId.trim();
      if (normalizedDeviceId.isNotEmpty) {
        payload['deviceId'] = normalizedDeviceId;
      }
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        payload['fcmToken'] = fcmToken.trim();
      }

      final response = await _dio.post(
        '$_apiPrefix/auth/student-login',
        data: payload,
      );

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data is! Map<String, dynamic>) {
          return ApiResponse<Map<String, dynamic>>(
            success: false,
            message: 'Invalid response format',
          );
        }

        await _writeToken(data['token']);
        if (data['deviceToken'] != null) {
          await _writeRefreshToken(data['deviceToken']);
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Login successful',
          data: Map<String, dynamic>.from(data),
        );
      } else {
        Map<String, dynamic>? errorPayload;
        String? action;

        if (response.data is Map) {
          final normalizedResponse =
              Map<String, dynamic>.from(response.data as Map);
          final errors = normalizedResponse['errors'];

          if (errors is Map) {
            errorPayload = Map<String, dynamic>.from(errors);
            action = errors['action']?.toString();
          } else if (normalizedResponse['data'] is Map) {
            errorPayload = Map<String, dynamic>.from(
              normalizedResponse['data'] as Map,
            );
            action = normalizedResponse['action']?.toString() ??
                errorPayload['action']?.toString();
          } else {
            action = normalizedResponse['action']?.toString();
          }
        }

        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: _extractApiErrorMessage(
            response.data,
            'Login failed',
          ),
          statusCode: response.statusCode,
          data: errorPayload,
          error: action != null ? {'action': action} : null,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'),
        );
      }

      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: getUserFriendlyErrorMessage(
              'Request timed out. Please try again.'),
        );
      }

      final responseData = e.response?.data;
      Map<String, dynamic>? errorPayload;
      String? action;
      if (responseData is Map) {
        final normalizedResponse = Map<String, dynamic>.from(responseData);
        final errors = normalizedResponse['errors'];
        if (errors is Map) {
          errorPayload = Map<String, dynamic>.from(errors);
          action = errors['action']?.toString();
        } else if (normalizedResponse['data'] is Map) {
          errorPayload = Map<String, dynamic>.from(
            normalizedResponse['data'] as Map,
          );
          action = errorPayload['action']?.toString();
        }
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: _extractApiErrorMessage(
          e.response?.data,
          'Login failed',
        ),
        statusCode: e.response?.statusCode,
        data: errorPayload,
        error: action != null ? {'action': action} : null,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> approveDeviceChange({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'username': username.trim(),
        'password': password,
        'deviceId': deviceId.trim(),
      };
      final response =
          await _dio.post('$_apiPrefix/auth/approve-device-change', data: {
        ...payload,
      });
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'),
        );
      }
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to approve device change',
      );
    }
  }

  Future<ApiResponse<void>> updateFcmToken(String? fcmToken) async {
    try {
      final response = await _dio
          .put('$_apiPrefix/users/fcm-token', data: {'fcm_token': fcmToken});
      return ApiResponse(
        success: true,
        message: response.data['message'] ?? 'Token updated',
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to update FCM token',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> validateStudentToken() async {
    try {
      final response = await _dio.get('$_apiPrefix/auth/validate-student');
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Token validation failed',
        error: e.response?.data,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.get('/health',
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ));
      _hasNetworkConnection = response.statusCode == 200;
      return _hasNetworkConnection;
    } catch (e) {
      _hasNetworkConnection = false;
      return false;
    }
  }

  // ===== SCHOOLS =====
  Future<ApiResponse<List<School>>> getSchools() async {
    try {
      debugPrint('🔍 [ApiService] getSchools: START');
      final response = await _dio.get('$_apiPrefix/schools');
      debugPrint(
          '🔍 [ApiService] getSchools: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        List<School> schools = [];

        if (data is List) {
          schools = data.map((json) {
            try {
              return School.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return School(
                id: json['id'] ?? 0,
                name: json['name']?.toString() ?? 'Unknown',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
            }
          }).toList();
        }

        return ApiResponse<List<School>>(
          success: true,
          message: response.data['message'] ?? 'Schools fetched',
          data: schools,
        );
      } else {
        return ApiResponse<List<School>>(
          success: false,
          message: response.data['message'] ?? 'Failed to fetch schools',
          data: [],
        );
      }
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getSchools: ERROR: $e');
      return ApiResponse<List<School>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch schools',
        data: [],
      );
    }
  }

  Future<ApiResponse<void>> selectSchool(int schoolId) async {
    try {
      final response = await _dio
          .put('$_apiPrefix/users/profile/me', data: {'school_id': schoolId});
      if (response.data is Map && response.data['success'] == true) {
        return ApiResponse(
            success: true, message: response.data['message']!.toString());
      } else {
        return ApiResponse(
            success: false,
            message: response.data['message'] ?? 'Failed to select school');
      }
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to select school',
      );
    }
  }

  Future<ApiResponse<String>> uploadPaymentProof(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        )
      });

      final response = await _dio.post(
        '$_apiPrefix/upload/image',
        data: formData,
        options: Options(headers: {
          'Content-Type': 'multipart/form-data',
          'Accept': 'application/json'
        }),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic> &&
          responseData['success'] == true) {
        String? fileUrl;
        if (responseData['data'] is String) {
          fileUrl = responseData['data'];
        } else if (responseData['data'] != null &&
            responseData['data'] is Map) {
          final dataMap = responseData['data'] as Map;
          fileUrl = dataMap['url']?.toString() ??
              dataMap['secure_url']?.toString() ??
              dataMap['file_path']?.toString();
        } else if (responseData['url'] != null) {
          fileUrl = responseData['url'];
        } else if (responseData['secure_url'] != null) {
          fileUrl = responseData['secure_url'];
        } else if (responseData['file_path'] != null) {
          fileUrl = responseData['file_path'];
        }
        if (fileUrl != null && fileUrl.isNotEmpty) {
          return ApiResponse<String>(
              success: true,
              message: responseData['message'] ?? 'Upload successful',
              data: fileUrl);
        }
      }
      return ApiResponse<String>(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? 'Upload response received',
          data: responseData['data']?.toString() ?? responseData.toString());
    } on DioException catch (e) {
      return ApiResponse<String>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to upload payment proof',
      );
    }
  }

  Future<ApiResponse<List<Setting>>> getSettingsByCategory(
      String category) async {
    try {
      final response =
          await _dio.get('$_apiPrefix/settings/category/$category');
      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List) {
          return ApiResponse<List<Setting>>(
            success: true,
            message: response.data['message'] ?? 'Settings retrieved',
            data: data.map((json) => Setting.fromJson(json)).toList(),
          );
        }
      }
      return ApiResponse<List<Setting>>(
        success: false,
        message:
            response.data['message'] ?? 'Failed to fetch $category settings',
        data: [],
      );
    } on DioException catch (e) {
      return ApiResponse<List<Setting>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to fetch $category settings',
        data: [],
      );
    }
  }

  // ===== SETTINGS =====
  Future<ApiResponse<List<Setting>>> getAllSettings() async {
    try {
      debugPrint('🔍 [ApiService] getAllSettings: START');
      final response = await _dio.get('$_apiPrefix/settings/all');
      debugPrint(
          '🔍 [ApiService] getAllSettings: statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.data is Map && response.data['success'] == true) {
          final data = response.data['data'];
          if (data is List) {
            debugPrint(
                '🔍 [ApiService] getAllSettings: found ${data.length} settings');
            return ApiResponse<List<Setting>>(
              success: true,
              message: response.data['message'] ?? 'Settings retrieved',
              data: data.map((json) => Setting.fromJson(json)).toList(),
            );
          }
        } else {
          debugPrint('🔍 [ApiService] getAllSettings: no settings found');
          return ApiResponse<List<Setting>>(
              success: true, message: 'No settings found', data: []);
        }
      }

      return ApiResponse<List<Setting>>(
          success: false, message: 'Failed to load settings', data: []);
    } catch (e) {
      debugPrint('🔍 [ApiService] getAllSettings: ERROR: $e');
      return ApiResponse<List<Setting>>(
          success: false,
          message: 'Failed to load settings: ${e.toString()}',
          data: []);
    }
  }

  // ===== CATEGORIES =====
  Future<ApiResponse<List<Category>>> getCategories() async {
    try {
      debugPrint('🔍 [ApiService] getCategories: ========== START ==========');
      debugPrint(
          '🔍 [ApiService] getCategories: Requesting $_apiPrefix/categories');

      final response = await _dio.get('$_apiPrefix/categories');

      debugPrint(
          '🔍 [ApiService] getCategories: Response received, statusCode=${response.statusCode}');

      if (response.data == null) {
        debugPrint('🔍 [ApiService] getCategories: ⚠️ Response data is null');
        return ApiResponse<List<Category>>(
          success: false,
          message: 'Empty response from server',
          data: [],
        );
      }

      final Map<String, dynamic> jsonResponse;
      if (response.data is Map<String, dynamic>) {
        jsonResponse = response.data as Map<String, dynamic>;
        debugPrint(
            '🔍 [ApiService] getCategories: ✅ Successfully parsed as Map');
      } else {
        debugPrint('🔍 [ApiService] getCategories: ❌ Response is not a Map');
        return ApiResponse<List<Category>>(
          success: false,
          message: 'Invalid response format',
          data: [],
        );
      }

      final bool success = jsonResponse['success'] ?? false;
      final String message = jsonResponse['message'] ?? 'Categories retrieved';

      List<Category> categories = [];
      final dynamic dataField = jsonResponse['data'];

      if (dataField is List) {
        debugPrint(
            '🔍 [ApiService] getCategories: dataField is List with ${dataField.length} items');
        categories = dataField.map<Category>((item) {
          try {
            if (item is Map<String, dynamic>) {
              return Category.fromJson(item);
            }
            return Category(
              id: item['id'] ?? 0,
              name: item['name']?.toString() ?? 'Unknown',
              status: item['status']?.toString() ?? 'active',
              billingCycle: item['billing_cycle']?.toString() ?? 'monthly',
            );
          } catch (e) {
            debugPrint(
                '🔍 [ApiService] getCategories: Error parsing category: $e');
            return Category(
              id: item['id'] ?? 0,
              name: item['name']?.toString() ?? 'Unknown',
              status: 'active',
              billingCycle: 'monthly',
            );
          }
        }).toList();
      }

      debugPrint(
          '🔍 [ApiService] getCategories: Parsed ${categories.length} categories');

      debugPrint(
          '🔍 [ApiService] getCategories: ✅ SUCCESS - returning ${categories.length} categories');

      return ApiResponse<List<Category>>(
        success: success,
        message: message,
        data: categories,
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getCategories: ❌ ERROR: $e');
      return ApiResponse<List<Category>>(
        success: false,
        message: 'Failed to load categories: ${e.toString()}',
        data: [],
      );
    }
  }

  // ===== COURSES =====
  Future<ApiResponse<List<Course>>> getCoursesByCategory(int categoryId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getCoursesByCategory: START for categoryId=$categoryId');
      final response = await _dio.get(
        '$_apiPrefix/courses/category/$categoryId',
        options: Options(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      debugPrint(
          '🔍 [ApiService] getCoursesByCategory: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Course> courses = [];

        if (data is List) {
          courses = data.map((json) => Course.fromJson(json)).toList();
        } else if (data is Map && data['courses'] is List) {
          courses = (data['courses'] as List)
              .map((json) => Course.fromJson(json))
              .toList();
        }

        return ApiResponse<List<Course>>(
          success: true,
          message: response.data['message'] ?? 'Courses retrieved',
          data: courses,
        );
      }

      return ApiResponse<List<Course>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch courses',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getCoursesByCategory: ERROR: $e');
      return ApiResponse<List<Course>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch courses',
        data: [],
      );
    }
  }

  // ===== CHAPTERS =====
  Future<ApiResponse<List<Chapter>>> getChaptersByCourse(int courseId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getChaptersByCourse: START for courseId=$courseId');
      final response = await _dio.get(
        '$_apiPrefix/chapters/course/$courseId',
        options: Options(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      debugPrint(
          '🔍 [ApiService] getChaptersByCourse: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Chapter> chapters = [];

        if (data is List) {
          chapters = data.map((json) => Chapter.fromJson(json)).toList();
        } else if (data is Map && data['chapters'] is List) {
          chapters = (data['chapters'] as List)
              .map((json) => Chapter.fromJson(json))
              .toList();
        }

        return ApiResponse<List<Chapter>>(
          success: true,
          message: response.data['message'] ?? 'Chapters retrieved',
          data: chapters,
        );
      }

      return ApiResponse<List<Chapter>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch chapters',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getChaptersByCourse: ERROR: $e');
      return ApiResponse<List<Chapter>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch chapters',
        data: [],
      );
    }
  }

  // ===== VIDEOS =====
  Future<ApiResponse<List<Video>>> getVideosByChapter(int chapterId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getVideosByChapter: START for chapterId=$chapterId');
      final response = await _dio.get(
        '$_apiPrefix/chapters/$chapterId/videos',
        options: Options(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      debugPrint(
          '🔍 [ApiService] getVideosByChapter: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Video> videos = [];

        if (data is List) {
          videos = data.map((json) => Video.fromJson(json)).toList();
        } else if (data is Map && data['videos'] is List) {
          videos = (data['videos'] as List)
              .map((json) => Video.fromJson(json))
              .toList();
        }

        return ApiResponse<List<Video>>(
          success: true,
          message: response.data['message'] ?? 'Videos retrieved',
          data: videos,
        );
      }

      return ApiResponse<List<Video>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch videos',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getVideosByChapter: ERROR: $e');
      return ApiResponse<List<Video>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch videos',
        data: [],
      );
    }
  }

  Future<ApiResponse<void>> incrementVideoViewCount(int videoId) async {
    try {
      final response = await _dio.post('$_apiPrefix/videos/$videoId/view');
      return ApiResponse(
        success: true,
        message: response.data['message'] ?? 'View count updated',
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to update view count',
      );
    }
  }

  // ===== NOTES =====
  Future<ApiResponse<List<Note>>> getNotesByChapter(int chapterId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getNotesByChapter: START for chapterId=$chapterId');
      final response = await _dio.get(
        '$_apiPrefix/chapters/$chapterId/notes',
        options: Options(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      debugPrint(
          '🔍 [ApiService] getNotesByChapter: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Note> notes = [];

        if (data is List) {
          notes = data.map((json) => Note.fromJson(json)).toList();
        } else if (data is Map && data['notes'] is List) {
          notes = (data['notes'] as List)
              .map((json) => Note.fromJson(json))
              .toList();
        }

        return ApiResponse<List<Note>>(
          success: true,
          message: response.data['message'] ?? 'Notes retrieved',
          data: notes,
        );
      }

      return ApiResponse<List<Note>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch notes',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getNotesByChapter: ERROR: $e');
      return ApiResponse<List<Note>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch notes',
        data: [],
      );
    }
  }

  // ===== PRACTICE QUESTIONS =====
  Future<ApiResponse<List<Question>>> getPracticeQuestions(
      int chapterId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getPracticeQuestions: START for chapterId=$chapterId');
      final response = await _dio.get(
        '$_apiPrefix/chapters/$chapterId/practice-questions',
        options: Options(
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      debugPrint(
          '🔍 [ApiService] getPracticeQuestions: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Question> questions = [];

        if (data is List) {
          questions = data.map((json) => Question.fromJson(json)).toList();
        } else if (data is Map && data['questions'] is List) {
          questions = (data['questions'] as List)
              .map((json) => Question.fromJson(json))
              .toList();
        }

        return ApiResponse<List<Question>>(
          success: true,
          message: response.data['message'] ?? 'Questions retrieved',
          data: questions,
        );
      }

      return ApiResponse<List<Question>>(
        success: false,
        message:
            response.data['message'] ?? 'Failed to fetch practice questions',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getPracticeQuestions: ERROR: $e');
      return ApiResponse<List<Question>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to fetch practice questions',
        data: [],
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkAnswer(
      int questionId, String selectedOption) async {
    try {
      final response = await _dio.post(
        '$_apiPrefix/practice/check-answer',
        data: {'question_id': questionId, 'selected_option': selectedOption},
      );
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to check answer',
        data: {},
      );
    }
  }

  // ===== EXAMS =====
  Future<ApiResponse<List<Exam>>> getAvailableExams({int? courseId}) async {
    try {
      debugPrint(
          '🔍 [ApiService] getAvailableExams: START with courseId=$courseId');
      final response = await _dio.get(
        '$_apiPrefix/exams/available',
        queryParameters: courseId != null ? {'course_id': courseId} : null,
      );
      debugPrint(
          '🔍 [ApiService] getAvailableExams: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Exam> exams = [];

        if (data is List) {
          exams = data.map((json) => Exam.fromJson(json)).toList();
        }

        return ApiResponse<List<Exam>>(
          success: true,
          message: response.data['message'] ?? 'Exams retrieved',
          data: exams,
        );
      }

      return ApiResponse<List<Exam>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch exams',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getAvailableExams: ERROR: $e');
      return ApiResponse<List<Exam>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch exams',
        data: [],
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> startExam(int examId) async {
    try {
      final response = await _dio.post('$_apiPrefix/exams/start/$examId');
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to start exam',
        data: {},
      );
    }
  }

  Future<ApiResponse<List<ExamQuestion>>> getExamQuestions(int examId) async {
    try {
      debugPrint('🔍 [ApiService] getExamQuestions: START for examId=$examId');
      final response =
          await _dio.get('$_apiPrefix/exam-questions/exam/$examId');
      debugPrint(
          '🔍 [ApiService] getExamQuestions: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<ExamQuestion> questions = [];

        if (data is List) {
          questions = data.map((json) => ExamQuestion.fromJson(json)).toList();
        }

        return ApiResponse<List<ExamQuestion>>(
          success: true,
          message: response.data['message'] ?? 'Exam questions retrieved',
          data: questions,
        );
      }

      return ApiResponse<List<ExamQuestion>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch exam questions',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getExamQuestions: ERROR: $e');
      return ApiResponse<List<ExamQuestion>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to fetch exam questions',
        data: [],
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> saveExamProgress(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final response = await _dio.post(
          '$_apiPrefix/exam-results/$examResultId/progress',
          data: {'answers': answers});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to save exam progress',
        data: {},
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitExam(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final response = await _dio.post(
          '$_apiPrefix/exams/submit/$examResultId',
          data: {'answers': answers});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to submit exam',
        data: {},
      );
    }
  }

  // ===== EXAM RESULTS =====
  Future<ApiResponse<List<ExamResult>>> getUserExamResults(int userId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getUserExamResults: START for userId=$userId');
      final response = await _dio.get(
        '$_apiPrefix/exam-results/user/$userId',
      );
      debugPrint(
          '🔍 [ApiService] getUserExamResults: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];

        List<ExamResult> results = [];

        if (data is List) {
          results = data.map((json) => ExamResult.fromJson(json)).toList();
        }

        return ApiResponse<List<ExamResult>>(
          success: true,
          message: response.data['message'] ?? 'Exam results retrieved',
          data: results,
        );
      }

      return ApiResponse<List<ExamResult>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch exam results',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getUserExamResults: ERROR: $e');
      return ApiResponse<List<ExamResult>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch exam results',
        data: [],
      );
    }
  }

  // ===== SUBSCRIPTIONS =====
  Future<ApiResponse<Map<String, dynamic>>> checkSubscriptionStatus(
      int categoryId) async {
    try {
      debugPrint(
          '🔍 [ApiService] checkSubscriptionStatus: START for categoryId=$categoryId');
      final response = await _performHttpGetJson(
        '$_apiPrefix/subscriptions/check-status',
        queryParameters: {'category_id': categoryId},
      );
      debugPrint(
          '🔍 [ApiService] checkSubscriptionStatus: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          final hasSubscription =
              mapData['has_subscription'] == true ||
                  mapData['has_active_subscription'] == true;
          final subscription = mapData['subscription'];

          if (subscription is Map) {
            final normalized = Map<String, dynamic>.from(subscription);
            normalized['has_subscription'] = hasSubscription;
            return ApiResponse<Map<String, dynamic>>(
              success: true,
              message: response.data['message'] ?? 'Status checked',
              data: normalized,
            );
          }

          return ApiResponse<Map<String, dynamic>>(
            success: true,
            message: response.data['message'] ?? 'Status checked',
            data: {
              'has_subscription': hasSubscription,
            },
          );
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Status checked',
          data: {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to check subscription',
        data: {'has_subscription': false},
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] checkSubscriptionStatus: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Failed to check subscription',
        data: {'has_subscription': false},
      );
    }
  }

  Future<ApiResponse<List<Subscription>>> getMySubscriptions() async {
    try {
      debugPrint('🔍 [ApiService] getMySubscriptions: START');
      final response = await _performHttpGetJson(
        '$_apiPrefix/subscriptions/my-subscriptions',
      );
      debugPrint(
          '🔍 [ApiService] getMySubscriptions: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Subscription> subscriptions = [];

        if (data is List) {
          subscriptions =
              data.map((json) => Subscription.fromJson(json)).toList();
        }

        return ApiResponse<List<Subscription>>(
          success: true,
          message: response.data['message'] ?? 'Subscriptions retrieved',
          data: subscriptions,
        );
      }

      return ApiResponse<List<Subscription>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch subscriptions',
        data: [],
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getMySubscriptions: ERROR: $e');
      return ApiResponse<List<Subscription>>(
        success: false,
        message: 'Failed to fetch subscriptions',
        data: [],
      );
    }
  }

  // ===== BATCH SUBSCRIPTION CHECK =====
  Future<Map<int, bool>> checkMultipleSubscriptions(
      List<int> categoryIds) async {
    try {
      debugPrint(
          '🔍 [ApiService] checkMultipleSubscriptions: START for ${categoryIds.length} categories');

      final response = await _dio.post(
        '$_apiPrefix/subscriptions/check-multiple',
        data: {'category_ids': categoryIds},
        options: Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      debugPrint(
          '🔍 [ApiService] checkMultipleSubscriptions: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final Map<String, dynamic> results = response.data['data'] ?? {};
        return results
            .map((key, value) => MapEntry(int.parse(key), value == true));
      }

      return {};
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] checkMultipleSubscriptions: ERROR: $e');
      return {};
    }
  }

  // ===== PAYMENTS =====
  Future<ApiResponse<Map<String, dynamic>>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? accountHolderName,
    String? proofImagePath,
  }) async {
    try {
      final response = await _dio.post(
        '$_apiPrefix/payments/submit',
        data: {
          'category_id': categoryId,
          'payment_type': paymentType,
          'payment_method': paymentMethod,
          'amount': amount,
          'account_holder_name': accountHolderName,
          'proof_image_path': proofImagePath,
        },
      );

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Payment submitted',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to submit payment',
        data: {},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to submit payment',
        data: {},
      );
    }
  }

  Future<ApiResponse<List<Payment>>> getMyPayments() async {
    try {
      debugPrint('🔍 [ApiService] getMyPayments: START');
      final response = await _performHttpGetJson(
        '$_apiPrefix/payments/my-payments',
      );
      debugPrint(
          '🔍 [ApiService] getMyPayments: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Payment> payments = [];

        if (data is List) {
          payments = data.map((json) => Payment.fromJson(json)).toList();
        }

        return ApiResponse<List<Payment>>(
          success: true,
          message: response.data['message'] ?? 'Payments retrieved',
          data: payments,
        );
      }

      return ApiResponse<List<Payment>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch payments',
        data: [],
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getMyPayments: ERROR: $e');
      return ApiResponse<List<Payment>>(
        success: false,
        message: 'Failed to fetch payments',
        data: [],
      );
    }
  }

  // ===== NOTIFICATIONS =====
  Future<ApiResponse<Map<String, dynamic>>> getUnreadCount() async {
    try {
      debugPrint('🔍 [ApiService] getUnreadCount: START');
      final response = await _performHttpGetJson(
        '$_apiPrefix/notifications/unread-count',
      );
      debugPrint(
          '🔍 [ApiService] getUnreadCount: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Unread count retrieved',
          data: data is Map
              ? Map<String, dynamic>.from(data)
              : {'unread_count': 0},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to get unread count',
        data: {'unread_count': 0},
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getUnreadCount: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Failed to get unread count',
        data: {'unread_count': 0},
      );
    }
  }

  Future<ApiResponse<List<Notification>>> getMyNotifications() async {
    try {
      debugPrint('🔍 [ApiService] getMyNotifications: START');
      final response = await _performHttpGetJson(
        '$_apiPrefix/notifications/my-notifications',
      );
      debugPrint(
          '🔍 [ApiService] getMyNotifications: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<Notification> notifications = [];

        if (data is List) {
          notifications =
              data.map((json) => Notification.fromJson(json)).toList();
        }

        return ApiResponse<List<Notification>>(
          success: true,
          message: response.data['message'] ?? 'Notifications retrieved',
          data: notifications,
        );
      }

      return ApiResponse<List<Notification>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch notifications',
        data: [],
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getMyNotifications: ERROR: $e');
      return ApiResponse<List<Notification>>(
        success: false,
        message: 'Failed to fetch notifications',
        data: [],
      );
    }
  }

  Future<ApiResponse<void>> markNotificationAsRead(int notificationId) async {
    try {
      final response =
          await _dio.put('$_apiPrefix/notifications/$notificationId/read');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ??
            'Failed to mark notification as read',
      );
    }
  }

  Future<ApiResponse<void>> markAllNotificationsAsRead() async {
    try {
      final response =
          await _dio.put('$_apiPrefix/notifications/mark-all-read');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to mark all as read',
      );
    }
  }

  Future<ApiResponse<void>> deleteNotification(int logId) async {
    try {
      final response = await _dio.delete('$_apiPrefix/notifications/$logId');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to delete notification',
      );
    }
  }

  Future<ApiResponse<void>> deleteAllNotifications() async {
    try {
      final response = await _dio.delete('$_apiPrefix/notifications/delete-all');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to delete all notifications',
      );
    }
  }

  // ===== STREAK =====
  Future<ApiResponse<Map<String, dynamic>>> getMyStreak() async {
    try {
      debugPrint('🔍 [ApiService] getMyStreak: START');
      final response = await _dio.get('$_apiPrefix/streaks/my-streak');
      debugPrint(
          '🔍 [ApiService] getMyStreak: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Streak retrieved',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch streak',
        data: {},
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getMyStreak: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch streak',
        data: {},
      );
    }
  }

  Future<ApiResponse<void>> updateStreak() async {
    try {
      final response = await _dio.post('$_apiPrefix/streaks/update');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to update streak',
      );
    }
  }

  // ===== TV PAIRING =====
  Future<ApiResponse<Map<String, dynamic>>> pairTvDevice(
      String tvDeviceId) async {
    try {
      final response = await _dio.post('$_apiPrefix/devices/tv/pair',
          data: {'tv_device_id': tvDeviceId});

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'TV paired',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to pair TV device',
        data: {},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to pair TV device',
        data: {},
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyTvPairing(
      String pairingCode) async {
    try {
      final response = await _dio.post('$_apiPrefix/devices/tv/verify',
          data: {'pairing_code': pairingCode});

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Verification successful',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to verify pairing',
        data: {},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to verify pairing',
        data: {},
      );
    }
  }

  Future<ApiResponse<void>> unpairTvDevice() async {
    try {
      final response = await _dio.post('$_apiPrefix/devices/tv/unpair');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to unpair TV device',
      );
    }
  }

  Future<ApiResponse<void>> updateDevice(
      String deviceType, String deviceId) async {
    try {
      final response = await _dio.put('$_apiPrefix/users/update-device',
          data: {'device_type': deviceType, 'device_id': deviceId});
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to update device',
      );
    }
  }

  // ===== PARENT LINK =====
  Future<ApiResponse<Map<String, dynamic>>> generateParentToken() async {
    try {
      final response = await _dio.post('$_apiPrefix/telegram/generate-token');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Token generated',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to generate parent token',
        data: {},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to generate parent token',
        data: {},
      );
    }
  }

  Future<ApiResponse<ParentLink>> getParentLinkStatus() async {
    try {
      debugPrint('🔍 [ApiService] getParentLinkStatus: START');
      final response = await _dio.get('$_apiPrefix/telegram/status');
      debugPrint(
          '🔍 [ApiService] getParentLinkStatus: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return ApiResponse<ParentLink>(
            success: true,
            message: response.data['message'] ?? 'Status retrieved',
            data: ParentLink.fromJson(data),
          );
        }
      }

      return ApiResponse<ParentLink>(
        success: false,
        message:
            response.data['message'] ?? 'Failed to fetch parent link status',
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getParentLinkStatus: ERROR: $e');
      return ApiResponse<ParentLink>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to fetch parent link status',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> unlinkParent() async {
    try {
      final response = await _dio.post('$_apiPrefix/telegram/unlink');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Parent unlinked',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to unlink parent',
        data: {},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to unlink parent',
        data: {},
      );
    }
  }

  // ===== USER PROFILE =====
  Future<ApiResponse<User>> getMyProfile() async {
    try {
      debugPrint('🔍 [ApiService] getMyProfile: START');
      final response = await _performHttpGetJson(
        '$_apiPrefix/users/profile/me',
      );
      debugPrint(
          '🔍 [ApiService] getMyProfile: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return ApiResponse<User>(
            success: true,
            message: response.data['message'] ?? 'Profile retrieved',
            data: User.fromJson(data),
          );
        }
      }

      return ApiResponse<User>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch profile',
      );
    } catch (e) {
      debugPrint('🔍 [ApiService] getMyProfile: ERROR: $e');
      return ApiResponse<User>(
        success: false,
        message: 'Failed to fetch profile',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateMyProfile(
      {String? email, String? phone, String? profileImage, int? schoolId}) async {
    try {
      final Map<String, dynamic> data = {};
      if (email != null && email.isNotEmpty) data['email'] = email;
      if (phone != null && phone.isNotEmpty) data['phone'] = phone;
      if (profileImage != null && profileImage.isNotEmpty) {
        data['profile_image'] = profileImage;
      }
      if (schoolId != null) data['school_id'] = schoolId;

      debugPrint('🔍 [ApiService] updateMyProfile: Sending data: $data');

      final response = await _dio.put(
        '$_apiPrefix/users/profile/me',
        data: data,
      );

      debugPrint(
          '🔍 [ApiService] updateMyProfile: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final responseData = response.data['data'];
        if (responseData != null && responseData is Map<String, dynamic>) {
          return ApiResponse<Map<String, dynamic>>(
            success: true,
            message: response.data['message'] ?? 'Profile updated successfully',
            data: responseData,
          );
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Profile updated successfully',
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] updateMyProfile: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to update profile',
      );
    }
  }

  // ===== PROGRESS =====
  Future<ApiResponse<void>> saveUserProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    try {
      final data = {
        'chapter_id': chapterId,
        if (videoProgress != null) 'video_progress': videoProgress,
        if (notesViewed != null) 'notes_viewed': notesViewed ? 1 : 0,
        if (questionsAttempted != null)
          'questions_attempted': questionsAttempted,
        if (questionsCorrect != null) 'questions_correct': questionsCorrect,
      };

      final response = await _dio.post('$_apiPrefix/progress/save', data: data);
      return ApiResponse(
          success: true, message: response.data['message'] ?? 'Progress saved');
    } on DioException catch (e) {
      return ApiResponse(
          success: false,
          message: e.response?.data['message'] ?? 'Failed to save progress');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getOverallProgress() async {
    try {
      debugPrint('🔍 [ApiService] getOverallProgress: START');
      final response = await _dio.get('$_apiPrefix/progress/overall');
      debugPrint(
          '🔍 [ApiService] getOverallProgress: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Progress retrieved',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch overall progress',
        data: {},
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getOverallProgress: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message:
            e.response?.data['message'] ?? 'Failed to fetch overall progress',
        data: {},
      );
    }
  }

  // ===== CHATBOT =====
  Future<ApiResponse<Map<String, dynamic>>> getChatbotUsage() async {
    try {
      debugPrint('🔍 [ApiService] getChatbotUsage: START');
      final response = await _dio.get('$_apiPrefix/chatbot/usage');
      debugPrint(
          '🔍 [ApiService] getChatbotUsage: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Usage retrieved',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to get usage',
        data: {},
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getChatbotUsage: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to get usage',
        data: {},
      );
    }
  }

  Future<ApiResponse<List<ChatbotConversation>>> getChatbotConversations(
      {int page = 1, int limit = 20}) async {
    try {
      debugPrint('🔍 [ApiService] getChatbotConversations: START');
      final response = await _dio.get(
        '$_apiPrefix/chatbot/conversations',
        queryParameters: {'page': page, 'limit': limit},
      );
      debugPrint(
          '🔍 [ApiService] getChatbotConversations: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<ChatbotConversation> conversations = [];

        if (data is List) {
          conversations = data
              .map((json) =>
                  ChatbotConversation.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data['conversations'] is List) {
          conversations = (data['conversations'] as List)
              .map((json) =>
                  ChatbotConversation.fromJson(json as Map<String, dynamic>))
              .toList();
        }

        return ApiResponse<List<ChatbotConversation>>(
          success: true,
          message: response.data['message'] ?? 'Conversations retrieved',
          data: conversations,
        );
      }

      return ApiResponse<List<ChatbotConversation>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch conversations',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getChatbotConversations: ERROR: $e');
      return ApiResponse<List<ChatbotConversation>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch conversations',
        data: [],
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendChatbotMessage(
    String message, {
    int? conversationId,
    List<String>? history,
  }) async {
    try {
      debugPrint('🔍 [ApiService] sendChatbotMessage: START');
      final response = await _dio.post(
        '$_apiPrefix/chatbot/chat',
        data: {
          'message': message,
          'conversation_id': conversationId,
          'history': history,
        },
      );
      debugPrint(
          '🔍 [ApiService] sendChatbotMessage: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] ?? {};
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Message sent',
          data: data is Map ? Map<String, dynamic>.from(data) : {},
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: response.data['message'] ?? 'Failed to send message',
        data: {},
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] sendChatbotMessage: ERROR: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to send message',
        data: {},
      );
    }
  }

  Future<ApiResponse<List<ChatbotMessage>>> getChatbotConversationMessages(
      int conversationId) async {
    try {
      debugPrint(
          '🔍 [ApiService] getChatbotConversationMessages: START for conversationId=$conversationId');
      final response = await _dio.get(
        '$_apiPrefix/chatbot/conversations/$conversationId/messages',
      );
      debugPrint(
          '🔍 [ApiService] getChatbotConversationMessages: statusCode=${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<ChatbotMessage> messages = [];

        if (data is List) {
          messages = data
              .map((json) =>
                  ChatbotMessage.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data['messages'] is List) {
          messages = (data['messages'] as List)
              .map((json) =>
                  ChatbotMessage.fromJson(json as Map<String, dynamic>))
              .toList();
        }

        return ApiResponse<List<ChatbotMessage>>(
          success: true,
          message: response.data['message'] ?? 'Messages retrieved',
          data: messages,
        );
      }

      return ApiResponse<List<ChatbotMessage>>(
        success: false,
        message: response.data['message'] ?? 'Failed to fetch messages',
        data: [],
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] getChatbotConversationMessages: ERROR: $e');
      return ApiResponse<List<ChatbotMessage>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to fetch messages',
        data: [],
      );
    }
  }

  Future<ApiResponse<bool>> renameChatbotConversation(
      int conversationId, String title) async {
    try {
      final response = await _dio.put(
        '$_apiPrefix/chatbot/conversations/$conversationId',
        data: {'title': title},
      );
      return ApiResponse<bool>(
        success: response.statusCode == 200 && response.data['success'] == true,
        message: response.data['message'] ?? 'Conversation renamed',
        data: true,
      );
    } on DioException catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to rename conversation',
        data: false,
      );
    }
  }

  Future<ApiResponse<bool>> deleteChatbotConversation(
      int conversationId) async {
    try {
      final response = await _dio.delete(
        '$_apiPrefix/chatbot/conversations/$conversationId',
      );
      return ApiResponse<bool>(
        success: response.statusCode == 200 && response.data['success'] == true,
        message: response.data['message'] ?? 'Conversation deleted',
        data: true,
      );
    } on DioException catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to delete conversation',
        data: false,
      );
    }
  }

  // ===== UPLOAD IMAGE =====
  Future<ApiResponse<String>> uploadImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file':
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      debugPrint('🔍 [ApiService] uploadImage: Uploading $fileName');

      final response = await _dio.post(
        '$_apiPrefix/upload/image',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      debugPrint(
          '🔍 [ApiService] uploadImage: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        String? fileUrl;
        if (response.data['data'] is String) {
          fileUrl = response.data['data'];
        } else if (response.data['data'] is Map &&
            response.data['data']['file_path'] != null) {
          fileUrl = response.data['data']['file_path'];
        } else if (response.data['file_path'] != null) {
          fileUrl = response.data['file_path'];
        } else if (response.data['url'] != null) {
          fileUrl = response.data['url'];
        }

        if (fileUrl != null && fileUrl.isNotEmpty) {
          debugPrint('🔍 [ApiService] uploadImage: Success, URL: $fileUrl');
          return ApiResponse<String>(
            success: true,
            message: response.data['message'] ?? 'Upload successful',
            data: fileUrl,
          );
        }
      }

      debugPrint('🔍 [ApiService] uploadImage: Failed - no URL in response');
      return ApiResponse<String>(
        success: false,
        message: response.data['message'] ?? 'Failed to upload image',
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] uploadImage: ERROR: $e');
      String errorMessage = 'Failed to upload image';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Receive timeout. Server may be slow.';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMessage = 'Send timeout. File may be too large.';
      }
      return ApiResponse<String>(
        success: false,
        message: e.response?.data['message'] ?? errorMessage,
      );
    }
  }

  Future<ApiResponse<String>> uploadProfileImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file':
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      debugPrint('🔍 [ApiService] uploadProfileImage: Uploading $fileName');

      final response = await _dio.post(
        '$_apiPrefix/upload/profile',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      debugPrint(
          '🔍 [ApiService] uploadProfileImage: statusCode=${response.statusCode}');

      if (response.data is Map && response.data['success'] == true) {
        String? fileUrl;
        if (response.data['data'] is String) {
          fileUrl = response.data['data'];
        } else if (response.data['data'] is Map &&
            response.data['data']['file_path'] != null) {
          fileUrl = response.data['data']['file_path'];
        } else if (response.data['file_path'] != null) {
          fileUrl = response.data['file_path'];
        } else if (response.data['url'] != null) {
          fileUrl = response.data['url'];
        }

        if (fileUrl != null && fileUrl.isNotEmpty) {
          debugPrint(
              '🔍 [ApiService] uploadProfileImage: Success, URL: $fileUrl');
          return ApiResponse<String>(
            success: true,
            message: response.data['message'] ?? 'Upload successful',
            data: fileUrl,
          );
        }
      }

      debugPrint(
          '🔍 [ApiService] uploadProfileImage: Failed - no URL in response');
      return ApiResponse<String>(
        success: false,
        message: response.data['message'] ?? 'Failed to upload image',
      );
    } on DioException catch (e) {
      debugPrint('🔍 [ApiService] uploadProfileImage: ERROR: $e');
      String errorMessage = 'Failed to upload image';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Receive timeout. Server may be slow.';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMessage = 'Send timeout. File may be too large.';
      }
      return ApiResponse<String>(
        success: false,
        message: e.response?.data['message'] ?? errorMessage,
      );
    }
  }
}
