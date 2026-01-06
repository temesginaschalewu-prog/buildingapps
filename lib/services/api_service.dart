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
      String username, String password) async {
    try {
      final response = await _dio.post(
        AppConstants.registerEndpoint,
        data: {'username': username, 'password': password},
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

  Future<ApiResponse<Map<String, dynamic>>> studentLogin(
      String username, String password, String? deviceId) async {
    try {
      final response = await _dio.post(
        AppConstants.studentLoginEndpoint,
        data: {
          'username': username,
          'password': password,
          'deviceId': deviceId,
        },
      );

      debugLog('ApiService', 'Login response status: ${response.statusCode}');
      debugLog('ApiService', 'Login response data: ${response.data}');

      // Check if response has success: false
      if (response.data is Map && response.data['success'] == false) {
        // This is an error response even if status code is 200
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

      // Handle 403 specifically
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

  Future<ApiResponse<List<Category>>> getCategories() async {
    try {
      final response = await _dio.get(AppConstants.categoriesEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) => List<Category>.from(data.map((x) => Category.fromJson(x))),
      );
    } on DioException catch (e) {
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
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
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

      return ApiResponse.fromJson(
        response.data,
        (data) {
          if (data is List) {
            return data.map<Exam>((item) => Exam.fromJson(item)).toList();
          }
          return <Exam>[];
        },
      );
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

  Future<ApiResponse<Map<String, dynamic>>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
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
          'proof_image_path': proofImagePath,
        },
      );
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to submit payment',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ApiResponse<List<Payment>>> getMyPayments() async {
    try {
      final response = await _dio.get(AppConstants.myPaymentsEndpoint);
      return ApiResponse.fromJson(
        response.data,
        (data) => List<Payment>.from(data.map((x) => Payment.fromJson(x))),
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
      return ApiResponse.fromJson(
        response.data,
        (data) =>
            List<Subscription>.from(data.map((x) => Subscription.fromJson(x))),
      );
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to fetch subscriptions',
        statusCode: e.response?.statusCode,
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
      return ApiResponse.fromJson(
          response.data, (data) => data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ??
            'Failed to check subscription status',
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

      return ApiResponse.fromJson(response.data, (data) => data['file_path']);
    } on DioException catch (e) {
      throw ApiError(
        message: e.response?.data['message'] ?? 'Failed to upload file',
        statusCode: e.response?.statusCode,
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
      return await uploadImage(imageFile);
    } catch (e) {
      throw ApiError(message: 'Failed to upload payment proof: $e');
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
      final response =
          await _dio.get('${AppConstants.coursesEndpoint}/$courseId');
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
