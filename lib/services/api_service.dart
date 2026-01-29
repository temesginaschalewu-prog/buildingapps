// ignore_for_file: only_throw_errors

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
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(AppConstants.deviceIdKey);
    if (deviceId != null) {
      options.headers['X-Device-ID'] = deviceId;
    }

    if (kDebugMode) {
      debugLog(
          'ApiService', '🌐 API Request: ${options.method} ${options.path}');
      if (options.data != null) {
        debugLog('ApiService', '📦 Request Body: ${options.data}');
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

    handler.next(response);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) async {
    debugLog('ApiService', '❌ API Error: ${error.type} - ${error.message}');
    debugLog('ApiService', '📡 URL: ${error.requestOptions.path}');
    debugLog('ApiService', '📦 Response: ${error.response?.data}');

    if (error.response?.statusCode == 429) {
      debugLog('ApiService', '⚠️ Rate limited, waiting before retry...');
      await Future.delayed(const Duration(seconds: 2));

      handler.next(error);
      return;
    }

    if (error.response?.statusCode == 401) {
      if (!_isRefreshingToken) {
        _isRefreshingToken = true;
        final refreshed = await _refreshToken();
        _isRefreshingToken = false;

        if (refreshed) {
          try {
            final request = error.requestOptions;
            final retryResponse = await _dio.request(
              request.path,
              data: request.data,
              queryParameters: request.queryParameters,
              options:
                  Options(method: request.method, headers: request.headers),
            );
            handler.resolve(retryResponse);
            return;
          } catch (retryError) {
            debugLog('ApiService', '❌ Retry failed: $retryError');
          }
        }
      }
    }

    handler.next(error);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken =
          await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        debugLog('ApiService', 'No refresh token found');
        return false;
      }

      debugLog('ApiService', '🔄 Refreshing token...');
      final response = await _dio.post(
        AppConstants.refreshTokenEndpoint,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final newToken = data['token'];
        final newRefreshToken = data['refreshToken'] ?? data['deviceToken'];

        if (newToken != null) {
          await _secureStorage.write(
              key: AppConstants.tokenKey, value: newToken);

          if (newRefreshToken != null) {
            await _secureStorage.write(
                key: AppConstants.refreshTokenKey, value: newRefreshToken);
          }

          debugLog('ApiService', '✅ Token refreshed successfully');
          return true;
        }
      }

      debugLog('ApiService', '❌ Token refresh failed: ${response.data}');
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

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'];

        Map<String, dynamic> userData;
        if (data is Map && data['user'] != null) {
          userData = Map<String, dynamic>.from(data);
        } else if (data is Map) {
          userData = Map<String, dynamic>.from(data);
        } else {
          throw ApiError(message: 'Invalid response format from server');
        }

        final user = User.fromJson(userData['user'] ?? userData);
        final token = userData['token'];

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.data['message'] ?? 'Registration successful',
          data: {
            'user': user,
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
      String password, String? deviceId, String? fcmToken) async {
    try {
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
        throw ApiError(
          message: e.response?.data['message']?.toString() ??
              'Device change required',
          statusCode: 403,
          data: e.response?.data,
          action: e.response?.data['action'],
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
      await _secureStorage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
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
        final refreshed = await _refreshToken();
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

  Future<ApiResponse<List<Setting>>> getAllSettings() async {
    try {
      final response = await _dio.get('/api/v1/settings');
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
      return ApiResponse.fromJson(
        response.data,
        (data) =>
            List<ExamQuestion>.from(data.map((x) => ExamQuestion.fromJson(x))),
      );
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

  Future<ApiResponse<List<UserProgress>>> getUserProgressForCourse(
      int courseId) async {
    try {
      final response = await _dio
          .get('${AppConstants.userProgressEndpoint}/course/$courseId');
      return ApiResponse.fromJson(
        response.data,
        (data) =>
            List<UserProgress>.from(data.map((x) => UserProgress.fromJson(x))),
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch user progress',
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

  Future<ApiResponse<List<Setting>>> getSettingsByCategory(
      String category) async {
    try {
      final response =
          await _dio.get(AppConstants.settingsByCategory(category));

      debugLog(
          'ApiService', 'getSettingsByCategory response: ${response.data}');

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return List<Setting>.from(data.map((x) => Setting.fromJson(x)));
          }
          return <Setting>[];
        },
      );
    } on DioException catch (e) {
      debugLog(
          'ApiService', 'getSettingsByCategory Dio error: ${e.response?.data}');
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch settings',
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

      // FIX: Use the correct payment proof endpoint
      final response = await _dio.post(
        AppConstants
            .uploadPaymentProofEndpoint, // THIS IS THE FIX: '/upload/payment-proof'
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

          // Try different response formats
          if (responseData['data'] is String) {
            fileUrl = responseData['data'];
          } else if (responseData['data'] != null) {
            // If data is not string but an object, try to extract URL
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

      // Fallback: if we can't parse the URL, return the entire response data as string
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

  Future<ApiResponse<UserProgress>> getUserProgress(int chapterId) async {
    try {
      final response =
          await _dio.get(AppConstants.userProgressByChapterEndpoint(chapterId));
      return ApiResponse.fromJson(
          response.data, (data) => UserProgress.fromJson(data));
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch user progress',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<void>> saveUserProgress(UserProgress progress) async {
    try {
      final response = await _dio.post(
        AppConstants.userProgressEndpoint,
        data: progress.toJson(),
      );
      return ApiResponse(success: true, message: response.data['message']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to save user progress',
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
