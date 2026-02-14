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

  Future<void> loadAvailableExams(
      {int? courseId, required bool forceRefresh}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading available exams for course: $courseId');

      if (courseId == null) {
        final cachedExams =
            await deviceService.getCacheItem<List<Exam>>('available_exams');
        if (cachedExams != null) {
          _availableExams = cachedExams;
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${_availableExams.length} exams from cache');
          return;
        }
      } else {
        final cachedExams = await deviceService
            .getCacheItem<List<Exam>>('exams_course_$courseId');
        if (cachedExams != null) {
          _examsByCourse[courseId] = cachedExams;
          _updateGlobalExams(cachedExams);
          _lastLoadedTime[courseId] = DateTime.now();
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');
          return;
        }
      }

      final response = await apiService.getAvailableExams(courseId: courseId);

      debugLog('ExamProvider', 'API Response success: ${response.success}');
      debugLog('ExamProvider', 'API Response message: ${response.message}');
      debugLog('ExamProvider',
          'API Response data length: ${response.data?.length ?? 0}');

      if (response.success && response.data != null) {
        final exams = response.data!;

        if (courseId == null) {
          _availableExams = exams;
          await deviceService.saveCacheItem('available_exams', exams,
              ttl: _cacheDuration);
        } else {
          _examsByCourse[courseId] = exams;
          _updateGlobalExams(exams);
          _lastLoadedTime[courseId] = DateTime.now();
          await deviceService.saveCacheItem('exams_course_$courseId', exams,
              ttl: _cacheDuration);
        }

        debugLog('ExamProvider', 'Loaded ${exams.length} exams');

        for (var i = 0; i < exams.length; i++) {
          final exam = exams[i];
          debugLog('ExamProvider',
              'Exam $i: ${exam.title} - status: ${exam.status}, autoSubmit: ${exam.autoSubmit}, showResults: ${exam.showResultsImmediately}');
        }

        _examsUpdateController.add(exams);
      } else {
        debugLog('ExamProvider', 'No exams data received: ${response.message}');
        _availableExams = [];
        _error = response.message;
      }
    } catch (e, stackTrace) {
      _error = 'Failed to load exams: ${e.toString()}';
      debugLog('ExamProvider', 'loadAvailableExams error: $e');
      debugLog('ExamProvider', 'Stack trace: $stackTrace');
      _availableExams = [];
    } finally {
      _isLoading = false;
      _notifySafely();
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
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      if (!forceRefresh) {
        final cachedResults = await deviceService
            .getCacheItem<List<ExamResult>>('my_exam_results');
        if (cachedResults != null) {
          _myExamResults = cachedResults;
          _isLoading = false;
          _resultsUpdateController.add(_myExamResults);
          debugLog('ExamProvider',
              '✅ Loaded ${_myExamResults.length} exam results from cache');
          return;
        }
      }

      debugLog('ExamProvider', 'Loading my exam results');
      final response = await apiService.getMyExamResults();
      if (response.success) {
        _myExamResults = response.data ?? [];
        await deviceService.saveCacheItem('my_exam_results', _myExamResults,
            ttl: _cacheDuration);

        _resultsUpdateController.add(_myExamResults);
      } else {
        _error = response.message;
        _myExamResults = [];
      }
    } catch (e) {
      _error = 'Failed to load exam results: ${e.toString()}';
      debugLog('ExamProvider', 'loadMyExamResults error: $e');
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

    _examsUpdateController.close();
    _resultsUpdateController.close();

    _examsUpdateController = StreamController<List<Exam>>.broadcast();
    _resultsUpdateController = StreamController<List<ExamResult>>.broadcast();

    _examsUpdateController.add(_availableExams);
    _resultsUpdateController.add(_myExamResults);

    _notifySafely();
  }

  void clearExamsForCourse(int courseId) async {
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
