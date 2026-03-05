import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/parsers.dart';

class ExamProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Exam> _availableExams = [];
  List<ExamResult> _myExamResults = [];
  Map<int, List<Exam>> _examsByCourse = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, bool> _isLoadingCourse = {};
  bool _isLoading = false;
  String? _error;
  Timer? _cacheCleanupTimer;

  final Map<int, bool> _pendingPaymentsByCategory = {};

  StreamController<List<Exam>> _examsUpdateController =
      StreamController<List<Exam>>.broadcast();
  StreamController<List<ExamResult>> _resultsUpdateController =
      StreamController<List<ExamResult>>.broadcast();

  static const Duration _cacheDuration = Duration(hours: 24);
  static const Duration _cacheCleanupInterval = Duration(minutes: 30);

  ExamProvider({required this.apiService, required this.deviceService}) {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
    });
  }

  List<Exam> get availableExams => List.unmodifiable(_availableExams);
  List<ExamResult> get myExamResults => List.unmodifiable(_myExamResults);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<Exam>> get examsUpdates => _examsUpdateController.stream;
  Stream<List<ExamResult>> get resultsUpdates =>
      _resultsUpdateController.stream;

  List<Exam> getExamsByCourse(int courseId) {
    return List.unmodifiable(_examsByCourse[courseId] ?? []);
  }

  bool isLoadingCourse(int courseId) => _isLoadingCourse[courseId] ?? false;

  bool canUserTakeExam(Exam exam) {
    if (exam.maxAttemptsReached) return false;
    if (exam.isBlockedByPendingPayment) return false;
    if (exam.requiresPayment && !exam.hasAccess) return false;
    return exam.canTakeExam;
  }

  String getExamStatusMessage(Exam exam) {
    if (exam.maxAttemptsReached) return 'Maximum attempts reached';
    if (exam.isBlockedByPendingPayment) return 'Payment pending verification';
    if (exam.requiresPayment && !exam.hasAccess) return 'Purchase required';
    if (exam.isUpcoming) return 'Starts ${_formatDate(exam.startDate)}';
    if (exam.isEnded) return 'Exam ended';
    if (exam.isInProgress) return 'In progress';
    return exam.message;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> updatePendingPayments(Map<int, bool> pendingStatus) async {
    debugLog(
        'ExamProvider', '🔄 Updating pending payments status: $pendingStatus');

    _pendingPaymentsByCategory.addAll(pendingStatus);

    bool hasChanges = false;

    for (int i = 0; i < _availableExams.length; i++) {
      final exam = _availableExams[i];
      final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

      if (exam.hasPendingPayment != hasPending) {
        _availableExams[i] = Exam(
          id: exam.id,
          title: exam.title,
          examType: exam.examType,
          startDate: exam.startDate,
          endDate: exam.endDate,
          duration: exam.duration,
          userTimeLimit: exam.userTimeLimit,
          passingScore: exam.passingScore,
          maxAttempts: exam.maxAttempts,
          autoSubmit: exam.autoSubmit,
          showResultsImmediately: exam.showResultsImmediately,
          courseName: exam.courseName,
          courseId: exam.courseId,
          categoryId: exam.categoryId,
          categoryName: exam.categoryName,
          categoryStatus: exam.categoryStatus,
          attemptsTaken: exam.attemptsTaken,
          lastAttemptStatus: exam.lastAttemptStatus,
          questionCount: exam.questionCount,
          status: exam.status,
          message: exam.message,
          canTakeExam: exam.canTakeExam,
          requiresPayment: exam.requiresPayment,
          hasAccess: exam.hasAccess,
          actualDuration: exam.actualDuration,
          timingType: exam.timingType,
          hasPendingPayment: hasPending,
        );
        hasChanges = true;
      }
    }

    for (final courseId in _examsByCourse.keys) {
      final courseExams = _examsByCourse[courseId]!;
      for (int i = 0; i < courseExams.length; i++) {
        final exam = courseExams[i];
        final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

        if (exam.hasPendingPayment != hasPending) {
          courseExams[i] = Exam(
            id: exam.id,
            title: exam.title,
            examType: exam.examType,
            startDate: exam.startDate,
            endDate: exam.endDate,
            duration: exam.duration,
            userTimeLimit: exam.userTimeLimit,
            passingScore: exam.passingScore,
            maxAttempts: exam.maxAttempts,
            autoSubmit: exam.autoSubmit,
            showResultsImmediately: exam.showResultsImmediately,
            courseName: exam.courseName,
            courseId: exam.courseId,
            categoryId: exam.categoryId,
            categoryName: exam.categoryName,
            categoryStatus: exam.categoryStatus,
            attemptsTaken: exam.attemptsTaken,
            lastAttemptStatus: exam.lastAttemptStatus,
            questionCount: exam.questionCount,
            status: exam.status,
            message: exam.message,
            canTakeExam: exam.canTakeExam,
            requiresPayment: exam.requiresPayment,
            hasAccess: exam.hasAccess,
            actualDuration: exam.actualDuration,
            timingType: exam.timingType,
            hasPendingPayment: hasPending,
          );
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _examsUpdateController.add(_availableExams);
      _notifySafely();
      debugLog('ExamProvider', '✅ Updated exams with pending payment status');
    }
  }

  Future<void> loadAvailableExams(
      {int? courseId, bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog(
          'ExamProvider', '📥 Loading available exams for course: $courseId');

      if (!forceRefresh) {
        if (courseId == null) {
          final cachedExams = await deviceService
              .getCacheItem<List<Exam>>(AppConstants.availableExamsCacheKey);
          if (cachedExams != null) {
            _availableExams = cachedExams;
            _applyPendingPaymentStatus();
            _isLoading = false;
            _examsUpdateController.add(_availableExams);
            debugLog('ExamProvider',
                '✅ Loaded ${_availableExams.length} exams from cache');

            unawaited(_refreshAvailableExamsInBackground());
            return;
          }
        } else {
          final cachedExams = await deviceService.getCacheItem<List<Exam>>(
              AppConstants.examsByCourseKey(courseId));
          if (cachedExams != null) {
            _examsByCourse[courseId] = cachedExams;
            _updateGlobalExams(cachedExams);
            _lastLoadedTime[courseId] = DateTime.now();
            _applyPendingPaymentStatus();
            _isLoading = false;
            _examsUpdateController.add(_availableExams);
            debugLog('ExamProvider',
                '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');

            unawaited(_refreshCourseExamsInBackground(courseId));
            return;
          }
        }
      }

      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success && response.data != null) {
        final exams = response.data!;

        if (courseId == null) {
          _availableExams = exams;
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem(
              AppConstants.availableExamsCacheKey, exams,
              ttl: _cacheDuration);
        } else {
          _examsByCourse[courseId] = exams;
          _updateGlobalExams(exams);
          _lastLoadedTime[courseId] = DateTime.now();
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem(
              AppConstants.examsByCourseKey(courseId), exams,
              ttl: _cacheDuration);
        }

        debugLog('ExamProvider', '✅ Loaded ${exams.length} exams from API');
        _examsUpdateController.add(exams);
      } else {
        debugLog(
            'ExamProvider', '❌ No exams data received: ${response.message}');

        if (courseId == null) {
          _availableExams = [];
        } else {
          _examsByCourse[courseId] = [];
        }
        _error = response.message;
      }
    } catch (e) {
      _error = 'Failed to load exams: ${e.toString()}';
      debugLog('ExamProvider', '❌ loadAvailableExams error: $e');

      if (courseId == null && _availableExams.isEmpty) {
        _availableExams = [];
      } else if (courseId != null && !_examsByCourse.containsKey(courseId)) {
        _examsByCourse[courseId] = [];
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshAvailableExamsInBackground() async {
    try {
      debugLog('ExamProvider', '🔄 Background refresh for available exams');

      final response = await apiService.getAvailableExams();

      if (response.success && response.data != null) {
        final exams = response.data!;

        _availableExams = exams;
        _applyPendingPaymentStatus();
        await deviceService.saveCacheItem(
            AppConstants.availableExamsCacheKey, exams,
            ttl: _cacheDuration);

        _examsUpdateController.add(_availableExams);
        _notifySafely();

        debugLog('ExamProvider', '✅ Background refresh completed');
      }
    } catch (e) {
      debugLog('ExamProvider', '⚠️ Background refresh failed: $e');
    }
  }

  Future<void> _refreshCourseExamsInBackground(int courseId) async {
    try {
      debugLog(
          'ExamProvider', '🔄 Background refresh for course $courseId exams');

      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success && response.data != null) {
        final exams = response.data!;

        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();

        await deviceService.saveCacheItem(
            AppConstants.examsByCourseKey(courseId), exams,
            ttl: _cacheDuration);

        _examsUpdateController.add(_availableExams);
        _notifySafely();

        debugLog('ExamProvider',
            '✅ Background refresh completed for course $courseId');
      }
    } catch (e) {
      debugLog('ExamProvider',
          '⚠️ Background refresh failed for course $courseId: $e');
    }
  }

  void _applyPendingPaymentStatus() {
    for (int i = 0; i < _availableExams.length; i++) {
      final exam = _availableExams[i];
      final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

      if (hasPending) {
        _availableExams[i] = Exam(
          id: exam.id,
          title: exam.title,
          examType: exam.examType,
          startDate: exam.startDate,
          endDate: exam.endDate,
          duration: exam.duration,
          userTimeLimit: exam.userTimeLimit,
          passingScore: exam.passingScore,
          maxAttempts: exam.maxAttempts,
          autoSubmit: exam.autoSubmit,
          showResultsImmediately: exam.showResultsImmediately,
          courseName: exam.courseName,
          courseId: exam.courseId,
          categoryId: exam.categoryId,
          categoryName: exam.categoryName,
          categoryStatus: exam.categoryStatus,
          attemptsTaken: exam.attemptsTaken,
          lastAttemptStatus: exam.lastAttemptStatus,
          questionCount: exam.questionCount,
          status: exam.status,
          message: exam.message,
          canTakeExam: exam.canTakeExam,
          requiresPayment: exam.requiresPayment,
          hasAccess: exam.hasAccess,
          actualDuration: exam.actualDuration,
          timingType: exam.timingType,
          hasPendingPayment: true,
        );
      }
    }

    for (final courseId in _examsByCourse.keys) {
      final courseExams = _examsByCourse[courseId]!;
      for (int i = 0; i < courseExams.length; i++) {
        final exam = courseExams[i];
        final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

        if (hasPending) {
          courseExams[i] = Exam(
            id: exam.id,
            title: exam.title,
            examType: exam.examType,
            startDate: exam.startDate,
            endDate: exam.endDate,
            duration: exam.duration,
            userTimeLimit: exam.userTimeLimit,
            passingScore: exam.passingScore,
            maxAttempts: exam.maxAttempts,
            autoSubmit: exam.autoSubmit,
            showResultsImmediately: exam.showResultsImmediately,
            courseName: exam.courseName,
            courseId: exam.courseId,
            categoryId: exam.categoryId,
            categoryName: exam.categoryName,
            categoryStatus: exam.categoryStatus,
            attemptsTaken: exam.attemptsTaken,
            lastAttemptStatus: exam.lastAttemptStatus,
            questionCount: exam.questionCount,
            status: exam.status,
            message: exam.message,
            canTakeExam: exam.canTakeExam,
            requiresPayment: exam.requiresPayment,
            hasAccess: exam.hasAccess,
            actualDuration: exam.actualDuration,
            timingType: exam.timingType,
            hasPendingPayment: true,
          );
        }
      }
    }
  }

  void _updateGlobalExams(List<Exam> exams) {
    for (final exam in exams) {
      final index = _availableExams.indexWhere((e) => e.id == exam.id);
      if (index == -1) {
        _availableExams.add(exam);
      } else {
        _availableExams[index] = exam;
      }
    }
  }

  Future<void> loadMyExamResults({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) {
      debugLog('ExamProvider', 'Already loading, skipping');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', '📥 Loading my exam results');

      if (!forceRefresh) {
        final cachedResults = await deviceService
            .getCacheItem<List<ExamResult>>(AppConstants.myExamResultsCacheKey);
        if (cachedResults != null && cachedResults.isNotEmpty) {
          _myExamResults = cachedResults;
          _isLoading = false;
          _resultsUpdateController.add(_myExamResults);
          _notifySafely();
          debugLog('ExamProvider',
              '✅ Loaded ${_myExamResults.length} exam results from cache');

          unawaited(_refreshExamResultsInBackground());
          return;
        }
      }

      final response = await apiService.getMyExamResults();

      if (response.success) {
        if (response.data is List) {
          _myExamResults = response.data as List<ExamResult>;
          debugLog('ExamProvider',
              '✅ Parsed ${_myExamResults.length} exam results from List');
        } else if (response.data is Map &&
            (response.data as Map).containsKey('data')) {
          final dataList = (response.data as Map)['data'];
          if (dataList is List) {
            _myExamResults =
                dataList.map((item) => ExamResult.fromJson(item)).toList();
            debugLog('ExamProvider',
                '✅ Parsed ${_myExamResults.length} exam results from data field');
          }
        } else {
          _myExamResults = [];
        }

        await deviceService.saveCacheItem(
            AppConstants.myExamResultsCacheKey, _myExamResults,
            ttl: _cacheDuration);

        _resultsUpdateController.add(_myExamResults);
        _notifySafely();

        debugLog('ExamProvider',
            '✅ Final exam results count: ${_myExamResults.length}');
      } else {
        _error = response.message;
        _myExamResults = [];
      }
    } catch (e) {
      _error = 'Failed to load exam results: ${e.toString()}';
      debugLog('ExamProvider', '❌ loadMyExamResults error: $e');

      if (_myExamResults.isEmpty) {
        _myExamResults = [];
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshExamResultsInBackground() async {
    try {
      debugLog('ExamProvider', '🔄 Background refresh for exam results');

      final response = await apiService.getMyExamResults();

      if (response.success) {
        if (response.data is List) {
          _myExamResults = response.data as List<ExamResult>;
        } else if (response.data is Map &&
            (response.data as Map).containsKey('data')) {
          final dataList = (response.data as Map)['data'];
          if (dataList is List) {
            _myExamResults =
                dataList.map((item) => ExamResult.fromJson(item)).toList();
          }
        }

        await deviceService.saveCacheItem(
            AppConstants.myExamResultsCacheKey, _myExamResults,
            ttl: _cacheDuration);

        _resultsUpdateController.add(_myExamResults);
        _notifySafely();

        debugLog('ExamProvider', '✅ Background refresh completed');
      }
    } catch (e) {
      debugLog('ExamProvider', '⚠️ Background refresh failed: $e');
    }
  }

  Future<void> loadExamsByCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoadingCourse[courseId] == true && !forceRefresh) return;

    if (!forceRefresh) {
      final cachedExams = await deviceService
          .getCacheItem<List<Exam>>(AppConstants.examsByCourseKey(courseId));
      if (cachedExams != null) {
        _examsByCourse[courseId] = cachedExams;
        _updateGlobalExams(cachedExams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();
        _examsUpdateController.add(_availableExams);
        _notifySafely();
        debugLog('ExamProvider',
            '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');

        unawaited(_refreshCourseExamsInBackground(courseId));
        return;
      }
    }

    _isLoadingCourse[courseId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', '📥 Loading exams for course: $courseId');
      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success) {
        final exams = response.data ?? [];
        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();

        await deviceService.saveCacheItem(
            AppConstants.examsByCourseKey(courseId), exams,
            ttl: _cacheDuration);

        _examsUpdateController.add(_availableExams);
        debugLog('ExamProvider',
            '✅ Loaded ${exams.length} exams for course $courseId from API');
      } else {
        _error = response.message;
        _examsByCourse[courseId] = [];
      }
    } catch (e) {
      _error = 'Failed to load exams for course: ${e.toString()}';
      debugLog('ExamProvider', '❌ loadExamsByCourse error: $e');

      if (!_examsByCourse.containsKey(courseId)) {
        _examsByCourse[courseId] = [];
      }
    } finally {
      _isLoadingCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Exam? getExamById(int id) {
    try {
      return _availableExams.firstWhere((exam) => exam.id == id);
    } catch (e) {
      return null;
    }
  }

  ExamResult? getExamResultById(int id) {
    try {
      return _myExamResults.firstWhere((result) => result.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupExpiredCache() async {
    debugLog('ExamProvider', '🔄 Cleaning up expired exam cache');
    final now = DateTime.now();

    final expiredCourses = <int>[];
    for (final entry in _lastLoadedTime.entries) {
      if (now.difference(entry.value) > _cacheDuration) {
        expiredCourses.add(entry.key);
      }
    }

    for (final courseId in expiredCourses) {
      await deviceService
          .removeCacheItem(AppConstants.examsByCourseKey(courseId));
      _examsByCourse.remove(courseId);
      _lastLoadedTime.remove(courseId);
      _isLoadingCourse.remove(courseId);
    }

    if (expiredCourses.isNotEmpty) {
      _examsUpdateController.add(_availableExams);
      debugLog('ExamProvider',
          ' Cleared cache for ${expiredCourses.length} expired courses');
    }
  }

  Future<void> clearUserData() async {
    debugLog('ExamProvider', 'Clearing exam data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('ExamProvider', '✅ Same user - preserving exam cache');
      return;
    }

    await deviceService.removeCacheItem(AppConstants.availableExamsCacheKey);
    await deviceService.removeCacheItem(AppConstants.myExamResultsCacheKey);

    final courseIds = _examsByCourse.keys.toList();
    for (final courseId in courseIds) {
      await deviceService
          .removeCacheItem(AppConstants.examsByCourseKey(courseId));
    }

    _availableExams = [];
    _examsByCourse = {};
    _myExamResults = [];
    _lastLoadedTime = {};
    _isLoadingCourse = {};
    _pendingPaymentsByCategory.clear();

    await _examsUpdateController.close();
    await _resultsUpdateController.close();

    _examsUpdateController = StreamController<List<Exam>>.broadcast();
    _resultsUpdateController = StreamController<List<ExamResult>>.broadcast();

    _examsUpdateController.add(_availableExams);
    _resultsUpdateController.add(_myExamResults);

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  Future<void> clearExamsForCourse(int courseId) async {
    await deviceService
        .removeCacheItem(AppConstants.examsByCourseKey(courseId));

    final courseExams = _examsByCourse[courseId] ?? [];
    _availableExams
        .removeWhere((exam) => courseExams.any((e) => e.id == exam.id));

    _examsByCourse.remove(courseId);
    _lastLoadedTime.remove(courseId);
    _isLoadingCourse.remove(courseId);

    _examsUpdateController.add(_availableExams);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _examsUpdateController.close();
    _resultsUpdateController.close();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}
