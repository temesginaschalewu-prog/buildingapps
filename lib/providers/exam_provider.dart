import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../utils/helpers.dart';

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

  // NEW: Track pending payments per category
  final Map<int, bool> _pendingPaymentsByCategory = {};

  StreamController<List<Exam>> _examsUpdateController =
      StreamController<List<Exam>>.broadcast();
  StreamController<List<ExamResult>> _resultsUpdateController =
      StreamController<List<ExamResult>>.broadcast();

  static const Duration _cacheDuration = Duration(hours: 1);
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

  // NEW: Update pending payments status for exams
  Future<void> updatePendingPayments(Map<int, bool> pendingStatus) async {
    debugLog(
        'ExamProvider', '🔄 Updating pending payments status: $pendingStatus');

    _pendingPaymentsByCategory.addAll(pendingStatus);

    // Update all exams with new pending payment status
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

    // Update course-specific exams
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
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading available exams for course: $courseId');

      if (courseId == null) {
        final cachedExams =
            await deviceService.getCacheItem<List<Exam>>('available_exams');
        if (cachedExams != null && !forceRefresh) {
          _availableExams = cachedExams;
          // Apply pending payment status to cached exams
          _applyPendingPaymentStatus();
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${_availableExams.length} exams from cache');
          return;
        }
      } else {
        final cachedExams = await deviceService
            .getCacheItem<List<Exam>>('exams_course_$courseId');
        if (cachedExams != null && !forceRefresh) {
          _examsByCourse[courseId] = cachedExams;
          _updateGlobalExams(cachedExams);
          _lastLoadedTime[courseId] = DateTime.now();
          _applyPendingPaymentStatus();
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');
          return;
        }
      }

      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success && response.data != null) {
        final exams = response.data!;

        if (courseId == null) {
          _availableExams = exams;
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem('available_exams', exams,
              ttl: _cacheDuration);
        } else {
          _examsByCourse[courseId] = exams;
          _updateGlobalExams(exams);
          _lastLoadedTime[courseId] = DateTime.now();
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem('exams_course_$courseId', exams,
              ttl: _cacheDuration);
        }

        debugLog('ExamProvider', 'Loaded ${exams.length} exams');
        _examsUpdateController.add(exams);
      } else {
        debugLog('ExamProvider', 'No exams data received: ${response.message}');
        _availableExams = [];
        _error = response.message;
      }
    } catch (e) {
      _error = 'Failed to load exams: ${e.toString()}';
      debugLog('ExamProvider', 'loadAvailableExams error: $e');
      _availableExams = [];
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  // NEW: Apply pending payment status to all exams
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
      debugLog('ExamProvider', 'Loading my exam results');

      if (!forceRefresh) {
        final cachedResults = await deviceService
            .getCacheItem<List<ExamResult>>('my_exam_results');
        if (cachedResults != null && cachedResults.isNotEmpty) {
          _myExamResults = cachedResults;
          _isLoading = false;
          _resultsUpdateController.add(_myExamResults);
          notifyListeners();
          debugLog('ExamProvider',
              '✅ Loaded ${_myExamResults.length} exam results from cache');
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

        await deviceService.saveCacheItem('my_exam_results', _myExamResults,
            ttl: _cacheDuration);

        _resultsUpdateController.add(_myExamResults);
        notifyListeners();

        debugLog('ExamProvider',
            '✅ Final exam results count: ${_myExamResults.length}');
      } else {
        _error = response.message;
        _myExamResults = [];
      }
    } catch (e) {
      _error = 'Failed to load exam results: ${e.toString()}';
      debugLog('ExamProvider', '❌ loadMyExamResults error: $e');
      _myExamResults = [];
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadExamsByCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoadingCourse[courseId] == true && !forceRefresh) return;

    if (!forceRefresh) {
      final cachedExams = await deviceService
          .getCacheItem<List<Exam>>('exams_course_$courseId');
      if (cachedExams != null) {
        _examsByCourse[courseId] = cachedExams;
        _updateGlobalExams(cachedExams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();
        _examsUpdateController.add(_availableExams);
        debugLog('ExamProvider',
            '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');
        return;
      }
    }

    _isLoadingCourse[courseId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading exams for course: $courseId');
      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success) {
        final exams = response.data ?? [];
        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();

        await deviceService.saveCacheItem('exams_course_$courseId', exams,
            ttl: _cacheDuration);

        _examsUpdateController.add(_availableExams);
      } else {
        _error = response.message;
        _examsByCourse[courseId] = [];
      }
    } catch (e) {
      _error = 'Failed to load exams for course: ${e.toString()}';
      debugLog('ExamProvider', 'loadExamsByCourse error: $e');
      _examsByCourse[courseId] = [];
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
      await deviceService.removeCacheItem('exams_course_$courseId');
      _examsByCourse.remove(courseId);
      _lastLoadedTime.remove(courseId);
      _isLoadingCourse.remove(courseId);
    }

    if (expiredCourses.isNotEmpty) {
      _examsUpdateController.add(_availableExams);
      debugLog('ExamProvider',
          '🧹 Cleared cache for ${expiredCourses.length} expired courses');
    }
  }

  Future<void> clearUserData() async {
    debugLog('ExamProvider', 'Clearing exam data');

    await deviceService.removeCacheItem('available_exams');
    await deviceService.removeCacheItem('my_exam_results');

    final courseIds = _examsByCourse.keys.toList();
    for (final courseId in courseIds) {
      await deviceService.removeCacheItem('exams_course_$courseId');
    }

    _availableExams = [];
    _examsByCourse = {};
    _myExamResults = [];
    _lastLoadedTime = {};
    _isLoadingCourse = {};
    _pendingPaymentsByCategory.clear();

    _examsUpdateController.close();
    _resultsUpdateController.close();

    _examsUpdateController = StreamController<List<Exam>>.broadcast();
    _resultsUpdateController = StreamController<List<ExamResult>>.broadcast();

    _examsUpdateController.add(_availableExams);
    _resultsUpdateController.add(_myExamResults);

    _notifySafely();
  }

  Future<void> clearExamsForCourse(int courseId) async {
    await deviceService.removeCacheItem('exams_course_$courseId');

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
