// lib/providers/question_provider.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/question_model.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Question Provider with Full Offline Support
class QuestionProvider extends ChangeNotifier
    with
        BaseProvider<QuestionProvider>,
        OfflineAwareProvider<QuestionProvider>,
        BackgroundRefreshMixin<QuestionProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  final Map<int, List<Question>> _questionsByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, Map<int, bool>> _answerResults = {};
  final Map<int, Map<int, String>> _selectedAnswers = {};

  static const Duration cacheDuration = AppConstants.cacheTTLQuestions;
  static const Duration answerCacheDuration = Duration(days: 7);
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box<Map<String, List<Question>>>? _questionsBox;
  Box<Map<String, dynamic>>? _answersBox;

  int _apiCallCount = 0;

  StreamController<Map<String, dynamic>> _questionUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _answerUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  QuestionProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('QuestionProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    // Register processor for answer checking
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSaveAnswer,
      _processAnswerCheck,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processAnswerCheck(Map<String, dynamic> data) async {
    try {
      log('Processing offline answer check');
      final questionId = data['question_id'];
      final selectedOption = data['selected_option'];

      final response = await apiService.checkAnswer(questionId, selectedOption);
      return response.success;
    } catch (e) {
      log('Error processing answer check: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedDataForAll();

    if (_hasLoadedForChapter.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      _questionsBox = await Hive.openBox<Map<String, List<Question>>>(
        AppConstants.hiveQuestionsBox,
      );
      _answersBox = await Hive.openBox<Map<String, dynamic>>('answers_box');
      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<void> _loadCachedDataForAll() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _questionsBox == null) return;

      final cachedData = _questionsBox!.get('user_${userId}_all_questions');
      if (cachedData != null) {
        // Convert string keys to int keys
        final Map<int, List<Question>> convertedData = {};
        cachedData.forEach((key, value) {
          final intKey = int.tryParse(key);
          if (intKey != null) {
            convertedData[intKey] = value;
          }
        });
        _questionsByChapter.addAll(convertedData);
        for (final chapterId in _questionsByChapter.keys) {
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
        }

        await _loadAllAnswers();

        _questionUpdateController.add({
          'type': 'all_questions_loaded',
          'chapters': _questionsByChapter.length,
        });

        log('✅ Loaded ${_questionsByChapter.length} chapters from Hive');
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _loadAllAnswers() async {
    try {
      if (_answersBox == null) return;

      final answersMap = _answersBox!.get('answers') ?? {};
      final resultsMap = _answersBox!.get('results') ?? {};

      for (final entry in answersMap.entries) {
        final parts = entry.key.toString().split('_');
        if (parts.length == 2) {
          final chapterId = int.tryParse(parts[0]);
          final questionId = int.tryParse(parts[1]);
          if (chapterId != null && questionId != null) {
            if (!_selectedAnswers.containsKey(chapterId)) {
              _selectedAnswers[chapterId] = {};
            }
            _selectedAnswers[chapterId]![questionId] = entry.value.toString();
          }
        }
      }

      for (final entry in resultsMap.entries) {
        final parts = entry.key.toString().split('_');
        if (parts.length == 2) {
          final chapterId = int.tryParse(parts[0]);
          final questionId = int.tryParse(parts[1]);
          if (chapterId != null && questionId != null) {
            if (!_answerResults.containsKey(chapterId)) {
              _answerResults[chapterId] = {};
            }
            _answerResults[chapterId]![questionId] = entry.value == true;
          }
        }
      }

      log('✅ Loaded answers from Hive');
    } catch (e) {
      log('Error loading answers: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _questionsBox != null) {
        // Convert int keys to string keys for Hive storage
        final Map<String, List<Question>> stringKeyData = {};
        _questionsByChapter.forEach((key, value) {
          stringKeyData[key.toString()] = value;
        });
        await _questionsBox!.put('user_${userId}_all_questions', stringKeyData);
        log('💾 Saved questions to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _saveChapterToHive(
      int chapterId, List<Question> questions) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _questionsBox != null) {
        final chapterMap = {chapterId.toString(): questions};
        await _questionsBox!
            .put('user_${userId}_chapter_${chapterId}_questions', chapterMap);
        await _saveToHive();
      }
    } catch (e) {
      log('Error saving chapter to Hive: $e');
    }
  }

  Future<void> _saveAnswerToHive(int chapterId, int questionId,
      String selectedOption, bool isCorrect) async {
    try {
      if (_answersBox == null) return;

      final answersMap = _answersBox!.get('answers') ?? {};
      answersMap['${chapterId}_$questionId'] = selectedOption;
      await _answersBox!.put('answers', answersMap);

      final resultsMap = _answersBox!.get('results') ?? {};
      resultsMap['${chapterId}_$questionId'] = isCorrect;
      await _answersBox!.put('results', resultsMap);

      log('💾 Saved answer for question $questionId to Hive');
    } catch (e) {
      log('Error saving answer to Hive: $e');
    }
  }

  // ===== GETTERS =====
  Stream<Map<String, dynamic>> get questionUpdates =>
      _questionUpdateController.stream;
  Stream<Map<String, dynamic>> get answerUpdates =>
      _answerUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;

  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Question> getQuestionsByChapter(int chapterId) {
    return _questionsByChapter[chapterId] ?? [];
  }

  bool? getAnswerResult(int chapterId, int questionId) {
    return _answerResults[chapterId]?[questionId];
  }

  String? getSelectedAnswer(int chapterId, int questionId) {
    return _selectedAnswers[chapterId]?[questionId];
  }

  int getCorrectAnswersCount(int chapterId) {
    final results = _answerResults[chapterId];
    if (results == null) return 0;
    return results.values.where((isCorrect) => isCorrect == true).length;
  }

  int getAttemptedQuestionsCount(int chapterId) {
    final results = _answerResults[chapterId];
    return results?.length ?? 0;
  }

  double getAccuracyPercentage(int chapterId) {
    final attempted = getAttemptedQuestionsCount(chapterId);
    final correct = getCorrectAnswersCount(chapterId);
    if (attempted == 0) return 0.0;
    return (correct / attempted) * 100;
  }

  Question? getQuestionById(int id) {
    for (final questions in _questionsByChapter.values) {
      try {
        return questions.firstWhere((q) => q.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  // ===== LOAD PRACTICE QUESTIONS =====
  Future<void> loadPracticeQuestions(
    int chapterId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadPracticeQuestions() CALL #$callId for chapter $chapterId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    if (_isLoadingForChapter[chapterId] == true && !forceRefresh) {
      log('⏳ Already loading chapter $chapterId, skipping');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    setLoading();
    safeNotify();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache for chapter $chapterId');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _questionsBox != null) {
          final cachedData = _questionsBox!
              .get('user_${userId}_chapter_${chapterId}_questions');

          if (cachedData != null && cachedData[chapterId.toString()] != null) {
            final questionList = cachedData[chapterId.toString()]!;

            _questionsByChapter[chapterId] = questionList;
            _hasLoadedForChapter[chapterId] = true;
            setLoaded();
            _isLoadingForChapter[chapterId] = false;
            _lastLoadedTime[chapterId] = DateTime.now();

            await _loadAnswerResults(chapterId, questionList);

            _questionUpdateController.add({
              'type': 'questions_loaded_cached',
              'chapter_id': chapterId,
              'count': questionList.length,
            });

            log('✅ Loaded ${questionList.length} questions from Hive for chapter $chapterId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground(chapterId));
            }
            return;
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache for chapter $chapterId');
        final cachedQuestions = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.questionsChapterKey(chapterId),
          isUserSpecific: true,
        );

        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          final List<Question> questionList = [];
          for (final questionJson in cachedQuestions) {
            try {
              if (questionJson is Map<String, dynamic>) {
                questionList.add(Question.fromJson(questionJson));
              } else if (questionJson is Map<dynamic, dynamic>) {
                // Convert Map<dynamic, dynamic> to Map<String, dynamic>
                final stringMap = questionJson
                    .map((key, value) => MapEntry(key.toString(), value));
                questionList.add(Question.fromJson(stringMap));
              }
            } catch (e) {
              log('Error parsing cached question: $e');
            }
          }

          if (questionList.isNotEmpty) {
            _questionsByChapter[chapterId] = questionList;
            _hasLoadedForChapter[chapterId] = true;
            setLoaded();
            _isLoadingForChapter[chapterId] = false;
            _lastLoadedTime[chapterId] = DateTime.now();

            await _saveChapterToHive(chapterId, questionList);

            await _loadAnswerResults(chapterId, questionList);

            _questionUpdateController.add({
              'type': 'questions_loaded_cached',
              'chapter_id': chapterId,
              'count': questionList.length,
            });

            log('✅ Loaded ${questionList.length} questions from DeviceService for chapter $chapterId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground(chapterId));
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode for chapter $chapterId');
        if (_questionsByChapter.containsKey(chapterId)) {
          _hasLoadedForChapter[chapterId] = true;
          setLoaded();
          _isLoadingForChapter[chapterId] = false;
          _questionUpdateController.add({
            'type': 'questions_loaded',
            'chapter_id': chapterId,
            'count': _questionsByChapter[chapterId]!.length,
          });
          log('✅ Showing cached questions offline for chapter $chapterId');
          return;
        }

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }

        _questionsByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _questionUpdateController.add({
          'type': 'questions_loaded',
          'chapter_id': chapterId,
          'count': 0,
        });
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API for chapter $chapterId');
      final response = await apiService.getPracticeQuestions(chapterId);

      if (response.success && response.data != null) {
        final questionList = response.data!;
        log('✅ Received ${questionList.length} questions from API');

        _questionsByChapter[chapterId] = questionList;
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _lastLoadedTime[chapterId] = DateTime.now();

        await _saveChapterToHive(chapterId, questionList);

        deviceService.saveCacheItem(
          AppConstants.questionsChapterKey(chapterId),
          questionList.map((q) => q.toJson()).toList(),
          ttl: cacheDuration,
          isUserSpecific: true,
        );

        await _loadAnswerResults(chapterId, questionList);

        _questionUpdateController.add({
          'type': 'questions_loaded',
          'chapter_id': chapterId,
          'count': questionList.length,
        });

        log('✅ Success! Questions loaded for chapter $chapterId');
      } else {
        setError(response.message);
        log('❌ API error: ${response.message}');

        _questionsByChapter[chapterId] = _questionsByChapter[chapterId] ?? [];
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _questionUpdateController.add({
          'type': 'questions_loaded',
          'chapter_id': chapterId,
          'count': _questionsByChapter[chapterId]!.length,
        });

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading questions: $e');

      setError(e.toString());
      setLoaded();
      _isLoadingForChapter[chapterId] = false;

      if (!_hasLoadedForChapter.containsKey(chapterId)) {
        await _recoverFromCache(chapterId);
      }

      _questionsByChapter[chapterId] = _questionsByChapter[chapterId] ?? [];
      _hasLoadedForChapter[chapterId] = true;
      _questionUpdateController.add({
        'type': 'questions_loaded',
        'chapter_id': chapterId,
        'count': _questionsByChapter[chapterId]!.length,
      });

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<void> _refreshInBackground(int chapterId) async {
    if (isOffline) return;

    try {
      final response = await apiService.getPracticeQuestions(chapterId);
      if (response.success && response.data != null) {
        final questionList = response.data!;

        _questionsByChapter[chapterId] = questionList;
        _lastLoadedTime[chapterId] = DateTime.now();

        await _saveChapterToHive(chapterId, questionList);

        deviceService.saveCacheItem(
          AppConstants.questionsChapterKey(chapterId),
          questionList.map((q) => q.toJson()).toList(),
          ttl: cacheDuration,
          isUserSpecific: true,
        );

        await _loadAnswerResults(chapterId, questionList);

        _questionUpdateController.add({
          'type': 'questions_refreshed',
          'chapter_id': chapterId,
          'count': questionList.length,
        });

        log('🔄 Background refresh for chapter $chapterId complete');
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  Future<void> _loadAnswerResults(
      int chapterId, List<Question> questions) async {
    if (!_answerResults.containsKey(chapterId)) {
      _answerResults[chapterId] = {};
    }
    if (!_selectedAnswers.containsKey(chapterId)) {
      _selectedAnswers[chapterId] = {};
    }

    for (final question in questions) {
      if (_answerResults[chapterId]!.containsKey(question.id)) {
        continue;
      }

      try {
        if (_answersBox != null) {
          final answersMap = _answersBox!.get('answers') ?? {};
          final resultsMap = _answersBox!.get('results') ?? {};

          final selected =
              answersMap['${chapterId}_${question.id}']?.toString();
          final result = resultsMap['${chapterId}_${question.id}'] == true;

          if (selected != null) {
            _selectedAnswers[chapterId]![question.id] = selected;
            _answerResults[chapterId]![question.id] = result;
            continue;
          }
        }
      } catch (e) {
        log('Error loading answer from Hive: $e');
      }

      final result = await deviceService.getCacheItem<bool>(
        AppConstants.answerResultKey(question.id),
        isUserSpecific: true,
      );
      if (result != null) {
        _answerResults[chapterId]![question.id] = result;
      }

      final selected = await deviceService.getCacheItem<String>(
        AppConstants.selectedAnswerKey(question.id),
        isUserSpecific: true,
      );
      if (selected != null) {
        _selectedAnswers[chapterId]![question.id] = selected;
      }
    }
  }

  Future<void> _recoverFromCache(int chapterId) async {
    log('Attempting cache recovery for chapter $chapterId');
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    // Try Hive first
    if (_questionsBox != null) {
      try {
        final cachedData =
            _questionsBox!.get('user_${userId}_chapter_${chapterId}_questions');
        if (cachedData != null && cachedData[chapterId.toString()] != null) {
          final questionList = cachedData[chapterId.toString()]!;
          _questionsByChapter[chapterId] = questionList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
          _questionUpdateController.add({
            'type': 'questions_loaded_cached',
            'chapter_id': chapterId,
            'count': questionList.length,
          });
          log('✅ Recovered ${questionList.length} questions from Hive after error');
          return;
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    // Try DeviceService
    try {
      final cachedQuestions = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.questionsChapterKey(chapterId),
        isUserSpecific: true,
      );
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        final List<Question> questionList = [];
        for (final questionJson in cachedQuestions) {
          try {
            questionList
                .add(Question.fromJson(questionJson as Map<String, dynamic>));
          } catch (e) {}
        }

        _questionsByChapter[chapterId] = questionList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
        _questionUpdateController.add({
          'type': 'questions_loaded_cached',
          'chapter_id': chapterId,
          'count': questionList.length,
        });
        log('✅ Recovered ${questionList.length} questions from DeviceService after error');
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  // ===== CHECK ANSWER =====
  Future<ApiResponse<Map<String, dynamic>>> checkAnswer(
      int questionId, String selectedOption) async {
    log('checkAnswer() for question $questionId');

    setLoading();

    try {
      if (isOffline) {
        log('📝 Offline - queuing answer check');
        await _saveAnswerOffline(questionId, selectedOption);
        setLoaded();
        return ApiResponse.queued(
          message: 'Answer saved offline. Will sync when online.',
        );
      }

      final response = await apiService.checkAnswer(questionId, selectedOption);

      int? chapterId;
      for (final entry in _questionsByChapter.entries) {
        if (entry.value.any((q) => q.id == questionId)) {
          chapterId = entry.key;
          break;
        }
      }

      if (chapterId != null) {
        final isCorrect = response.data?['is_correct'] == true;

        if (!_answerResults.containsKey(chapterId)) {
          _answerResults[chapterId] = {};
        }
        if (!_selectedAnswers.containsKey(chapterId)) {
          _selectedAnswers[chapterId] = {};
        }

        _answerResults[chapterId]![questionId] = isCorrect;
        _selectedAnswers[chapterId]![questionId] = selectedOption;

        await _saveAnswerToHive(
            chapterId, questionId, selectedOption, isCorrect);

        deviceService.saveCacheItem(
          AppConstants.answerResultKey(questionId),
          isCorrect,
          ttl: answerCacheDuration,
          isUserSpecific: true,
        );
        deviceService.saveCacheItem(
          AppConstants.selectedAnswerKey(questionId),
          selectedOption,
          ttl: answerCacheDuration,
          isUserSpecific: true,
        );

        _answerUpdateController.add({
          'type': 'answer_checked',
          'question_id': questionId,
          'chapter_id': chapterId,
          'is_correct': isCorrect,
          'selected_option': selectedOption,
        });
      }

      setLoaded();
      return response;
    } catch (e) {
      setLoaded();
      setError(e.toString());
      log('❌ Error checking answer: $e');
      return ApiResponse.error(message: 'Failed to check answer: $e');
    }
  }

  Future<void> _saveAnswerOffline(int questionId, String selectedOption) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionSaveAnswer,
        data: {
          'question_id': questionId,
          'selected_option': selectedOption,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _answerUpdateController.add({
        'type': 'answer_queued',
        'question_id': questionId,
        'selected_option': selectedOption,
      });

      log('📝 Queued answer for question $questionId');
    } catch (e) {
      log('Error queueing answer offline: $e');
    }
  }

  // ===== CLEAR METHODS =====
  Future<void> clearQuestionsForChapter(int chapterId) async {
    log('clearQuestionsForChapter() for chapter $chapterId');

    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterQuestions = _questionsByChapter[chapterId] ?? [];
    _questionsByChapter.remove(chapterId);

    _answerResults.remove(chapterId);
    _selectedAnswers.remove(chapterId);

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _questionsBox != null) {
      await _questionsBox!
          .delete('user_${userId}_chapter_${chapterId}_questions');
    }

    await deviceService.removeCacheItem(
      AppConstants.questionsChapterKey(chapterId),
      isUserSpecific: true,
    );

    for (final question in chapterQuestions) {
      if (_answersBox != null) {
        final answersMap = _answersBox!.get('answers') ?? {};
        final resultsMap = _answersBox!.get('results') ?? {};
        answersMap.remove('${chapterId}_${question.id}');
        resultsMap.remove('${chapterId}_${question.id}');
        await _answersBox!.put('answers', answersMap);
        await _answersBox!.put('results', resultsMap);
      }

      await deviceService.removeCacheItem(
        AppConstants.answerResultKey(question.id),
        isUserSpecific: true,
      );
      await deviceService.removeCacheItem(
        AppConstants.selectedAnswerKey(question.id),
        isUserSpecific: true,
      );
    }

    _questionUpdateController
        .add({'type': 'questions_cleared', 'chapter_id': chapterId});
    safeNotify();
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (isOffline) return;

    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true &&
          !(_isLoadingForChapter[chapterId] ?? false)) {
        unawaited(_refreshInBackground(chapterId));
      }
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing questions');
    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true) {
        await loadPracticeQuestions(chapterId, forceRefresh: true);
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
        await _answersBox!.clear();
      }
    }

    _questionsByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _answerResults.clear();
    _selectedAnswers.clear();
    stopBackgroundRefresh();

    await deviceService.clearCacheByPrefix('questions_');
    await deviceService.clearCacheByPrefix('answer_result_');
    await deviceService.clearCacheByPrefix('selected_answer_');

    await _questionUpdateController.close();
    await _answerUpdateController.close();

    _questionUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();
    _answerUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();

    _questionUpdateController.add({'type': 'all_questions_cleared'});
    _answerUpdateController.add({'type': 'all_answers_cleared'});
    safeNotify();
  }

  @override
  void clearError() {
    clearError();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _questionUpdateController.close();
    _answerUpdateController.close();
    _questionsBox?.close();
    _answersBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
