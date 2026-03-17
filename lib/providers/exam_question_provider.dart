// lib/providers/exam_question_provider.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/exam_question_model.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Exam Question Provider with Full Offline Support
class ExamQuestionProvider extends ChangeNotifier
    with
        BaseProvider<ExamQuestionProvider>,
        OfflineAwareProvider<ExamQuestionProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;
  BuildContext? _context;

  final Map<int, List<ExamQuestion>> _questionsByExam = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, bool> _isLoadingExam = {};
  final Map<int, bool> _examAccessChecked = {};
  final Map<int, bool> _examHasAccess = {};
  final Map<int, Map<int, String>> _savedAnswers = {};

  static const Duration _cacheDuration = AppConstants.cacheTTLQuestions;
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);

  Box? _questionsBox;
  Box? _answersBox;
  Box? _accessBox;

  int _apiCallCount = 0;
  Timer? _cacheCleanupTimer;

  StreamController<Map<int, List<ExamQuestion>>> _questionsUpdateController =
      StreamController<Map<int, List<ExamQuestion>>>.broadcast();
  StreamController<Map<int, bool>> _examAccessController =
      StreamController<Map<int, bool>>.broadcast();

  ExamQuestionProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('ExamQuestionProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    // Register processor for answer saving (though answers are local only)
    // No need for queue processors as answers are saved locally
    log('✅ Registered queue processors');
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
    });
    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen('exam_questions_box')) {
        _questionsBox = await Hive.openBox('exam_questions_box');
      } else {
        _questionsBox = Hive.box('exam_questions_box');
      }

      if (!Hive.isBoxOpen('exam_answers_box')) {
        _answersBox = await Hive.openBox('exam_answers_box');
      } else {
        _answersBox = Hive.box('exam_answers_box');
      }

      if (!Hive.isBoxOpen('exam_access_box')) {
        _accessBox = await Hive.openBox('exam_access_box');
      } else {
        _accessBox = Hive.box('exam_access_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  void setContext(BuildContext context) {
    _context ??= context;
  }

  // ===== GETTERS =====
  Stream<Map<int, List<ExamQuestion>>> get questionsUpdates =>
      _questionsUpdateController.stream;
  Stream<Map<int, bool>> get examAccessUpdates => _examAccessController.stream;

  bool hasExamAccess(int examId) => _examHasAccess[examId] ?? false;
  bool isExamAccessChecked(int examId) => _examAccessChecked[examId] ?? false;
  bool isLoadingExam(int examId) => _isLoadingExam[examId] ?? false;

  List<ExamQuestion> getQuestionsByExam(int examId) {
    return _questionsByExam[examId] ?? [];
  }

  ExamQuestion? getQuestionById(int id) {
    for (final questions in _questionsByExam.values) {
      try {
        return questions.firstWhere((q) => q.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  String? getSavedAnswer(int examId, int questionId) {
    return _savedAnswers[examId]?[questionId];
  }

  // ===== ANSWER SAVING METHODS =====
  Future<void> saveAnswerOffline(
      int examId, int questionId, String answer) async {
    log('saveAnswerOffline() for exam $examId, question $questionId');

    if (!_savedAnswers.containsKey(examId)) {
      _savedAnswers[examId] = {};
    }
    _savedAnswers[examId]![questionId] = answer;

    try {
      if (_answersBox != null) {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          final answersKey = 'user_${userId}_exam_${examId}_answers';
          final Map answersMap = _answersBox!.get(answersKey) ?? {};
          answersMap[questionId.toString()] = answer;
          await _answersBox!.put(answersKey, answersMap);
          log('💾 Saved answer for exam $examId, question $questionId to Hive');
        }
      }
    } catch (e) {
      log('Error saving answer to Hive: $e');
    }
  }

  Future<Map<int, String>> loadSavedAnswersForExam(int examId) async {
    log('loadSavedAnswersForExam() for exam $examId');

    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _answersBox != null) {
        final answersKey = 'user_${userId}_exam_${examId}_answers';
        final answersMap = _answersBox!.get(answersKey);
        if (answersMap != null && answersMap is Map) {
          final saved = <int, String>{};
          answersMap.forEach((key, value) {
            final qid = int.tryParse(key.toString());
            if (qid != null) {
              saved[qid] = value.toString();
            }
          });
          _savedAnswers[examId] = saved;
          log('✅ Loaded ${saved.length} saved answers for exam $examId');
          return saved;
        }
      }
    } catch (e) {
      log('Error loading saved answers: $e');
    }
    return {};
  }

  // ===== CHECK EXAM ACCESS =====
  Future<bool> checkExamAccess(int examId, {bool forceCheck = false}) async {
    log('checkExamAccess() for exam $examId');

    final lastChecked = _examAccessChecked[examId];
    if (lastChecked == true && !forceCheck && !isOffline) {
      final hasAccess = _examHasAccess[examId] ?? false;
      log('Using cached access: $hasAccess');
      return hasAccess;
    }

    _examAccessChecked[examId] = true;
    safeNotify();

    try {
      if (isOffline) {
        log('Offline, checking cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _accessBox != null) {
          final accessKey = 'user_${userId}_exam_${examId}_access';
          final cachedAccess = _accessBox!.get(accessKey) == true;
          _examHasAccess[examId] = cachedAccess;
          _examAccessController.add({examId: cachedAccess});
          log('Cached access: $cachedAccess');
          return cachedAccess;
        }

        _examHasAccess[examId] = _examHasAccess[examId] ?? false;
        _examAccessController.add({examId: _examHasAccess[examId]!});
        return _examHasAccess[examId]!;
      }

      final BuildContext? checkContext = _context;

      if (checkContext == null || !checkContext.mounted) {
        log('No context, assuming true');
        _examHasAccess[examId] = true;
        _examAccessController.add({examId: true});
        return true;
      }

      final examProvider =
          Provider.of<ExamProvider>(checkContext, listen: false);
      final exam = examProvider.getExamById(examId);

      if (exam == null) {
        log('Exam not found');
        _examHasAccess[examId] = false;
        _examAccessController.add({examId: false});
        return false;
      }

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(checkContext, listen: false);

      final hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(exam.categoryId);

      _examHasAccess[examId] = hasAccess;
      log('Access from subscription: $hasAccess');

      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _accessBox != null) {
        final accessKey = 'user_${userId}_exam_${examId}_access';
        await _accessBox!.put(accessKey, hasAccess);
        log('Saved access to Hive');
      }

      _examAccessController.add({examId: hasAccess});

      return hasAccess;
    } catch (e) {
      log('Error checking access: $e');
      _examHasAccess[examId] = false;
      _examAccessController.add({examId: false});
      return false;
    } finally {
      safeNotify();
    }
  }

  // ===== LOAD EXAM QUESTIONS =====
  Future<void> loadExamQuestions(
    int examId, {
    bool forceRefresh = false,
    bool checkAccess = true,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadExamQuestions() CALL #$callId for exam $examId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    if (_isLoadingExam[examId] == true && !forceRefresh) {
      log('⏳ Already loading exam $examId, skipping');
      return;
    }

    if (checkAccess && !isOffline) {
      log('Checking access for exam $examId');
      final hasAccess = await checkExamAccess(examId, forceCheck: forceRefresh);
      if (!hasAccess) {
        log('❌ No access to exam $examId');
        _isLoadingExam[examId] = false;
        setError('You do not have access to this exam');
        safeNotify();
        return;
      }
    }

    _isLoadingExam[examId] = true;
    setLoading();
    safeNotify();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _questionsBox != null) {
          final questionsKey = 'user_${userId}_exam_${examId}_questions';
          final cachedData = _questionsBox!.get(questionsKey);

          if (cachedData != null &&
              cachedData is Map &&
              cachedData[examId] != null) {
            final dynamic questionData = cachedData[examId];
            if (questionData is List) {
              final List<ExamQuestion> questions = [];
              for (final item in questionData) {
                if (item is ExamQuestion) {
                  questions.add(item);
                } else if (item is Map<String, dynamic>) {
                  questions.add(ExamQuestion.fromJson(item));
                }
              }
              if (questions.isNotEmpty) {
                _questionsByExam[examId] = questions;
                _lastLoadedTime[examId] = DateTime.now();
                setLoaded();
                _isLoadingExam[examId] = false;

                await loadSavedAnswersForExam(examId);

                _questionsUpdateController.add({examId: questions});
                log('✅ Loaded ${questions.length} questions from Hive for exam $examId');

                if (!isOffline && !forceRefresh) {
                  unawaited(_refreshInBackground(examId));
                }
                return;
              }
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cachedQuestions = await _getCachedExamQuestions(examId);
        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          _questionsByExam[examId] = cachedQuestions;
          _lastLoadedTime[examId] = DateTime.now();
          setLoaded();
          _isLoadingExam[examId] = false;

          await loadSavedAnswersForExam(examId);

          await _cacheExamQuestionsToHive(examId, cachedQuestions);

          _questionsUpdateController.add({examId: cachedQuestions});
          log('✅ Loaded ${cachedQuestions.length} questions from DeviceService for exam $examId');

          if (!isOffline && !forceRefresh) {
            unawaited(_refreshInBackground(examId));
          }
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        setError('You are offline. No cached exam questions available.');
        setLoaded();
        _isLoadingExam[examId] = false;
        _questionsUpdateController.add({examId: []});

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API for exam $examId');
      final response = await apiService.getExamQuestions(examId);

      List<ExamQuestion> questions = [];

      if (response.success && response.data != null) {
        questions = response.data!;
        log('✅ Received ${questions.length} questions from API');

        if (questions.isNotEmpty) {
          await _cacheExamQuestions(examId, questions);
          await _cacheExamQuestionsToHive(examId, questions);
        } else {
          log('⚠️ No questions from API, checking cache');
          final cachedQuestions = await _getCachedExamQuestions(examId);
          if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
            questions = cachedQuestions;
            log('✅ Using cached questions instead');
          }
        }

        _questionsByExam[examId] = questions;
        _lastLoadedTime[examId] = DateTime.now();
        setLoaded();
        _isLoadingExam[examId] = false;

        await loadSavedAnswersForExam(examId);

        _questionsUpdateController.add({examId: questions});
        log('✅ Success! Questions loaded for exam $examId');
      } else {
        setError(response.message);
        log('❌ API error: ${response.message}');

        final cachedQuestions = await _getCachedExamQuestions(examId);
        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          _questionsByExam[examId] = cachedQuestions;
          _questionsUpdateController.add({examId: cachedQuestions});
          log('✅ Recovered from cache after error');
        } else {
          _questionsByExam[examId] = [];
          _questionsUpdateController.add({examId: []});
        }

        setLoaded();
        _isLoadingExam[examId] = false;

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading exam questions: $e');

      setError(e.toString());
      setLoaded();
      _isLoadingExam[examId] = false;

      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _questionsUpdateController.add({examId: cachedQuestions});
        log('✅ Recovered ${cachedQuestions.length} questions from cache');
      } else {
        _questionsByExam[examId] = [];
        _questionsUpdateController.add({examId: []});
      }

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<List<ExamQuestion>?> _getCachedExamQuestions(int examId) async {
    try {
      final cached = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.examQuestionsKey(examId),
        isUserSpecific: true,
      );
      if (cached != null) {
        final List<ExamQuestion> questions = [];
        for (final json in cached) {
          if (json is Map<String, dynamic>) {
            questions.add(ExamQuestion.fromJson(json));
          }
        }
        return questions;
      }
    } catch (e) {
      log('Error reading cached questions: $e');
    }
    return null;
  }

  Future<void> _cacheExamQuestions(
      int examId, List<ExamQuestion> questions) async {
    try {
      final questionsJson = questions.map((q) => q.toJson()).toList();
      deviceService.saveCacheItem(
        AppConstants.examQuestionsKey(examId),
        questionsJson,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );
      log('Saved to DeviceService');
    } catch (e) {
      log('Error caching questions: $e');
    }
  }

  Future<void> _cacheExamQuestionsToHive(
      int examId, List<ExamQuestion> questions) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _questionsBox != null) {
        final questionsKey = 'user_${userId}_exam_${examId}_questions';
        final questionsMap = {examId: questions};
        await _questionsBox!.put(questionsKey, questionsMap);
        log('Saved to Hive');
      }
    } catch (e) {
      log('Error caching questions to Hive: $e');
    }
  }

  Future<void> _refreshInBackground(int examId) async {
    if (isOffline) return;

    try {
      await loadExamQuestions(examId, forceRefresh: true, checkAccess: false);
      log('🔄 Background refresh for exam $examId complete');
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  Future<void> _cleanupExpiredCache() async {
    log('_cleanupExpiredCache()');
    final now = DateTime.now();
    final expiredExams = <int>[];

    for (final entry in _lastLoadedTime.entries) {
      if (now.difference(entry.value) > _cacheDuration) {
        expiredExams.add(entry.key);
      }
    }

    for (final examId in expiredExams) {
      log('Cleaning up expired cache for exam $examId');
      await deviceService.removeCacheItem(
        AppConstants.examQuestionsKey(examId),
        isUserSpecific: true,
      );
      _questionsByExam.remove(examId);
      _lastLoadedTime.remove(examId);
      _isLoadingExam.remove(examId);
      _examAccessChecked.remove(examId);
      _examHasAccess.remove(examId);
    }

    if (expiredExams.isNotEmpty) {
      _questionsUpdateController.add({});
      _examAccessController.add({});
    }
  }

  // ===== SAVE EXAM PROGRESS =====
  Future<ApiResponse<Map<String, dynamic>>> saveExamProgress(
      int examResultId, List<Map<String, dynamic>> answers) async {
    log('saveExamProgress() for result $examResultId');

    setLoading();

    try {
      if (isOffline) {
        log('📝 Offline - queuing exam progress');
        await _saveExamProgressOffline(examResultId, answers);
        setLoaded();
        return ApiResponse.queued(
          message: 'Progress saved offline. Will sync when online.',
        );
      }

      final response = await apiService.saveExamProgress(examResultId, answers);
      setLoaded();
      log('✅ Exam progress saved successfully');
      return response;
    } catch (e) {
      setLoaded();
      setError(e.toString());
      log('❌ Error saving exam progress: $e');
      return ApiResponse.error(message: 'Failed to save progress: $e');
    }
  }

  Future<void> _saveExamProgressOffline(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionSaveExamProgress,
        data: {
          'exam_result_id': examResultId,
          'answers': answers,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log('📝 Queued exam progress for offline sync');
    } catch (e) {
      log('Error saving exam progress offline: $e');
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing exam questions');
    // Refresh any loaded exams
    for (final examId in _questionsByExam.keys) {
      if (_questionsByExam[examId] != null) {
        unawaited(_refreshInBackground(examId));
      }
    }
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_questionsBox != null) {
        final keysToDelete = _questionsBox!.keys
            .where((key) => key.toString().contains('user_${userId}_'))
            .toList();
        for (final key in keysToDelete) {
          await _questionsBox!.delete(key);
        }
      }

      if (_answersBox != null) {
        final keysToDelete = _answersBox!.keys
            .where((key) => key.toString().contains('user_${userId}_'))
            .toList();
        for (final key in keysToDelete) {
          await _answersBox!.delete(key);
        }
      }

      if (_accessBox != null) {
        final keysToDelete = _accessBox!.keys
            .where((key) => key.toString().contains('user_${userId}_'))
            .toList();
        for (final key in keysToDelete) {
          await _accessBox!.delete(key);
        }
      }
    }

    final keys = _questionsByExam.keys.toList();
    for (final examId in keys) {
      await deviceService.removeCacheItem(
        AppConstants.examQuestionsKey(examId),
        isUserSpecific: true,
      );
      await deviceService.removeCacheItem(
        AppConstants.examAccessKey(examId),
        isUserSpecific: true,
      );
    }

    _questionsByExam.clear();
    _lastLoadedTime.clear();
    _isLoadingExam.clear();
    _examAccessChecked.clear();
    _examHasAccess.clear();
    _savedAnswers.clear();

    await _questionsUpdateController.close();
    await _examAccessController.close();

    _questionsUpdateController =
        StreamController<Map<int, List<ExamQuestion>>>.broadcast();
    _examAccessController = StreamController<Map<int, bool>>.broadcast();

    _questionsUpdateController.add({});
    _examAccessController.add({});
    safeNotify();
  }

  @override
  void clearError() {
    clearError();
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _questionsUpdateController.close();
    _examAccessController.close();
    _questionsBox?.close();
    _answersBox?.close();
    _accessBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
