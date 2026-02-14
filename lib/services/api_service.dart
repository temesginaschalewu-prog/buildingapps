// ignore_for_file: only_throw_errors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
import 'package:flutter/foundation.dart' show kReleaseMode, kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' hide MultipartFile, Response;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/models/category_model.dart';
import '../utils/api_response.dart';

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRefreshingToken = false;
  late SharedPreferences _prefs;

  // Track retry counts for exponential backoff
  final Map<String, int> _retryCounts = {};
  static const int _maxRetries = 3;
  static const int _baseRetryDelaySeconds = 2;

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
        validateStatus: (status) {
          return status! < 500;
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

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
          final decoded = utf8.decode(base64Url.decode(payload));
          final jsonPayload = json.decode(decoded);
          final exp = jsonPayload['exp'];

          if (exp != null) {
            final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            final now = DateTime.now();
            final minutesUntilExpiry = expiryTime.difference(now).inMinutes;

            if (minutesUntilExpiry < 5) {
              debugLog('ApiService',
                  '⚠️ Token expiring soon ($minutesUntilExpiry minutes), refreshing...');
              await _refreshAccessToken();
            }
          }
        }
      } catch (e) {}

      options.headers['Authorization'] = 'Bearer $token';
    }

    final userData = _prefs.getString(AppConstants.userDataKey);
    if (userData != null) {
      try {
        final userJson = json.decode(userData);
        final userId = userJson['id'];
        if (userId != null) {
          options.headers['X-User-ID'] = userId.toString();
        }
      } catch (e) {}
    }

    if (kDebugMode) {
      debugLog(
          'ApiService', '🌐 API Request: ${options.method} ${options.path}');
      if (options.data != null && options.data is Map) {
        final data = options.data as Map;
        final safeData = Map.from(data);

        if (safeData.containsKey('password')) safeData['password'] = '***';
        if (safeData.containsKey('token')) safeData['token'] = '***';
        debugLog('ApiService', '📦 Request Body: $safeData');
      }
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    debugLog('ApiService',
        '✅ API Response: ${response.statusCode} ${response.requestOptions.path}');

    if (kDebugMode && response.data != null) {
      debugLog('ApiService', '📦 Response Body: ${response.data}');
    }

    // Reset retry count on successful response
    final path = response.requestOptions.path;
    _retryCounts.remove(path);

    handler.next(response);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) async {
    debugLog('ApiService', '❌ API Error: ${error.type} - ${error.message}');
    debugLog('ApiService', '📡 URL: ${error.requestOptions.path}');

    final path = error.requestOptions.path;
    final currentRetryCount = _retryCounts[path] ?? 0;

    // Handle rate limiting (429)
    if (error.response?.statusCode == 429) {
      debugLog('ApiService', '⚠️ Rate limited (429)');

      if (currentRetryCount < _maxRetries) {
        // Increment retry count
        _retryCounts[path] = currentRetryCount + 1;

        // Calculate exponential backoff delay
        final delaySeconds = _baseRetryDelaySeconds *
            (1 << currentRetryCount); // 2, 4, 8 seconds
        debugLog('ApiService',
            '⏱️ Exponential backoff: waiting $delaySeconds seconds (attempt ${currentRetryCount + 1}/$_maxRetries)');

        await Future.delayed(Duration(seconds: delaySeconds));

        // Retry the request
        try {
          final response = await _dio.request(
            error.requestOptions.path,
            data: error.requestOptions.data,
            queryParameters: error.requestOptions.queryParameters,
            options: Options(
              method: error.requestOptions.method,
              headers: error.requestOptions.headers,
            ),
          );
          handler.resolve(response);
          return;
        } catch (retryError) {
          // If retry also fails, continue with error handling
          debugLog('ApiService', '❌ Retry $path failed: $retryError');
        }
      } else {
        debugLog(
            'ApiService', '❌ Max retries ($_maxRetries) reached for $path');
        _retryCounts.remove(path);

        // Return a friendly error response
        handler.resolve(Response(
          requestOptions: error.requestOptions,
          statusCode: 429,
          data: 'Too many requests. Please try again later.',
        ));
        return;
      }
    }

    // Handle non-JSON responses (like plain text error messages)
    if (error.response?.data is String) {
      final stringResponse = error.response?.data as String;
      debugLog('ApiService', '📦 String Response: $stringResponse');

      // Return a structured error
      handler.resolve(Response(
        requestOptions: error.requestOptions,
        statusCode: error.response?.statusCode ?? 500,
        data: {
          'success': false,
          'message': stringResponse,
        },
      ));
      return;
    }

    if (error.response?.data != null && error.response!.data is Map) {
      final responseData = error.response!.data as Map<String, dynamic>;
      debugLog('ApiService', '📦 Response: ${responseData['message']}');
    }

    if (error.response?.statusCode == 401) {
      final responseData = error.response?.data;
      final errorMessage =
          responseData is Map ? responseData['message']?.toString() : '';

      debugLog('ApiService', '🔑 401 Unauthorized: $errorMessage');

      if (!_isRefreshingToken && errorMessage?.contains('expired') == true) {
        _isRefreshingToken = true;

        try {
          debugLog('ApiService', '🔄 Attempting token refresh...');

          final refreshed = await _refreshAccessToken();

          if (refreshed) {
            debugLog('ApiService', '✅ Token refreshed, retrying request');

            final newToken =
                await _secureStorage.read(key: AppConstants.tokenKey);

            final newHeaders =
                Map<String, dynamic>.from(error.requestOptions.headers);
            newHeaders['Authorization'] = 'Bearer $newToken';

            final options = Options(
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
              requestEncoder: error.requestOptions.requestEncoder,
              responseDecoder: error.requestOptions.responseDecoder,
              listFormat: error.requestOptions.listFormat,
            );

            try {
              final retryResponse = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: options,
              );

              handler.resolve(retryResponse);
              return;
            } catch (retryError) {
              debugLog('ApiService', '❌ Retry failed: $retryError');
            }
          } else {
            debugLog('ApiService', '❌ Token refresh failed');
          }
        } catch (e) {
          debugLog('ApiService', '❌ Error during token refresh: $e');
        } finally {
          _isRefreshingToken = false;
        }
      } else if (_isRefreshingToken) {
        debugLog('ApiService',
            '⚠️ Token refresh already in progress, queuing request');

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
      final currentToken =
          await _secureStorage.read(key: AppConstants.tokenKey);

      if (refreshToken == null || currentToken == null) {
        debugLog('ApiService', '❌ No tokens available for refresh');
        return false;
      }

      debugLog('ApiService', '🔄 Attempting to refresh access token...');

      try {
        final response = await _dio.post(
          '/auth/refresh-access',
          data: {'refreshToken': refreshToken},
          options: Options(
            headers: {'Authorization': 'Bearer $currentToken'},
          ),
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'];
          final newToken = data['token'];

          if (newToken != null && newToken is String) {
            await _secureStorage.write(
              key: AppConstants.tokenKey,
              value: newToken,
            );

            debugLog('ApiService', '✅ Access token refreshed successfully');
            return true;
          }
        }
      } catch (endpointError) {
        debugLog('ApiService', '⚠️ Refresh endpoint failed: $endpointError');
      }

      try {
        final validationResponse = await _dio.get(
          AppConstants.validateStudentTokenEndpoint,
          options: Options(
            headers: {'Authorization': 'Bearer $currentToken'},
          ),
        );

        if (validationResponse.statusCode == 200) {
          debugLog('ApiService', '✅ Token still valid, no refresh needed');
          return true;
        }
      } catch (validateError) {
        debugLog('ApiService', '❌ Token validation failed');
      }

      debugLog(
          'ApiService', '⚠️ All refresh methods failed, token may be invalid');
      return false;
    } catch (e) {
      debugLog('ApiService', '❌ Token refresh failed: $e');
      return false;
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> register(
      String username, String password, String deviceId,
      {String? fcmToken}) async {
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

      debugLog('ApiService', 'Register response: ${response.data}');

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        if (data == null) {
          throw ApiError(message: 'No data received from server');
        }

        Map<String, dynamic> userData;
        String token;

        if (data is Map && data.containsKey('user')) {
          userData = Map<String, dynamic>.from(data['user']);
          token = data['token']?.toString() ?? '';
        } else if (data is Map) {
          userData = Map<String, dynamic>.from(data);
          token = data['token']?.toString() ?? '';
        } else {
          throw ApiError(message: 'Invalid response format from server');
        }

        if (!userData.containsKey('id') || !userData.containsKey('username')) {
          throw ApiError(message: 'Invalid user data received');
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Registration successful',
          data: {
            'user': userData,
            'token': token,
          },
        );
      } else {
        throw ApiError(
            message:
                response.data['message']?.toString() ?? 'Registration failed');
      }
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message']?.toString() ?? 'Registration failed',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<void>> updateFcmToken(String fcmToken) async {
    try {
      final response = await _dio.put(
        '/users/fcm-token',
        data: {'fcm_token': fcmToken},
      );

      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update FCM token',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> studentLogin(String username,
      String password, String deviceId, String? fcmToken) async {
    try {
      debugLog('ApiService', '🔐 Login with device ID: $deviceId');

      final response = await _dio.post(
        AppConstants.studentLoginEndpoint,
        data: {
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'fcmToken': fcmToken,
        },
      );

      debugLog('ApiService', 'Login response status: ${response.statusCode}');
      debugLog('ApiService', 'Login response data: ${response.data}');

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
          throw ApiError(message: 'Invalid response format from server');
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
          message: response.data['message']?.toString() ?? 'Login successful',
          data: data,
        );
      } else {
        throw ApiError(
            message: response.data['message']?.toString() ?? 'Login failed');
      }
    } on DioException catch (e) {
      debugLog('ApiService', 'DioException in studentLogin: ${e.type}');

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

  Future<void> logout() async {
    try {
      await _dio.post(AppConstants.logoutEndpoint);
    } catch (e) {
      debugLog('ApiService', 'Logout error (ignored): $e');
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
          key == 'session_start' ||
          key.startsWith('cache_')) {
        await _prefs.remove(key);
      }
    }

    debugLog('ApiService', '✅ User data cleared');
  }

  Future<ApiResponse<List<School>>> getSchools() async {
    try {
      final response = await _dio.get(AppConstants.schoolsEndpoint);

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        List<School> schools;
        if (data is List) {
          schools = data.map((json) => School.fromJson(json)).toList();
        } else {
          schools = [];
        }

        return ApiResponse<List<School>>(
          success: true,
          message: response.data['message']?.toString() ??
              'Schools fetched successfully',
          data: schools,
        );
      } else {
        throw ApiError(
            message: response.data['message']?.toString() ??
                'Failed to fetch schools');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw ApiError(message: 'Too many requests. Please try again later.');
      }
      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to fetch schools',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> selectSchool(int schoolId) async {
    try {
      final response = await _dio.put(
        AppConstants.updateProfileEndpoint,
        data: {'school_id': schoolId},
      );

      if (response.data is Map && response.data['success'] == true) {
        return ApiResponse(
            success: true, message: response.data['message']!.toString());
      } else {
        throw ApiError(
            message: response.data['message']?.toString() ??
                'Failed to select school');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final retryResponse = await _dio.put(
            AppConstants.updateProfileEndpoint,
            data: {'school_id': schoolId},
          );

          if (retryResponse.data is Map &&
              retryResponse.data['success'] == true) {
            return ApiResponse(
                success: true,
                message: retryResponse.data['message']!.toString());
          }
        }
      }

      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to select school',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // UPDATED: getAllSettings method that tries /settings/all first, then falls back to categories
  Future<ApiResponse<List<Setting>>> getAllSettings() async {
    try {
      debugLog('ApiService', '📋 Loading ALL settings from backend...');

      // First try to get all settings via the /settings/all endpoint
      try {
        final response = await _dio.get('/settings/all');
        debugLog(
            'ApiService', '✅ All settings response: ${response.statusCode}');

        return ApiResponse.fromJson(
          response.data,
          (data) {
            if (data is List) {
              debugLog('ApiService', '✅ Parsed ${data.length} total settings');
              // Log the categories found
              final categories =
                  data.map((s) => s['category']).toSet().toList();
              debugLog('ApiService', '📊 Categories found: $categories');
              return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
            } else if (data is Map<String, dynamic> && data['data'] != null) {
              final settingsData = data['data'];
              if (settingsData is List) {
                debugLog('ApiService',
                    '✅ Parsing ${settingsData.length} settings from data field');
                final categories =
                    settingsData.map((s) => s['category']).toSet().toList();
                debugLog('ApiService', '📊 Categories found: $categories');
                return List<Setting>.from(
                    settingsData.map((x) => Setting.fromJson(x)));
              }
            }
            return <Setting>[];
          },
        );
      } catch (e) {
        debugLog('ApiService', '⚠️ /settings/all failed: $e');
        debugLog('ApiService', '⚠️ Falling back to multiple category calls');

        // Fallback: Load multiple categories
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
              debugLog('ApiService',
                  '✅ Loaded ${response.data!.length} $category settings');
            }
          } catch (e) {
            debugLog('ApiService', '⚠️ Failed to load $category settings: $e');
          }
        }

        debugLog('ApiService',
            '✅ Total settings loaded from categories: ${allSettings.length}');
        return ApiResponse<List<Setting>>(
          success: true,
          message: 'Loaded ${allSettings.length} settings from categories',
          data: allSettings,
        );
      }
    } catch (e) {
      debugLog('ApiService', '❌ Error getting all settings: $e');
      return ApiResponse<List<Setting>>(
        success: false,
        message: 'Failed to fetch settings: $e',
        data: [],
      );
    }
  }

  Future<ApiResponse<List<Setting>>> getPaymentSettingsDirect() async {
    try {
      debugLog('ApiService', '💰 Getting payment settings directly...');

      final response = await _dio.get('/settings/category/payment');

      debugLog('ApiService',
          '💰 Direct payment settings response: ${response.statusCode}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            debugLog('ApiService',
                '💰 Found ${data.length} payment settings directly');
            for (final item in data) {
              if (item is Map<String, dynamic>) {
                final key = item['setting_key'] ?? 'unknown';
                final value = item['setting_value'] ?? 'null';
                debugLog('ApiService', '💰   - $key: $value');
              }
            }
            return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
          }
          return <Setting>[];
        },
      );
    } catch (e) {
      debugLog('ApiService', '❌ Error getting payment settings directly: $e');
      return ApiResponse<List<Setting>>(
        success: false,
        message: 'Failed to get payment settings: $e',
        data: [],
      );
    }
  }

  Future<ApiResponse<List<Category>>> getCategories() async {
    try {
      final response = await _dio.get(AppConstants.categoriesEndpoint);

      debugLog('ApiService', 'getCategories response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map<Category>((item) {
              try {
                return Category.fromJson(item);
              } catch (e) {
                debugLog(
                    'ApiService', 'Error parsing category: $e\nData: $item');

                return Category(
                  id: item['id'] ?? 0,
                  name: item['name'] ?? 'Unknown Category',
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
      debugLog('ApiService', 'getCategories Dio error: ${e.response?.data}');
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch categories',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitDeviceChangePayment({
    required String username,
    required String password,
    required String paymentMethod,
    required double amount,
    required String proofImagePath,
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.submitPaymentEndpoint,
        data: {
          'username': username,
          'password': password,
          'payment_method': paymentMethod,
          'payment_type': 'device_change',
          'amount': amount,
          'proof_image_path': proofImagePath,
          'device_id': deviceId,
        },
      );
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to submit device change payment',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCoursesByCategory(
      int categoryId) async {
    try {
      final response =
          await _dio.get(AppConstants.coursesByCategory(categoryId));

      debugLog('ApiService', 'getCoursesByCategory response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is Map<String, dynamic>) {
            final coursesData = data['courses'] ?? data['data'] ?? [];
            List<dynamic> coursesList = [];

            if (coursesData is List) {
              coursesList = coursesData;
            }

            return {
              'courses': coursesList,
              'category_id': categoryId,
            };
          }
          return {'courses': [], 'category_id': categoryId};
        },
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', 'getCoursesByCategory Dio error: ${e.response?.data}');
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
        response.data,
        (data) => data as Map<String, dynamic>,
      );
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
      final response = await _dio.get(AppConstants.videosByChapter(chapterId));
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch videos',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getNotesByChapter(
      int chapterId) async {
    try {
      final response = await _dio.get(AppConstants.notesByChapter(chapterId));
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
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
        response.data,
        (data) => data as Map<String, dynamic>,
      );
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

      debugLog('ApiService', 'getAvailableExams response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          List<Exam> exams = [];

          if (data['data'] is List) {
            exams = (data['data'] as List).map<Exam>((item) {
              return Exam.fromJson(item);
            }).toList();
          }

          return ApiResponse<List<Exam>>(
            success: true,
            message: data['message']?.toString() ?? 'Exams retrieved',
            data: exams,
          );
        } else {
          return ApiResponse<List<Exam>>(
            success: false,
            message: data['message']?.toString() ?? 'Failed to fetch exams',
            data: [],
          );
        }
      }

      return ApiResponse<List<Exam>>(
        success: false,
        message: 'Invalid response format',
        data: [],
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', 'getAvailableExams Dio error: ${e.response?.data}');
      throw ApiError(
        message:
            e.response?.data['message']?.toString() ?? 'Failed to fetch exams',
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

      debugLog('ApiService', 'getExamQuestions response: ${response.data}');

      // ✅ FIXED: Handle the response directly without double-parsing
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          List<ExamQuestion> questions = [];

          // Check if data['data'] exists and is a List
          if (data.containsKey('data') && data['data'] is List) {
            final items = data['data'] as List;
            debugLog(
                'ApiService', 'Found data list with ${items.length} items');

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
                hasAnswer: false,
              );
            }).toList();
          } else {
            debugLog('ApiService', 'No data field found in response');
          }

          debugLog('ApiService', 'Parsed ${questions.length} exam questions');

          // Return ApiResponse with the questions list directly
          return ApiResponse<List<ExamQuestion>>(
            success: true,
            message: data['message']?.toString() ?? 'Exam questions retrieved',
            data: questions,
          );
        } else {
          return ApiResponse<List<ExamQuestion>>(
            success: false,
            message:
                data['message']?.toString() ?? 'Failed to fetch exam questions',
            data: [],
          );
        }
      } else if (response.data is List) {
        // Handle direct list response
        final items = response.data as List;
        debugLog(
            'ApiService', 'Response is direct List with ${items.length} items');

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
            hasAnswer: false,
          );
        }).toList();

        debugLog('ApiService', 'Parsed ${questions.length} exam questions');

        return ApiResponse<List<ExamQuestion>>(
          success: true,
          message: 'Exam questions retrieved successfully',
          data: questions,
        );
      }

      return ApiResponse<List<ExamQuestion>>(
        success: false,
        message: 'Invalid response format',
        data: [],
      );
    } on DioException catch (e) {
      debugLog('ApiService', 'getExamQuestions error: ${e.response?.data}');
      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to fetch exam questions',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> saveExamProgress(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final response = await _dio.post(
        AppConstants.examProgressEndpoint(examResultId),
        data: {'answers': answers},
      );
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
        data: {'answers': answers},
      );
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
        (data) {
          if (data is List) {
            return data
                .map<ExamResult>((item) => ExamResult.fromJson(item))
                .toList();
          }
          return <ExamResult>[];
        },
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch exam results',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<ExamResult>> getExamResult(int examResultId) async {
    try {
      final response =
          await _dio.get(AppConstants.examResultByIdEndpoint(examResultId));
      return ApiResponse.fromJson(
          response.data, (data) => ExamResult.fromJson(data));
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch exam result',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>>
      checkHasActiveSubscriptionForCategory(int categoryId) async {
    try {
      final response = await _dio.get(
        '/api/v1/subscriptions/has-active/$categoryId',
      );

      debugLog('ApiService',
          'checkHasActiveSubscriptionForCategory response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        return ApiResponse<Map<String, dynamic>>(
          success: data['success'] ?? false,
          message: data['message']?.toString() ?? 'Subscription status checked',
          data: data['data'] ?? data,
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Invalid response format',
        data: {'has_active_subscription': false},
      );
    } on DioException catch (e) {
      debugLog('ApiService',
          'checkHasActiveSubscriptionForCategory Dio error: ${e.response?.data}');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message']?.toString() ??
            'Failed to check subscription status',
        data: {'has_active_subscription': false},
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? proofImagePath,
  }) async {
    try {
      debugLog('ApiService',
          'Submitting payment: category=$categoryId, amount=$amount, method=$paymentMethod, proof=$proofImagePath');

      final response = await _dio.post(
        AppConstants.submitPaymentEndpoint,
        data: {
          'category_id': categoryId,
          'payment_type': paymentType,
          'payment_method': paymentMethod,
          'amount': amount,
          'proof_image_path': proofImagePath,
        },
      );

      debugLog('ApiService', 'Payment submission response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        if (data['has_pending_payment'] == true) {
          return ApiResponse<Map<String, dynamic>>(
            success: false,
            message: data['message'] ?? 'Payment already pending',
            data: data['data'] ?? data,
          );
        }

        return ApiResponse<Map<String, dynamic>>(
          success: data['success'] ?? false,
          message: data['message']?.toString() ?? 'Payment submitted',
          data: data['data'] ?? data,
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Invalid response format',
        data: {'success': false, 'message': 'Invalid response'},
      );
    } on DioException catch (e) {
      debugLog('ApiService', 'Submit payment Dio error: ${e.response?.data}');

      if (e.response?.statusCode == 400 &&
          e.response?.data is Map<String, dynamic> &&
          (e.response?.data['has_pending_payment'] == true)) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: e.response?.data['message'] ?? 'Payment already pending',
          data: e.response?.data['data'] ?? e.response?.data,
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message']?.toString() ??
            'Failed to submit payment',
        data: {'success': false, 'error': e.toString()},
      );
    }
  }

  Future<ApiResponse<List<Payment>>> getMyPayments() async {
    try {
      final response = await _dio.get(AppConstants.myPaymentsEndpoint);

      debugLog('ApiService', 'getMyPayments response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map<Payment>((item) {
              try {
                return Payment.fromJson(item);
              } catch (e) {
                debugLog(
                    'ApiService', 'Error parsing payment: $e\nData: $item');

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
                  categoryName: item['category_name'] ?? 'Unknown Category',
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
      debugLog('ApiService', 'getMyPayments Dio error: ${e.response?.data}');
      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to fetch payments',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Subscription>>> getMySubscriptions() async {
    try {
      final response = await _dio.get(AppConstants.mySubscriptionsEndpoint);

      debugLog('ApiService', 'getMySubscriptions response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          List<Subscription> subscriptions = [];

          if (data['data'] is List) {
            subscriptions = (data['data'] as List).map<Subscription>((item) {
              try {
                return Subscription.fromJson(item);
              } catch (e) {
                debugLog('ApiService',
                    'Error parsing subscription: $e\nData: $item');

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
                  status: item['current_status'] ?? item['status'] ?? 'active',
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
            }).toList();
          }

          return ApiResponse<List<Subscription>>(
            success: true,
            message: data['message']?.toString() ?? 'Subscriptions retrieved',
            data: subscriptions,
          );
        } else {
          return ApiResponse<List<Subscription>>(
            success: false,
            message:
                data['message']?.toString() ?? 'Failed to fetch subscriptions',
            data: [],
          );
        }
      }

      return ApiResponse<List<Subscription>>(
        success: false,
        message: 'Invalid response format',
        data: [],
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', 'getMySubscriptions Dio error: ${e.response?.data}');
      return ApiResponse<List<Subscription>>(
        success: false,
        message: e.response?.data['message']?.toString() ??
            'Failed to fetch subscriptions',
        data: [],
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> checkSubscriptionStatus(
      int categoryId) async {
    try {
      final response = await _dio.get(
        AppConstants.checkSubscriptionStatusEndpoint,
        queryParameters: {'category_id': categoryId},
      );

      debugLog(
          'ApiService', 'checkSubscriptionStatus response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        return ApiResponse<Map<String, dynamic>>(
          success: data['success'] ?? false,
          message: data['message']?.toString() ?? 'Status checked',
          data: data['data'] ?? data,
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Invalid response format',
        data: {'has_subscription': false, 'status': 'unpaid'},
      );
    } on DioException catch (e) {
      debugLog('ApiService',
          'checkSubscriptionStatus Dio error: ${e.response?.data}');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: e.response?.data['message']?.toString() ??
            'Failed to check subscription status',
        data: {'has_subscription': false, 'status': 'error'},
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
      final response = await _dio.post(
        AppConstants.pairTvDeviceEndpoint,
        data: {'tv_device_id': tvDeviceId},
      );
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
      final response = await _dio.post(
        AppConstants.verifyTvPairingEndpoint,
        data: {'pairing_code': pairingCode},
      );
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to verify pairing',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<int>> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return ApiResponse.fromJson(
        response.data,
        (data) => (data['unread_count'] as num).toInt(),
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to get unread count',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _dio.put(
        '${AppConstants.notificationsEndpoint}/$notificationId/read',
      );
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
      final response = await _dio.put(
        '${AppConstants.notificationsEndpoint}/mark-all-read',
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to mark all notifications as read',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> deleteNotification(int notificationId) async {
    try {
      final response = await _dio.delete(
        '${AppConstants.notificationsEndpoint}/$notificationId',
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to delete notification',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> deleteAllNotifications() async {
    try {
      final response = await _dio.delete(
        '${AppConstants.notificationsEndpoint}/delete-all',
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to delete all notifications',
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

      debugLog('ApiService', 'Parent link response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          debugLog('ApiService', 'Parsing parent link data: $data');
          return ParentLink.fromJson(data);
        },
      );
    } on DioException catch (e) {
      debugLog('ApiService', 'Parent link error: ${e.response?.data}');
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

  Future<ApiResponse<Map<String, dynamic>>> getUserProgress(
      int chapterId) async {
    try {
      final response = await _dio.get('/progress/chapter/$chapterId');
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch progress',
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

  Future<ApiResponse<void>> updateMyProfile({
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final response = await _dio.put(
        AppConstants.updateProfileEndpoint,
        data: {
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (profileImage != null) 'profile_image': profileImage,
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
      final response = await _dio.put(
        AppConstants.updateDeviceEndpoint,
        data: {'device_type': deviceType, 'device_id': deviceId},
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update device',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Setting>>> getPublicSettings() async {
    try {
      final response = await _dio.get(AppConstants.publicSettingsEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) => List<Setting>.from(data.map((x) => Setting.fromJson(x))),
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch settings',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // UPDATED: getSettingsByCategory with better logging
  Future<ApiResponse<List<Setting>>> getSettingsByCategory(
      String category) async {
    try {
      debugLog('ApiService', '📋 Loading settings for category: $category');

      final response = await _dio.get('/settings/category/$category');

      debugLog('ApiService',
          'Settings by category response: ${response.statusCode}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            debugLog('ApiService', 'Parsing ${data.length} $category settings');
            return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
          } else if (data is Map<String, dynamic> && data['data'] != null) {
            final settingsData = data['data'];
            if (settingsData is List) {
              debugLog('ApiService',
                  'Parsing ${settingsData.length} $category settings from data field');
              return List<Setting>.from(
                  settingsData.map((x) => Setting.fromJson(x)));
            }
          }
          debugLog('ApiService', '⚠️ No $category settings data found');
          return <Setting>[];
        },
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', '❌ getSettingsByCategory error: ${e.response?.data}');
      debugLog('ApiService', '❌ Error URL: ${e.requestOptions.path}');

      if (e.response?.statusCode == 404) {
        debugLog('ApiService', '⚠️ 404 error for /settings/category/$category');
      }

      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to fetch $category settings',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
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

      debugLog('ApiService', 'Uploading file to: $endpoint');

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      debugLog('ApiService', 'Upload response: ${response.data}');

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['data'] != null) {
          final data = responseData['data'];
          if (data is String) {
            return ApiResponse<String>(
              success: responseData['success'] ?? true,
              message:
                  responseData['message']?.toString() ?? 'Upload successful',
              data: data,
            );
          } else if (data is Map<String, dynamic> &&
              data['file_path'] != null) {
            return ApiResponse<String>(
              success: responseData['success'] ?? true,
              message:
                  responseData['message']?.toString() ?? 'Upload successful',
              data: data['file_path'].toString(),
            );
          }
        } else if (responseData['file_path'] != null) {
          return ApiResponse<String>(
            success: true,
            message: responseData['message']?.toString() ?? 'Upload successful',
            data: responseData['file_path'].toString(),
          );
        }
      }

      final String url;
      if (responseData is Map<String, dynamic>) {
        url = responseData.toString();
      } else {
        url = responseData?.toString() ?? '';
      }

      return ApiResponse<String>(
        success: true,
        message: 'File uploaded successfully',
        data: url,
      );
    } on DioException catch (e) {
      debugLog('ApiService', 'Upload file error: ${e.response?.data}');
      throw ApiError(
        message:
            e.response?.data['message']?.toString() ?? 'Failed to upload file',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<String>> uploadImage(File imageFile) async {
    try {
      final response = await uploadFile(imageFile, 'image');
      return response;
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
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      debugLog('ApiService', '📸 Uploading payment proof...');

      final response = await _dio.post(
        AppConstants.uploadPaymentProofEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
        ),
      );

      debugLog('ApiService', '📸 Upload response: ${response.data}');

      final responseData = response.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['success'] == true) {
          String? fileUrl;

          if (responseData['data'] is String) {
            fileUrl = responseData['data'];
          } else if (responseData['data'] != null) {
            if (responseData['data'] is Map) {
              final dataMap = responseData['data'] as Map;
              if (dataMap['url'] != null) {
                fileUrl = dataMap['url'].toString();
              } else if (dataMap['secure_url'] != null) {
                fileUrl = dataMap['secure_url'].toString();
              } else if (dataMap['file_path'] != null) {
                fileUrl = dataMap['file_path'].toString();
              }
            }
          } else if (responseData['url'] != null) {
            fileUrl = responseData['url'];
          } else if (responseData['secure_url'] != null) {
            fileUrl = responseData['secure_url'];
          } else if (responseData['file_path'] != null) {
            fileUrl = responseData['file_path'];
          }

          if (fileUrl != null && fileUrl.isNotEmpty) {
            debugLog('ApiService', '✅ Payment proof URL: $fileUrl');
            return ApiResponse<String>(
              success: true,
              message: responseData['message'] ?? 'Upload successful',
              data: fileUrl,
            );
          } else {
            debugLog('ApiService', '❌ No URL found in response');
          }
        } else {
          debugLog('ApiService',
              '❌ Upload not successful: ${responseData['message']}');
        }
      }

      debugLog('ApiService', '⚠️ Using fallback response parsing');
      return ApiResponse<String>(
        success: responseData['success'] ?? false,
        message:
            responseData['message']?.toString() ?? 'Upload response received',
        data: responseData['data']?.toString() ?? responseData.toString(),
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', '❌ Payment proof upload error: ${e.response?.data}');
      throw ApiError(
        message: e.response?.data['message']?.toString() ??
            'Failed to upload payment proof',
        statusCode: e.response?.statusCode,
        data: e.response?.data,
      );
    }
  }

  Future<ApiResponse<void>> incrementVideoViewCount(int videoId) async {
    try {
      final response =
          await _dio.post(AppConstants.incrementViewEndpoint(videoId));
      return ApiResponse(
          success: true,
          message: response.data['message'] ?? 'View count updated');
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to update view count',
        statusCode: e.response?.statusCode,
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

  Future<ApiResponse<Map<String, dynamic>>> getExamResultDetails(
      int examResultId) async {
    try {
      final response =
          await _dio.get('${AppConstants.examResultsEndpoint}/$examResultId');
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to fetch exam result details',
        statusCode: e.response?.statusCode,
      );
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
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to save progress',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<String>>> getSettingsCategories() async {
    try {
      final response = await _dio.get(AppConstants.settingsCategoriesEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => List<String>.from(data['data'] ?? []));
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to fetch settings categories',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Setting>> getSettingByKey(String key) async {
    try {
      final response = await _dio.get(AppConstants.settingByKeyEndpoint(key));
      return ApiResponse.fromJson(
          response.data, (data) => Setting.fromJson(data));
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch setting',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getDeviceInfo() async {
    try {
      final response = await _dio.get(AppConstants.deviceInfoEndpoint);
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch device info',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCourseDetails(
      int courseId) async {
    try {
      final response = await _dio.get('/courses/$courseId');
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to fetch course details',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> approveDeviceChange({
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/approve-device-change',
        data: {
          'password': password,
          'deviceId': deviceId,
        },
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiError(
        message:
            e.response?.data['message'] ?? 'Failed to approve device change',
        statusCode: e.response?.statusCode,
      );
    }
  }

  T _parseResponseData<T>(dynamic data) {
    if (data is T) {
      return data;
    }
    throw FormatException('Invalid response format, expected $T');
  }
}
