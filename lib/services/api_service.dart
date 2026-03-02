import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/exam_question_model.dart';
import 'package:familyacademyclient/models/exam_result_model.dart';
import 'package:familyacademyclient/models/notification_model.dart';
import 'package:familyacademyclient/models/parent_link_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/models/setting_model.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/utils/constants.dart' show AppConstants;
import 'package:familyacademyclient/utils/helpers.dart';

import '../utils/api_response.dart';

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRefreshingToken = false;
  late SharedPreferences _prefs;

  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;
  static const int _baseRetryDelaySeconds = 2;

  final StreamController<Map<String, dynamic>> _deviceDeactivationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceDeactivationStream =>
      _deviceDeactivationController.stream;

  bool _hasNetworkConnection = true;
  bool get hasNetworkConnection => _hasNetworkConnection;

  Dio get dio => _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
        receiveTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
        sendTimeout: const Duration(seconds: AppConstants.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status! < 500,
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));

    if (!kReleaseMode) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }

    _initSharedPreferences();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);

    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final decoded =
              utf8.decode(base64Url.decode(base64Url.normalize(payload)));
          final jsonPayload = json.decode(decoded);
          final exp = jsonPayload['exp'];
          if (exp != null) {
            final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            final minutesUntilExpiry =
                expiryTime.difference(DateTime.now()).inMinutes;
            if (minutesUntilExpiry < 5) await _refreshAccessToken();
          }
        }
      } catch (e) {
        debugLog('api_service', 'Error: $e');
      }
      options.headers['Authorization'] = 'Bearer $token';
    }

    final userData = _prefs.getString(AppConstants.userDataKey);
    if (userData != null) {
      try {
        final userJson = json.decode(userData);
        final userId = userJson['id'];
        if (userId != null) options.headers['X-User-ID'] = userId.toString();
      } catch (e) {
        debugLog('api_service', 'Error: $e');
      }
    }

    if (kDebugMode) {
      debugLog('ApiService', '${options.method} ${options.path}');
      if (options.data != null && options.data is Map) {
        final data = Map.from(options.data as Map);
        if (data.containsKey('password')) data['password'] = '***';
        if (data.containsKey('token')) data['token'] = '***';
        debugLog('ApiService', 'Request: $data');
      }
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    debugLog(
        'ApiService', '${response.statusCode} ${response.requestOptions.path}');
    _retryCounts.remove(response.requestOptions.path);
    _hasNetworkConnection = true;
    handler.next(response);
  }

  Future<void> _onError(
      DioException error, ErrorInterceptorHandler handler) async {
    debugLog('ApiService', '${error.type} - ${error.message}');

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      _hasNetworkConnection = false;

      handler.resolve(Response(
        requestOptions: error.requestOptions,
        statusCode: -1,
        data: {
          'success': false,
          'message': 'Network error. Please check your internet connection.',
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

    if (error.response?.data is String) {
      handler.resolve(Response(
        requestOptions: error.requestOptions,
        statusCode: error.response?.statusCode ?? 500,
        data: {'success': false, 'message': error.response?.data as String},
      ));
      return;
    }

    if (error.response?.statusCode == 401) {
      if (!_isRefreshingToken) {
        _isRefreshingToken = true;
        try {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            final newToken =
                await _secureStorage.read(key: AppConstants.tokenKey);
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

    handler.next(error);
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        await _secureStorage.write(key: AppConstants.tokenKey, value: newToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register(String username,
      String password, String deviceId, String? fcmToken) async {
    try {
      final response = await _dio.post(
        AppConstants.registerEndpoint,
        data: {
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'fcmToken': fcmToken,
        },
      );

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data == null) throw ApiError(message: 'No data received');

        Map<String, dynamic> userData;
        String token;

        if (data is Map && data.containsKey('user')) {
          userData = Map<String, dynamic>.from(data['user']);
          token = data['token']?.toString() ?? '';
        } else if (data is Map) {
          userData = Map<String, dynamic>.from(data);
          token = data['token']?.toString() ?? '';
        } else {
          throw ApiError(message: 'Invalid response format');
        }

        if (!userData.containsKey('id') || !userData.containsKey('username')) {
          throw ApiError(message: 'Invalid user data');
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Registration successful',
          data: {'user': userData, 'token': token},
        );
      } else {
        throw ApiError(
            message:
                response.data['message']?.toString() ?? 'Registration failed');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Network error. Please check your internet connection.',
          data: null,
        );
      }
      throw ApiError(
        message:
            e.response?.data['message']?.toString() ?? 'Registration failed',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> approveDeviceChange({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post('/auth/approve-device-change', data: {
        'username': username,
        'password': password,
        'deviceId': deviceId,
      });
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Network error. Please check your internet connection.',
          data: null,
        );
      }
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to approve device change',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> studentLogin(String username,
      String password, String deviceId, String? fcmToken) async {
    try {
      final response = await _dio.post(
        AppConstants.studentLoginEndpoint,
        data: {
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'fcmToken': fcmToken
        },
      );

      if (response.data is Map && response.data['success'] == false) {
        if (response.statusCode == 403 &&
            response.data['action'] == 'device_change_required') {
          throw ApiError(
            message: response.data['message']?.toString() ??
                'Device change required',
            statusCode: response.statusCode,
            data: response.data,
            action: 'device_change_required',
          );
        }
        throw ApiError(
          message: response.data['message']?.toString() ?? 'Login failed',
          statusCode: response.statusCode,
          data: response.data,
          action: response.data['action'],
        );
      }

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        if (data is! Map<String, dynamic>) {
          throw ApiError(message: 'Invalid response format');
        }

        await _secureStorage.write(
            key: AppConstants.tokenKey, value: data['token']);
        if (data['deviceToken'] != null) {
          await _secureStorage.write(
              key: AppConstants.refreshTokenKey, value: data['deviceToken']);
        }

        final user = User.fromJson(data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            AppConstants.userDataKey, json.encode(user.toJson()));

        return ApiResponse(
            success: true,
            message: response.data['message'] ?? 'Login successful',
            data: data);
      } else {
        throw ApiError(
            message: response.data['message']?.toString() ?? 'Login failed');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Network error. Please check your internet connection.',
          data: null,
        );
      }
      if (e.response?.statusCode == 403 && e.response?.data is Map) {
        final responseData = e.response!.data as Map<String, dynamic>;
        if (responseData['action'] == 'device_change_required') {
          throw ApiError(
            message:
                responseData['message']?.toString() ?? 'Device change required',
            statusCode: 403,
            data: responseData,
            action: 'device_change_required',
          );
        }
        throw ApiError(
          message: responseData['message']?.toString() ?? 'Login failed',
          statusCode: 403,
          data: responseData,
          action: responseData['action'],
        );
      }
      throw ApiError(
        message: e.response?.data['message']?.toString() ?? 'Login failed',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<void>> updateFcmToken(String fcmToken) async {
    try {
      final response =
          await _dio.put('/users/fcm-token', data: {'fcm_token': fcmToken});
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse(
          success: false,
          message: 'Network error. Will retry later.',
        );
      }
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update FCM token',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(AppConstants.logoutEndpoint);
    } catch (e) {
      debugLog('ApiService', 'Logout error (non-critical): $e');
    } finally {
      await _clearUserDataOnly();
    }
  }

  Future<void> _clearUserDataOnly() async {
    await _secureStorage.deleteAll();
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('user_') ||
          key == AppConstants.userDataKey ||
          key == AppConstants.sessionStartKey ||
          key.startsWith('cache_')) {
        await _prefs.remove(key);
      }
    }
  }

  Future<ApiResponse<List<School>>> getSchools() async {
    try {
      final response = await _dio.get(AppConstants.schoolsEndpoint);

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];
        List<School> schools = [];

        if (data is List) {
          schools = data.map((json) {
            try {
              return School.fromJson(json);
            } catch (e) {
              debugLog('ApiService', 'Error parsing school: $e');
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
        throw ApiError(
            message: response.data['message'] ?? 'Failed to fetch schools');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return ApiResponse<List<School>>(
          success: false,
          message: 'Network error. Please check your internet connection.',
          data: [],
        );
      }
      if (e.response?.statusCode == 429) {
        throw ApiError(message: 'Too many requests');
      }
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch schools',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final response = await _dio.get('/health',
          options: Options(
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ));
      _hasNetworkConnection = response.statusCode == 200;
      return _hasNetworkConnection;
    } catch (e) {
      _hasNetworkConnection = false;
      return false;
    }
  }

  Future<ApiResponse<void>> selectSchool(int schoolId) async {
    try {
      final response = await _dio.put(AppConstants.updateProfileEndpoint,
          data: {'school_id': schoolId});
      if (response.data is Map && response.data['success'] == true) {
        return ApiResponse(
            success: true, message: response.data['message']!.toString());
      } else {
        throw ApiError(
            message: response.data['message'] ?? 'Failed to select school');
      }
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to select school',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Setting>>> getAllSettings() async {
    try {
      final response = await _dio.get('/settings/all');
      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
          }
          if (data is Map<String, dynamic> &&
              data['data'] != null &&
              data['data'] is List) {
            return List<Setting>.from(
                (data['data'] as List).map((x) => Setting.fromJson(x)));
          }
          return <Setting>[];
        },
      );
    } catch (e) {
      final List<String> categories = [
        'payment',
        'contact',
        'general',
        'system'
      ];
      final List<Setting> allSettings = [];
      for (final category in categories) {
        try {
          final response = await getSettingsByCategory(category);
          if (response.success && response.data != null) {
            allSettings.addAll(response.data!);
          }
        } catch (e) {}
      }
      return ApiResponse<List<Setting>>(
          success: true,
          message: 'Loaded ${allSettings.length} settings',
          data: allSettings);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> sendChatbotMessage(
    String message, {
    int? conversationId,
    List<String>? history,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.chatbotChatEndpoint,
        data: {
          'message': message,
          'conversation_id': conversationId,
          'history': history,
        },
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to send message',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Category>>> getCategories() async {
    try {
      final response = await _dio.get(AppConstants.categoriesEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map<Category>((item) {
              try {
                return Category.fromJson(item);
              } catch (e) {
                return Category(
                  id: item['id'] ?? 0,
                  name: item['name'] ?? 'Unknown',
                  status: item['status'] ?? 'active',
                  price: item['price'] != null
                      ? double.parse(item['price'].toString())
                      : null,
                  billingCycle: item['billing_cycle'] ?? 'monthly',
                  description: item['description'],
                  courseCount: item['course_count'] ?? 0,
                );
              }
            }).toList();
          }
          return <Category>[];
        },
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch categories',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCoursesByCategory(
      int categoryId) async {
    try {
      final response =
          await _dio.get(AppConstants.coursesByCategory(categoryId));
      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is Map<String, dynamic>) {
            final coursesData = data['courses'] ?? data['data'] ?? [];
            return {
              'courses': coursesData is List ? coursesData : [],
              'category_id': categoryId
            };
          }
          return {'courses': [], 'category_id': categoryId};
        },
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch courses',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getChaptersByCourse(
      int courseId) async {
    try {
      final response = await _dio.get(AppConstants.chaptersByCourse(courseId));
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch chapters',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getVideosByChapter(
      int chapterId) async {
    try {
      final response = await _dio.get('/videos/chapter/$chapterId');

      if (response.data is Map && response.data['success'] == true) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Videos retrieved',
          data: response.data['data'] ?? {},
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: response.data['message'] ?? 'Failed to fetch videos',
          data: {},
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: e.response?.data['message'] ?? 'Access denied',
          data: e.response?.data ?? {},
        );
      }
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch videos',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> incrementVideoViewCount(int videoId) async {
    try {
      final response = await _dio.post('/videos/$videoId/view');

      return ApiResponse(
        success: true,
        message: response.data['message'] ?? 'View count updated',
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update view count',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return ApiResponse<Map<String, dynamic>>(
        success: true,
        message: response.data['message'] ?? 'Unread count retrieved',
        data: response.data['data'] ?? {'unread_count': 0},
      );
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message'] ?? 'Failed to get unread count',
        error: e,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getNotesByChapter(
      int chapterId) async {
    try {
      final response = await _dio.get(AppConstants.notesByChapter(chapterId));
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch notes',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getPracticeQuestions(
      int chapterId) async {
    try {
      final response =
          await _dio.get(AppConstants.practiceQuestions(chapterId));
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch practice questions',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkAnswer(
      int questionId, String selectedOption) async {
    try {
      final response = await _dio.post(
        AppConstants.checkAnswerEndpoint,
        data: {'question_id': questionId, 'selected_option': selectedOption},
      );
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to check answer',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Exam>>> getAvailableExams({int? courseId}) async {
    try {
      final response = await _dio.get(
        AppConstants.availableExamsEndpoint,
        queryParameters: courseId != null ? {'course_id': courseId} : null,
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<Exam> exams = data['data'] is List
              ? (data['data'] as List)
                  .map<Exam>((item) => Exam.fromJson(item))
                  .toList()
              : [];
          return ApiResponse<List<Exam>>(
              success: true,
              message: data['message'] ?? 'Exams retrieved',
              data: exams);
        } else {
          return ApiResponse<List<Exam>>(
              success: false,
              message: data['message'] ?? 'Failed to fetch exams',
              data: []);
        }
      }
      return ApiResponse<List<Exam>>(
          success: false, message: 'Invalid response', data: []);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch exams',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> startExam(int examId) async {
    try {
      final response = await _dio.post(AppConstants.startExamEndpoint(examId));
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to start exam',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<ExamQuestion>>> getExamQuestions(int examId) async {
    try {
      final response =
          await _dio.get(AppConstants.examQuestionsEndpoint(examId));

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          List<ExamQuestion> questions = [];
          if (data.containsKey('data') && data['data'] is List) {
            final items = data['data'] as List;
            questions = items.map<ExamQuestion>((item) {
              if (item is Map<String, dynamic>) {
                return ExamQuestion(
                  id: item['id'] ?? 0,
                  examId: examId,
                  questionId: item['id'] ?? item['exam_question_id'] ?? 0,
                  displayOrder: item['display_order'] ?? 0,
                  marks: item['marks'] ?? 1,
                  questionText: item['question_text']?.toString() ?? '',
                  optionA: item['option_a']?.toString(),
                  optionB: item['option_b']?.toString(),
                  optionC: item['option_c']?.toString(),
                  optionD: item['option_d']?.toString(),
                  optionE: item['option_e']?.toString(),
                  optionF: item['option_f']?.toString(),
                  difficulty: (item['difficulty']?.toString() ?? 'medium')
                      .toLowerCase(),
                  hasAnswer: item['correct_option'] != null &&
                      (item['correct_option']?.toString() ?? '').isNotEmpty,
                );
              }
              return ExamQuestion(
                  id: 0,
                  examId: examId,
                  questionId: 0,
                  displayOrder: 0,
                  marks: 0,
                  questionText: '',
                  difficulty: 'medium',
                  hasAnswer: false);
            }).toList();
          }
          return ApiResponse<List<ExamQuestion>>(
              success: true,
              message: data['message'] ?? 'Exam questions retrieved',
              data: questions);
        } else {
          return ApiResponse<List<ExamQuestion>>(
              success: false,
              message: data['message'] ?? 'Failed to fetch exam questions',
              data: []);
        }
      } else if (response.data is List) {
        final items = response.data as List;
        final questions = items.map<ExamQuestion>((item) {
          if (item is Map<String, dynamic>) {
            return ExamQuestion(
              id: item['id'] ?? 0,
              examId: examId,
              questionId: item['id'] ?? item['exam_question_id'] ?? 0,
              displayOrder: item['display_order'] ?? 0,
              marks: item['marks'] ?? 1,
              questionText: item['question_text']?.toString() ?? '',
              optionA: item['option_a']?.toString(),
              optionB: item['option_b']?.toString(),
              optionC: item['option_c']?.toString(),
              optionD: item['option_d']?.toString(),
              optionE: item['option_e']?.toString(),
              optionF: item['option_f']?.toString(),
              difficulty:
                  (item['difficulty']?.toString() ?? 'medium').toLowerCase(),
              hasAnswer: item['correct_option'] != null &&
                  (item['correct_option']?.toString() ?? '').isNotEmpty,
            );
          }
          return ExamQuestion(
              id: 0,
              examId: examId,
              questionId: 0,
              displayOrder: 0,
              marks: 0,
              questionText: '',
              difficulty: 'medium',
              hasAnswer: false);
        }).toList();
        return ApiResponse<List<ExamQuestion>>(
            success: true,
            message: 'Exam questions retrieved',
            data: questions);
      }

      return ApiResponse<List<ExamQuestion>>(
          success: false, message: 'Invalid response', data: []);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch exam questions',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> saveExamProgress(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final response = await _dio.post(
          AppConstants.examProgressEndpoint(examResultId),
          data: {'answers': answers});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to save exam progress',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitExam(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final response = await _dio.post(
          AppConstants.submitExamEndpoint(examResultId),
          data: {'answers': answers});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to submit exam',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<ExamResult>>> getMyExamResults() async {
    try {
      final response = await _dio.get(AppConstants.myExamResultsEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) => data is List
            ? data.map<ExamResult>((item) => ExamResult.fromJson(item)).toList()
            : <ExamResult>[],
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch exam results',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>>
      checkHasActiveSubscriptionForCategory(int categoryId) async {
    try {
      final response =
          await _dio.get('/api/v1/subscriptions/has-active/$categoryId');
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return ApiResponse<Map<String, dynamic>>(
            success: data['success'] ?? false,
            message: data['message'] ?? 'Subscription status checked',
            data: data['data'] ?? data);
      }
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Invalid response',
          data: {'has_active_subscription': false});
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message:
              e.response?.data['message'] ?? 'Failed to check subscription',
          data: {'has_active_subscription': false});
    }
  }

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
        AppConstants.submitPaymentEndpoint,
        data: {
          'category_id': categoryId,
          'payment_type': paymentType,
          'payment_method': paymentMethod,
          'amount': amount,
          'account_holder_name': accountHolderName,
          'proof_image_path': proofImagePath,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['has_pending_payment'] == true) {
          return ApiResponse<Map<String, dynamic>>(
              success: false,
              message: data['message'] ?? 'Payment already pending',
              data: data['data'] ?? data);
        }
        return ApiResponse<Map<String, dynamic>>(
            success: data['success'] ?? false,
            message: data['message'] ?? 'Payment submitted',
            data: data['data'] ?? data);
      }
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Invalid response',
          data: {'success': false, 'message': 'Invalid response'});
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data['has_pending_payment'] == true)) {
        return ApiResponse<Map<String, dynamic>>(
            success: false,
            message: e.response?.data['message'] ?? 'Payment already pending',
            data: e.response?.data['data'] ?? e.response?.data);
      }
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: e.response?.data['message'] ?? 'Failed to submit payment',
          data: {'success': false, 'error': e.toString()});
    }
  }

  Future<ApiResponse<List<Payment>>> getMyPayments() async {
    try {
      final response = await _dio.get(AppConstants.myPaymentsEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map<Payment>((item) {
              try {
                return Payment.fromJson(item);
              } catch (e) {
                return Payment(
                  id: item['id'] ?? 0,
                  paymentType: item['payment_type'] ?? 'first_time',
                  amount: item['amount'] != null
                      ? double.parse(item['amount'].toString())
                      : 0,
                  paymentMethod: item['payment_method'] ?? 'telebirr',
                  status: item['status'] ?? 'pending',
                  createdAt: item['created_at'] != null
                      ? DateTime.parse(item['created_at'])
                      : DateTime.now(),
                  categoryName: item['category_name'] ?? 'Unknown',
                  verifiedAt: item['verified_at'] != null
                      ? DateTime.parse(item['verified_at'])
                      : null,
                  rejectionReason: item['rejection_reason'],
                );
              }
            }).toList();
          }
          return <Payment>[];
        },
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch payments',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Subscription>>> getMySubscriptions() async {
    try {
      final response = await _dio.get(AppConstants.mySubscriptionsEndpoint);
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<Subscription> subscriptions = data['data'] is List
              ? (data['data'] as List).map<Subscription>((item) {
                  try {
                    return Subscription.fromJson(item);
                  } catch (e) {
                    return Subscription(
                      id: item['id'] ?? 0,
                      userId: item['user_id'] ?? 0,
                      categoryId: item['category_id'] ?? 0,
                      startDate: item['start_date'] != null
                          ? DateTime.parse(item['start_date'])
                          : DateTime.now(),
                      expiryDate: item['expiry_date'] != null
                          ? DateTime.parse(item['expiry_date'])
                          : DateTime.now().add(const Duration(days: 30)),
                      status:
                          item['current_status'] ?? item['status'] ?? 'active',
                      billingCycle: item['billing_cycle'] ?? 'monthly',
                      paymentId: item['payment_id'],
                      createdAt: item['created_at'] != null
                          ? DateTime.parse(item['created_at'])
                          : null,
                      updatedAt: item['updated_at'] != null
                          ? DateTime.parse(item['updated_at'])
                          : null,
                      categoryName: item['category_name'],
                      price: item['price'] != null
                          ? double.parse(item['price'].toString())
                          : null,
                    );
                  }
                }).toList()
              : [];
          return ApiResponse<List<Subscription>>(
              success: true,
              message: data['message'] ?? 'Subscriptions retrieved',
              data: subscriptions);
        } else {
          return ApiResponse<List<Subscription>>(
              success: false,
              message: data['message'] ?? 'Failed to fetch subscriptions',
              data: []);
        }
      }
      return ApiResponse<List<Subscription>>(
          success: false, message: 'Invalid response', data: []);
    } on DioException catch (e) {
      return ApiResponse<List<Subscription>>(
          success: false,
          message:
              e.response?.data['message'] ?? 'Failed to fetch subscriptions',
          data: []);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkSubscriptionStatus(
      int categoryId) async {
    try {
      final response = await _dio.get(
          AppConstants.checkSubscriptionStatusEndpoint,
          queryParameters: {'category_id': categoryId});
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return ApiResponse<Map<String, dynamic>>(
            success: data['success'] ?? false,
            message: data['message'] ?? 'Status checked',
            data: data['data'] ?? data);
      }
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'Invalid response',
          data: {'has_subscription': false, 'status': 'unpaid'});
    } on DioException catch (e) {
      return ApiResponse<Map<String, dynamic>>(
          success: false,
          message:
              e.response?.data['message'] ?? 'Failed to check subscription',
          data: {'has_subscription': false, 'status': 'error'});
    }
  }

  Future<ApiResponse<void>> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _dio
          .put('${AppConstants.notificationsEndpoint}/$notificationId/read');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to mark notification as read',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> markAllNotificationsAsRead() async {
    try {
      final response =
          await _dio.put('${AppConstants.notificationsEndpoint}/mark-all-read');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to mark all notifications as read',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> deleteNotification(int logId) async {
    try {
      final response =
          await _dio.delete('${AppConstants.notificationsEndpoint}/$logId');
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to delete notification',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getMyStreak() async {
    try {
      final response = await _dio.get(AppConstants.myStreakEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch streak',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> updateStreak() async {
    try {
      final response = await _dio.post(AppConstants.updateStreakEndpoint);
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update streak',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> pairTvDevice(
      String tvDeviceId) async {
    try {
      final response = await _dio.post(AppConstants.pairTvDeviceEndpoint,
          data: {'tv_device_id': tvDeviceId});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to pair TV device',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> verifyTvPairing(
      String pairingCode) async {
    try {
      final response = await _dio.post(AppConstants.verifyTvPairingEndpoint,
          data: {'pairing_code': pairingCode});
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to verify pairing',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> unpairTvDevice() async {
    try {
      final response = await _dio.post(AppConstants.unpairTvDeviceEndpoint);
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to unpair TV device',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> generateParentToken() async {
    try {
      final response =
          await _dio.post(AppConstants.generateParentTokenEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to generate parent token',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<ParentLink>> getParentLinkStatus() async {
    try {
      final response = await _dio.get(AppConstants.parentLinkStatusEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => ParentLink.fromJson(data));
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch parent link status',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> unlinkParent() async {
    try {
      final response = await _dio.post(AppConstants.unlinkParentEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to unlink parent',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Notification>>> getMyNotifications() async {
    try {
      final response = await _dio.get(AppConstants.myNotificationsEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) =>
            List<Notification>.from(data.map((x) => Notification.fromJson(x))),
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch notifications',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<User>> getMyProfile() async {
    try {
      final response = await _dio.get(AppConstants.myProfileEndpoint);
      return ApiResponse.fromJson(response.data, (data) => User.fromJson(data));
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch profile',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> updateMyProfile(
      {String? email, String? phone, String? profileImage}) async {
    try {
      final response = await _dio.put(
        AppConstants.updateProfileEndpoint,
        data: {
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (profileImage != null) 'profile_image': profileImage
        },
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update profile',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> updateDevice(
      String deviceType, String deviceId) async {
    try {
      final response = await _dio.put(AppConstants.updateDeviceEndpoint,
          data: {'device_type': deviceType, 'device_id': deviceId});
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update device',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Setting>>> getSettingsByCategory(
      String category) async {
    try {
      final response = await _dio.get('/settings/category/$category');
      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
          }
          if (data is Map<String, dynamic> &&
              data['data'] != null &&
              data['data'] is List) {
            return List<Setting>.from(
                (data['data'] as List).map((x) => Setting.fromJson(x)));
          }
          return <Setting>[];
        },
      );
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch $category settings',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<String>> uploadFile(File file, String type) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final endpoint = type == 'image'
          ? AppConstants.uploadImageEndpoint
          : type == 'video'
              ? AppConstants.uploadVideoEndpoint
              : AppConstants.uploadFileEndpoint;

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] != null) {
          final data = responseData['data'];
          if (data is String) {
            return ApiResponse<String>(
                success: responseData['success'] ?? true,
                message: responseData['message'] ?? 'Upload successful',
                data: data);
          }
          if (data is Map<String, dynamic> && data['file_path'] != null) {
            return ApiResponse<String>(
                success: responseData['success'] ?? true,
                message: responseData['message'] ?? 'Upload successful',
                data: data['file_path'].toString());
          }
        } else if (responseData['file_path'] != null) {
          return ApiResponse<String>(
              success: true,
              message: responseData['message'] ?? 'Upload successful',
              data: responseData['file_path'].toString());
        }
      }
      return ApiResponse<String>(
          success: true,
          message: 'File uploaded',
          data: responseData?.toString() ?? '');
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to upload file',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<String>> uploadImage(File imageFile) async {
    try {
      return await uploadFile(imageFile, 'image');
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to upload image',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
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
        AppConstants.uploadPaymentProofEndpoint,
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
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to upload payment proof',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> validateToken() async {
    try {
      final response = await _dio.get(AppConstants.validateTokenEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Token validation failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> validateStudentToken() async {
    try {
      final response =
          await _dio.get(AppConstants.validateStudentTokenEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Student token validation failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

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

      final response = await _dio.post('/progress/save', data: data);
      if (response.data is Map && response.data['success'] == true) {
        return ApiResponse(
            success: true,
            message: response.data['message'] ?? 'Progress saved');
      } else {
        return ApiResponse(
            success: false,
            message: response.data['message'] ?? 'Failed to save progress');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return ApiResponse(success: true, message: 'Progress saved locally');
      }
      return ApiResponse(
          success: false,
          message: e.response?.data['message'] ?? 'Failed to save progress');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getOverallProgress() async {
    try {
      final response = await _dio.get('/progress/overall');
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch overall progress',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<UserProgress>>> getUserProgressForCourse(
      int courseId) async {
    try {
      final response = await _dio.get('/progress/course/$courseId');
      return ApiResponse.fromJson(
        response.data,
        (data) =>
            List<UserProgress>.from(data.map((x) => UserProgress.fromJson(x))),
      );
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch course progress',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
