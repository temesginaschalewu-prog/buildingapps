// lib/providers/exam_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED CONNECTIVITY & ERROR HANDLING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Exam Provider with Full Offline Support
class ExamProvider extends ChangeNotifier
    with
        BaseProvider<ExamProvider>,
        OfflineAwareProvider<ExamProvider>,
        BackgroundRefreshMixin<ExamProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  List<Exam> _availableExams = [];
  List<ExamResult> _myExamResults = [];
  Map<int, List<Exam>> _examsByCourse = {};
  final Map<int, bool> _isLoadingForCourse = {};
  final Map<int, bool> _hasLoadedForCourse = {};

  bool _hasLoadedExams = false;
  bool _hasLoadedResults = false;

  static const Duration _cacheDuration = AppConstants.cacheTTLExams;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _examsBox;
  Box? _resultsBox;
  String? _activeUserId;

  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream declarations with late
  late StreamController<List<Exam>> _examsUpdateController;
  late StreamController<List<ExamResult>> _resultsUpdateController;

  ExamProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  })  : _examsUpdateController = StreamController<List<Exam>>.broadcast(),
        _resultsUpdateController =
            StreamController<List<ExamResult>>.broadcast() {
    log('ExamProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSubmitExam,
      _processExamSubmission,
    );
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSaveExamProgress,
      _processExamProgressSave,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processExamSubmission(Map<String, dynamic> data) async {
    try {
      log('Processing offline exam submission');
      final examResultId = data['exam_result_id'];
      final answers = data['answers'];
      final response = await apiService.submitExam(examResultId, answers);
      return response.success;
    } catch (e) {
      log('Error processing exam submission: $e');
      return false;
    }
  }

  Future<bool> _processExamProgressSave(Map<String, dynamic> data) async {
    try {
      log('Processing offline exam progress save');
      final examResultId = data['exam_result_id'];
      final answers = data['answers'];
      final response = await apiService.saveExamProgress(examResultId, answers);
      return response.success;
    } catch (e) {
      log('Error processing exam progress save: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _ensureCurrentUserScope();
    await _loadCachedData();

    if (_hasLoadedExams || _hasLoadedResults) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveExamsBox)) {
        _examsBox = await Hive.openBox<dynamic>(AppConstants.hiveExamsBox);
      } else {
        _examsBox = Hive.box<dynamic>(AppConstants.hiveExamsBox);
      }

      if (!Hive.isBoxOpen(AppConstants.hiveExamResultsBox)) {
        _resultsBox =
            await Hive.openBox<dynamic>(AppConstants.hiveExamResultsBox);
      } else {
        _resultsBox = Hive.box<dynamic>(AppConstants.hiveExamResultsBox);
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<String?> _ensureCurrentUserScope() async {
    final userId = await UserSession().getCurrentUserId();
    if (_activeUserId == userId) return userId;

    log('🔄 ExamProvider user scope changed: $_activeUserId -> $userId');
    _activeUserId = userId;
    _resetInMemoryState();
    return userId;
  }

  void _resetInMemoryState() {
    stopBackgroundRefresh();
    _availableExams = [];
    _myExamResults = [];
    _examsByCourse = {};
    _isLoadingForCourse.clear();
    _hasLoadedForCourse.clear();
    _hasLoadedExams = false;
    _hasLoadedResults = false;
    _lastBackgroundRefreshForCourse.clear();
    _lastResultsBackgroundRefresh = null;

    if (!_examsUpdateController.isClosed) {
      _examsUpdateController.add(_availableExams);
    }
    if (!_resultsUpdateController.isClosed) {
      _resultsUpdateController.add(_myExamResults);
    }

    safeNotify();
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = await _ensureCurrentUserScope();
      if (userId == null) return;

      if (_examsBox != null) {
        final cachedExams = _examsBox!.get('user_${userId}_exams');
        if (cachedExams != null && cachedExams is List) {
          final List<Exam> exams = [];
          for (final item in cachedExams) {
            if (item is Exam) {
              exams.add(item);
            } else if (item is Map<String, dynamic>) {
              exams.add(Exam.fromJson(item));
            }
          }
          if (exams.isNotEmpty) {
            _availableExams = exams;
            _rebuildExamsByCourse();
            _hasLoadedExams = true;
            _examsUpdateController.add(_availableExams);
            log('✅ Loaded ${_availableExams.length} exams from Hive');
          }
        }
      }

      if (_resultsBox != null) {
        final cachedResults = _resultsBox!.get('user_${userId}_results');
        if (cachedResults != null && cachedResults is List) {
          final List<ExamResult> results = [];
          for (final item in cachedResults) {
            if (item is ExamResult) {
              results.add(item);
            } else if (item is Map<String, dynamic>) {
              results.add(ExamResult.fromJson(item));
            }
          }
          if (results.isNotEmpty) {
            _myExamResults = results;
            _hasLoadedResults = true;
            _resultsUpdateController.add(_myExamResults);
            log('✅ Loaded ${_myExamResults.length} results from Hive');
          }
        }
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _saveExamsToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _examsBox != null) {
        await _examsBox!.put('user_${userId}_exams', _availableExams);
        log('💾 Saved ${_availableExams.length} exams to Hive');
      }
    } catch (e) {
      log('Error saving exams to Hive: $e');
    }
  }

  Future<void> _saveResultsToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _resultsBox != null) {
        await _resultsBox!.put('user_${userId}_results', _myExamResults);
        log('💾 Saved ${_myExamResults.length} results to Hive');
      }
    } catch (e) {
      log('Error saving results to Hive: $e');
    }
  }

  void _rebuildExamsByCourse() {
    _examsByCourse.clear();
    for (final exam in _availableExams) {
      if (!_examsByCourse.containsKey(exam.courseId)) {
        _examsByCourse[exam.courseId] = [];
      }
      _examsByCourse[exam.courseId]!.add(exam);
    }
  }

  // ===== GETTERS =====
  List<Exam> get availableExams => List.unmodifiable(_availableExams);
  List<ExamResult> get myExamResults => List.unmodifiable(_myExamResults);

  bool get hasLoadedExams => _hasLoadedExams;
  bool get hasLoadedResults => _hasLoadedResults;

  Stream<List<Exam>> get examsUpdates => _examsUpdateController.stream;
  Stream<List<ExamResult>> get resultsUpdates =>
      _resultsUpdateController.stream;

  List<Exam> getExamsByCourse(int courseId) {
    return _examsByCourse[courseId] ?? [];
  }

  bool isLoadingForCourse(int courseId) =>
      _isLoadingForCourse[courseId] ?? false;
  bool hasLoadedForCourse(int courseId) =>
      _hasLoadedForCourse[courseId] ?? false;

  Exam? getExamById(int id) {
    try {
      return _availableExams.firstWhere((exam) => exam.id == id);
    } catch (e) {
      return null;
    }
  }

  // ===== LOAD EXAMS BY COURSE =====
  Future<void> loadExamsByCourse(
    int courseId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    await _ensureCurrentUserScope();
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadExamsByCourse() CALL #$callId for course $courseId');

    // ✅ FIXED: Early connectivity check with user-friendly message
    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // Return cached data immediately if available
    if (_hasLoadedForCourse[courseId] == true && !forceRefresh) {
      log('✅ Already have data for course $courseId, returning cached');
      _examsUpdateController.add(_availableExams);
      setLoaded();
      return;
    }

    if (_isLoadingForCourse[courseId] == true && !forceRefresh) {
      log('⏳ Already loading course $courseId, waiting...');
      int attempts = 0;
      while (_isLoadingForCourse[courseId] == true && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoadedForCourse[courseId] == true) {
        log('✅ Got exams from existing load');
        _examsUpdateController.add(_availableExams);
        setLoaded();
        return;
      }
    }

    _isLoadingForCourse[courseId] = true;
    setLoading();
    safeNotify();

    try {
      // STEP 1: Check memory cache first
      if (!forceRefresh && _examsByCourse.containsKey(courseId)) {
        log('STEP 1: Using memory cache for course $courseId');
        setLoaded();
        _examsUpdateController.add(_availableExams);
        return;
      }

      // STEP 2: Try Hive cache
      if (!forceRefresh) {
        log('STEP 2: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _examsBox != null) {
          final cachedExams = _examsBox!.get('user_${userId}_exams');
          if (cachedExams != null && cachedExams is List) {
            final List<Exam> exams = [];
            for (final item in cachedExams) {
              if (item is Exam) {
                exams.add(item);
              } else if (item is Map<String, dynamic>) {
                exams.add(Exam.fromJson(item));
              }
            }
            if (exams.isNotEmpty) {
              _availableExams = exams;
              _rebuildExamsByCourse();
              _hasLoadedExams = true;
              _hasLoadedForCourse[courseId] = true;
              setLoaded();
              _isLoadingForCourse[courseId] = false;
              _examsUpdateController.add(_availableExams);
              log('✅ Loaded ${exams.length} exams from Hive cache');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshCourseExamsInBackground(courseId));
              }
              return;
            }
          }
        }
      }

      // STEP 3: Try DeviceService
      if (!forceRefresh) {
        log('STEP 3: Checking DeviceService cache');
        final cachedExams = await deviceService.getCacheItem<List<dynamic>>(
          'exams_course_$courseId',
          isUserSpecific: true,
        );

        if (cachedExams != null && cachedExams.isNotEmpty) {
          final List<Exam> exams = [];
          for (final json in cachedExams) {
            if (json is Map<String, dynamic>) {
              exams.add(Exam.fromJson(json));
            }
          }

          if (exams.isNotEmpty) {
            _examsByCourse[courseId] = exams;
            _updateGlobalExams(exams);
            _hasLoadedForCourse[courseId] = true;
            _hasLoadedExams = true;
            setLoaded();
            _isLoadingForCourse[courseId] = false;

            await _saveExamsToHive();

            _examsUpdateController.add(_availableExams);
            log('✅ Loaded ${exams.length} exams from DeviceService for course $courseId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshCourseExamsInBackground(courseId));
            }
            return;
          }
        }
      }

      // STEP 4: Check offline status
      if (isOffline) {
        log('STEP 4: Offline mode');
        if (_examsByCourse.containsKey(courseId)) {
          _hasLoadedForCourse[courseId] = true;
          setLoaded();
          _isLoadingForCourse[courseId] = false;
          _examsUpdateController.add(_availableExams);
          log('✅ Showing cached exams offline for course $courseId');
          return;
        }

        setError(getUserFriendlyErrorMessage(
            'You are offline. No cached exams available.'));
        _hasLoadedForCourse[courseId] = true;
        setLoaded();
        _isLoadingForCourse[courseId] = false;

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 5: Fetch from API with timeout
      log('STEP 5: Fetching from API for course $courseId');
      final response =
          await apiService.getAvailableExams(courseId: courseId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout for course $courseId');
          if (_examsByCourse.containsKey(courseId)) {
            log('✅ Using cached exams due to timeout');
            _hasLoadedForCourse[courseId] = true;
            _isLoadingForCourse[courseId] = false;
            setLoaded();
            _examsUpdateController.add(_availableExams);
            return ApiResponse<List<Exam>>(
              success: true,
              message: 'Using cached data',
              data: _examsByCourse[courseId],
            );
          }
          return ApiResponse<List<Exam>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      if (response.success) {
        final exams = response.data ?? [];
        log('✅ Received ${exams.length} exams from API');

        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);
        _hasLoadedForCourse[courseId] = true;
        _hasLoadedExams = true;
        setLoaded();
        _isLoadingForCourse[courseId] = false;

        await _saveExamsToHive();

        deviceService.saveCacheItem(
          'exams_course_$courseId',
          exams.map((e) => e.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _examsUpdateController.add(_availableExams);
        log('✅ Success! Exams loaded for course $courseId');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        _examsByCourse[courseId] = _examsByCourse[courseId] ?? [];
        _hasLoadedForCourse[courseId] = true;
        setLoaded();
        _isLoadingForCourse[courseId] = false;
        _examsUpdateController.add(_availableExams);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading exams: $e');

      setError(getUserFriendlyErrorMessage(e));
      _examsByCourse[courseId] = _examsByCourse[courseId] ?? [];
      _hasLoadedForCourse[courseId] = true;
      setLoaded();
      _isLoadingForCourse[courseId] = false;

      if (_availableExams.isEmpty) {
        await _recoverExamsFromCache();
      }

      _examsUpdateController.add(_availableExams);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ===== LOAD EXAM RESULTS =====
  Future<void> loadMyExamResults({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    await _ensureCurrentUserScope();
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadMyExamResults() CALL #$callId');

    // ✅ FIXED: Early connectivity check with user-friendly message
    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // Return cached data immediately if available
    if (_hasLoadedResults && !forceRefresh && _myExamResults.isNotEmpty) {
      log('✅ Already have results, returning cached');
      setLoaded();
      _resultsUpdateController.add(_myExamResults);
      return;
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, waiting...');
      int attempts = 0;
      while (isLoading && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoadedResults) {
        log('✅ Got results from existing load');
        setLoaded();
        _resultsUpdateController.add(_myExamResults);
        return;
      }
    }

    setLoading();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _resultsBox != null) {
          final cachedResults = _resultsBox!.get('user_${userId}_results');
          if (cachedResults != null && cachedResults is List) {
            final List<ExamResult> results = [];
            for (final item in cachedResults) {
              if (item is ExamResult) {
                results.add(item);
              } else if (item is Map<String, dynamic>) {
                results.add(ExamResult.fromJson(item));
              }
            }
            if (results.isNotEmpty) {
              _myExamResults = results;
              _hasLoadedResults = true;
              setLoaded();
              _resultsUpdateController.add(_myExamResults);
              log('✅ Loaded ${results.length} results from Hive cache');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshExamResultsInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cachedResults = await deviceService.getCacheItem<List<dynamic>>(
          'my_exam_results',
          isUserSpecific: true,
        );

        if (cachedResults != null && cachedResults.isNotEmpty) {
          final List<ExamResult> results = [];
          for (final json in cachedResults) {
            if (json is Map<String, dynamic>) {
              results.add(ExamResult.fromJson(json));
            }
          }

          if (results.isNotEmpty) {
            _myExamResults = results;
            _hasLoadedResults = true;
            setLoaded();
            _resultsUpdateController.add(_myExamResults);

            await _saveResultsToHive();
            log('✅ Loaded ${results.length} results from DeviceService cache');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshExamResultsInBackground());
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_myExamResults.isNotEmpty) {
          _hasLoadedResults = true;
          setLoaded();
          _resultsUpdateController.add(_myExamResults);
          log('✅ Showing cached exam results offline');
          return;
        }

        _myExamResults = [];
        _hasLoadedResults = true;
        setLoaded();
        _resultsUpdateController.add(_myExamResults);

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 4: Fetch from API with timeout
      log('STEP 4: Fetching from API');

      final userId = await UserSession().getCurrentUserId();
      if (userId == null) {
        setLoaded();
        return;
      }

      final response =
          await apiService.getUserExamResults(int.parse(userId)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout for exam results');
          if (_myExamResults.isNotEmpty) {
            log('✅ Using cached results due to timeout');
            _hasLoadedResults = true;
            setLoaded();
            _resultsUpdateController.add(_myExamResults);
            return ApiResponse<List<ExamResult>>(
              success: true,
              message: 'Using cached data',
              data: _myExamResults,
            );
          }
          return ApiResponse<List<ExamResult>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      if (response.success) {
        _myExamResults = response.data ?? [];
        log('✅ Received ${_myExamResults.length} results from API');
        _hasLoadedResults = true;
        setLoaded();

        await _saveResultsToHive();

        deviceService.saveCacheItem(
          'my_exam_results',
          _myExamResults.map((r) => r.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _resultsUpdateController.add(_myExamResults);
        log('✅ Success! Exam results loaded');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        _hasLoadedResults = true;
        setLoaded();
        _resultsUpdateController.add(_myExamResults);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading exam results: $e');

      setError(getUserFriendlyErrorMessage(e));
      setLoaded();
      _hasLoadedResults = true;

      if (_myExamResults.isEmpty) {
        await _recoverResultsFromCache();
      }

      _resultsUpdateController.add(_myExamResults);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ===== EXAM SUBMISSION METHODS =====
  Future<ApiResponse<Map<String, dynamic>>> startExam(int examId) async {
    log('startExam() for exam $examId');
    await _ensureCurrentUserScope();

    // ✅ FIXED: Early connectivity check
    if (isOffline) {
      return ApiResponse.offline(
        message:
            'Cannot start exam while offline. Please connect and try again.',
      );
    }

    setLoading();
    try {
      final response = await apiService.startExam(examId);
      setLoaded();
      return response;
    } catch (e) {
      setLoaded();
      setError(getUserFriendlyErrorMessage(e));
      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitExam(
      int examResultId, List<Map<String, dynamic>> answers) async {
    log('submitExam() for result $examResultId');
    await _ensureCurrentUserScope();

    // ✅ FIXED: Handle offline with queue
    if (isOffline) {
      offlineQueueManager.addItem(
        type: AppConstants.queueActionSubmitExam,
        data: {
          'exam_result_id': examResultId,
          'answers': answers,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return ApiResponse.queued(
        message: 'Exam saved offline. Will submit when online.',
      );
    }

    setLoading();
    try {
      final response = await apiService.submitExam(examResultId, answers);

      if (response.success) {
        unawaited(loadMyExamResults(forceRefresh: true));
      }

      setLoaded();
      return response;
    } catch (e) {
      setLoaded();
      setError(getUserFriendlyErrorMessage(e));
      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> saveExamProgress(
      int examResultId, List<Map<String, dynamic>> answers) async {
    log('saveExamProgress() for result $examResultId');
    await _ensureCurrentUserScope();

    // ✅ FIXED: Handle offline with queue
    if (isOffline) {
      offlineQueueManager.addItem(
        type: AppConstants.queueActionSaveExamProgress,
        data: {
          'exam_result_id': examResultId,
          'answers': answers,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return ApiResponse.queued(
        message: 'Progress saved offline.',
      );
    }

    try {
      final response = await apiService.saveExamProgress(examResultId, answers);
      return response;
    } catch (e) {
      log('Error saving exam progress: $e');
      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
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

  // ✅ FIXED: Background refresh with rate limiting
  final Map<dynamic, dynamic> _lastBackgroundRefreshForCourse = {};
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  Future<void> _refreshCourseExamsInBackground(int courseId) async {
    // Rate limit background refreshes per course
    if (_lastBackgroundRefreshForCourse[courseId] != null &&
        DateTime.now().difference(_lastBackgroundRefreshForCourse[courseId]!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited for course $courseId');
      return;
    }
    _lastBackgroundRefreshForCourse[courseId] = DateTime.now();

    if (isOffline) return;

    try {
      final response =
          await apiService.getAvailableExams(courseId: courseId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Background refresh timeout for course $courseId');
          return ApiResponse<List<Exam>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success && response.data != null) {
        final exams = response.data!;

        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);

        await _saveExamsToHive();

        deviceService.saveCacheItem(
          'exams_course_$courseId',
          exams.map((e) => e.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _examsUpdateController.add(_availableExams);
        log('🔄 Background refresh for course $courseId complete');
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  DateTime? _lastResultsBackgroundRefresh;

  Future<void> _refreshExamResultsInBackground() async {
    // Rate limit background refreshes
    if (_lastResultsBackgroundRefresh != null &&
        DateTime.now().difference(_lastResultsBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Results background refresh rate limited');
      return;
    }
    _lastResultsBackgroundRefresh = DateTime.now();

    if (isOffline) return;

    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      final response =
          await apiService.getUserExamResults(int.parse(userId)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Background refresh timeout for results');
          return ApiResponse<List<ExamResult>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success) {
        _myExamResults = response.data ?? [];

        await _saveResultsToHive();

        deviceService.saveCacheItem(
          'my_exam_results',
          _myExamResults.map((r) => r.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _resultsUpdateController.add(_myExamResults);
        log('🔄 Background refresh for results complete');
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  Future<void> _recoverExamsFromCache() async {
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    if (_examsBox != null) {
      try {
        final cachedExams = _examsBox!.get('user_${userId}_exams');
        if (cachedExams != null && cachedExams is List) {
          final List<Exam> exams = [];
          for (final item in cachedExams) {
            if (item is Exam) {
              exams.add(item);
            } else if (item is Map<String, dynamic>) {
              exams.add(Exam.fromJson(item));
            }
          }
          if (exams.isNotEmpty) {
            _availableExams = exams;
            _rebuildExamsByCourse();
            _hasLoadedExams = true;
            _examsUpdateController.add(_availableExams);
            log('✅ Recovered ${exams.length} exams from Hive after error');
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }
  }

  Future<void> _recoverResultsFromCache() async {
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    if (_resultsBox != null) {
      try {
        final cachedResults = _resultsBox!.get('user_${userId}_results');
        if (cachedResults != null && cachedResults is List) {
          final List<ExamResult> results = [];
          for (final item in cachedResults) {
            if (item is ExamResult) {
              results.add(item);
            } else if (item is Map<String, dynamic>) {
              results.add(ExamResult.fromJson(item));
            }
          }
          if (results.isNotEmpty) {
            _myExamResults = results;
            _hasLoadedResults = true;
            _resultsUpdateController.add(_myExamResults);
            log('✅ Recovered ${results.length} results from Hive after error');
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (isOffline) return;

    if (_hasLoadedExams) {
      unawaited(_refreshCourseExamsInBackground(0));
    }
    if (_hasLoadedResults) {
      unawaited(_refreshExamResultsInBackground());
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing exams');
    if (_hasLoadedExams) {
      await loadExamsByCourse(0, forceRefresh: true);
    }
    if (_hasLoadedResults) {
      await loadMyExamResults(forceRefresh: true);
    }
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;
    _activeUserId = null;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_examsBox != null) {
        await _examsBox!.delete('user_${userId}_exams');
      }
      if (_resultsBox != null) {
        await _resultsBox!.delete('user_${userId}_results');
      }
    }

    await deviceService.clearCacheByPrefix('exams_');
    await deviceService.clearCacheByPrefix('my_exam_results');

    _availableExams = [];
    _examsByCourse = {};
    _isLoadingForCourse.clear();
    _hasLoadedForCourse.clear();
    _myExamResults = [];
    _hasLoadedExams = false;
    _hasLoadedResults = false;
    _lastBackgroundRefreshForCourse.clear();
    _lastResultsBackgroundRefresh = null;
    stopBackgroundRefresh();

    // ✅ FIXED: Properly recreate stream controllers
    await _examsUpdateController.close();
    await _resultsUpdateController.close();
    _examsUpdateController = StreamController<List<Exam>>.broadcast();
    _resultsUpdateController = StreamController<List<ExamResult>>.broadcast();
    _examsUpdateController.add([]);
    _resultsUpdateController.add([]);

    safeNotify();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _examsUpdateController.close();
    _resultsUpdateController.close();
    _examsBox?.close();
    _resultsBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
