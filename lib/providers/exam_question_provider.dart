import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/exam_question_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';
import '../utils/parsers.dart';

class ExamQuestionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;
  BuildContext? _context;

  final List<ExamQuestion> _examQuestions = [];
  final Map<int, List<ExamQuestion>> _questionsByExam = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, bool> _isLoadingExam = {};
  final Map<int, bool> _examAccessChecked = {};
  final Map<int, bool> _examHasAccess = {};
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;
  Timer? _cacheCleanupTimer;

  StreamController<Map<int, List<ExamQuestion>>> _questionsUpdateController =
      StreamController<Map<int, List<ExamQuestion>>>.broadcast();
  StreamController<Map<int, bool>> _examAccessController =
      StreamController<Map<int, bool>>.broadcast();

  static const Duration _cacheDuration = AppConstants.cacheTTLQuestions;
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);

  ExamQuestionProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
    });
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        notifyListeners();
      }
    });
  }

  void setContext(BuildContext context) {
    if (_context == null) {
      _context = context;
      debugLog('ExamQuestionProvider', '✅ Context set');
    }
  }

  List<ExamQuestion> get examQuestions => List.unmodifiable(_examQuestions);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  Stream<Map<int, List<ExamQuestion>>> get questionsUpdates =>
      _questionsUpdateController.stream;
  Stream<Map<int, bool>> get examAccessUpdates => _examAccessController.stream;

  bool hasExamAccess(int examId) => _examHasAccess[examId] ?? false;
  bool isExamAccessChecked(int examId) => _examAccessChecked[examId] ?? false;
  bool isLoadingExam(int examId) => _isLoadingExam[examId] ?? false;

  List<ExamQuestion> getQuestionsByExam(int examId) {
    return List.unmodifiable(_questionsByExam[examId] ?? []);
  }

  ExamQuestion? getQuestionById(int id) {
    try {
      return _examQuestions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkExamAccess(int examId, {bool forceCheck = false}) async {
    final lastChecked = _examAccessChecked[examId];
    if (lastChecked == true && !forceCheck && !_isOffline) {
      final hasAccess = _examHasAccess[examId] ?? false;
      debugLog('ExamQuestionProvider',
          'Using cached access for exam $examId: $hasAccess');
      return hasAccess;
    }

    _examAccessChecked[examId] = true;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider', 'Checking access for exam: $examId');

      if (_isOffline) {
        debugLog('ExamQuestionProvider', 'Offline - using cached access');
        _examHasAccess[examId] = _examHasAccess[examId] ?? false;
        _examAccessController.add({examId: _examHasAccess[examId]!});
        return _examHasAccess[examId]!;
      }

      final BuildContext? checkContext = _context;

      if (checkContext == null || !checkContext.mounted) {
        debugLog('ExamQuestionProvider',
            'Context not available, assuming access for now');
        _examHasAccess[examId] = true;
        _examAccessController.add({examId: true});
        return true;
      }

      final examProvider =
          Provider.of<ExamProvider>(checkContext, listen: false);
      final exam = examProvider.getExamById(examId);

      if (exam == null) {
        debugLog('ExamQuestionProvider', 'Exam not found: $examId');
        _examHasAccess[examId] = false;
        _examAccessController.add({examId: false});
        return false;
      }

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(checkContext, listen: false);

      debugLog('ExamQuestionProvider',
          'Checking subscription for category: ${exam.categoryId}');

      final hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(exam.categoryId);

      _examHasAccess[examId] = hasAccess;
      _examAccessController.add({examId: hasAccess});

      debugLog('ExamQuestionProvider',
          'Exam $examId access check result: $hasAccess');

      return hasAccess;
    } on ApiError catch (e) {
      debugLog('ExamQuestionProvider',
          'Access check error for exam $examId: ${e.message}');
      _examHasAccess[examId] = false;
      _examAccessController.add({examId: false});
      return false;
    } catch (e) {
      debugLog('ExamQuestionProvider',
          'Unexpected access check error for exam $examId: $e');
      _examHasAccess[examId] = false;
      _examAccessController.add({examId: false});
      return false;
    } finally {
      _notifySafely();
    }
  }

  Future<void> loadExamQuestions(int examId,
      {bool forceRefresh = false, bool checkAccess = true}) async {
    if (_isLoadingExam[examId] == true && !forceRefresh) return;

    if (checkAccess && !_isOffline) {
      final hasAccess = await checkExamAccess(examId, forceCheck: forceRefresh);
      if (!hasAccess) {
        debugLog('ExamQuestionProvider',
            'No access to exam $examId, skipping question load');
        return;
      }
    }

    if (!forceRefresh && !_isOffline) {
      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        _lastLoadedTime[examId] = DateTime.now();
        _questionsUpdateController.add({examId: cachedQuestions});
        debugLog('ExamQuestionProvider',
            '✅ Loaded ${cachedQuestions.length} questions from cache for exam $examId');
        return;
      }
    }

    _isLoadingExam[examId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider', 'Loading questions for exam: $examId');

      if (_isOffline) {
        _error = 'You are offline. Using cached data.';
        _isLoadingExam[examId] = false;
        _isLoading = false;
        _notifySafely();
        return;
      }

      final response = await apiService.getExamQuestions(examId);

      debugLog(
          'ExamQuestionProvider', 'API Response success: ${response.success}');
      debugLog('ExamQuestionProvider',
          'API Response data type: ${response.data.runtimeType}');

      List<ExamQuestion> questions = [];

      if (response.data is List) {
        final items = response.data as List;
        debugLog('ExamQuestionProvider',
            'Response is direct List with ${items.length} items');

        questions = items.whereType<ExamQuestion>().toList();
        debugLog('ExamQuestionProvider',
            '✅ Directly got ${questions.length} ExamQuestion objects');
      } else if (response.data is Map<String, dynamic>) {
        final dataMap = response.data as Map<String, dynamic>;
        debugLog('ExamQuestionProvider',
            'Response is Map with keys: ${dataMap.keys}');

        if (dataMap.containsKey('data') && dataMap['data'] is List) {
          final items = dataMap['data'] as List;
          debugLog('ExamQuestionProvider',
              'Found data list with ${items.length} items');

          for (final item in items) {
            if (item is Map<String, dynamic>) {
              try {
                final examQuestion = ExamQuestion(
                  id: Parsers.parseInt(item['id']),
                  examId: examId,
                  questionId:
                      Parsers.parseInt(item['id'] ?? item['exam_question_id']),
                  displayOrder: Parsers.parseInt(item['display_order']),
                  marks: Parsers.parseInt(item['marks'], 1),
                  questionText: item['question_text']?.toString() ?? '',
                  optionA: item['option_a']?.toString(),
                  optionB: item['option_b']?.toString(),
                  optionC: item['option_c']?.toString(),
                  optionD: item['option_d']?.toString(),
                  optionE: item['option_e']?.toString(),
                  optionF: item['option_f']?.toString(),
                  difficulty: (item['difficulty']?.toString() ?? 'medium')
                      .toLowerCase(),
                  hasAnswer: Parsers.parseBool(item['correct_option']),
                );
                questions.add(examQuestion);
                debugLog('ExamQuestionProvider',
                    'Added question ${questions.length} from data field');
              } catch (e) {
                debugLog(
                    'ExamQuestionProvider', 'Error parsing question item: $e');
              }
            }
          }
        }
      }

      debugLog('ExamQuestionProvider',
          '✅ Successfully processed ${questions.length} questions for exam $examId');

      if (questions.isNotEmpty) {
        await _cacheExamQuestions(examId, questions);
      } else {
        debugLog('ExamQuestionProvider',
            '⚠️ No questions parsed from response for exam $examId');

        final cachedQuestions = await _getCachedExamQuestions(examId);
        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          questions = cachedQuestions;
          debugLog(
              'ExamQuestionProvider', '✅ Using cached questions as fallback');
        }
      }

      _questionsByExam[examId] = questions;
      _updateGlobalQuestions(questions);
      _lastLoadedTime[examId] = DateTime.now();
      _questionsUpdateController.add({examId: questions});

      debugLog('ExamQuestionProvider',
          '📊 Final questions for exam $examId: ${questions.length} items');
    } on ApiError catch (e) {
      _error = e.message;
      debugLog(
          'ExamQuestionProvider', '❌ loadExamQuestions error: ${e.message}');

      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        debugLog(
            'ExamQuestionProvider', '✅ Fallback to cached questions on error');
        _questionsUpdateController.add({examId: cachedQuestions});
      } else {
        _questionsByExam[examId] = [];
        _questionsUpdateController.add({examId: []});
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', '❌ Unexpected error: $e');
      debugLog('ExamQuestionProvider', 'Stack trace: $stackTrace');

      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        debugLog('ExamQuestionProvider',
            '✅ Fallback to cached questions on unexpected error');
        _questionsUpdateController.add({examId: cachedQuestions});
      } else {
        _questionsByExam[examId] = [];
        _questionsUpdateController.add({examId: []});
      }
    } finally {
      _isLoadingExam[examId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<List<ExamQuestion>?> _getCachedExamQuestions(int examId) async {
    try {
      final cached =
          await deviceService.getCacheItem<List<Map<String, dynamic>>>(
              AppConstants.examQuestionsKey(examId),
              isUserSpecific: true);
      if (cached != null) {
        return cached.map(ExamQuestion.fromJson).toList();
      }
    } catch (e) {
      debugLog('ExamQuestionProvider', 'Error reading cached questions: $e');
    }
    return null;
  }

  Future<void> _cacheExamQuestions(
      int examId, List<ExamQuestion> questions) async {
    try {
      final questionsJson = questions.map((q) => q.toJson()).toList();
      await deviceService.saveCacheItem(
        AppConstants.examQuestionsKey(examId),
        questionsJson,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('ExamQuestionProvider', 'Error caching questions: $e');
    }
  }

  void _updateGlobalQuestions(List<ExamQuestion> questions) {
    for (final question in questions) {
      final index = _examQuestions.indexWhere((q) => q.id == question.id);
      if (index == -1) {
        _examQuestions.add(question);
      } else {
        _examQuestions[index] = question;
      }
    }
  }

  Future<void> _cleanupExpiredCache() async {
    debugLog(
        'ExamQuestionProvider', '🔄 Cleaning up expired exam question cache');
    final now = DateTime.now();
    final expiredExams = <int>[];

    for (final entry in _lastLoadedTime.entries) {
      if (now.difference(entry.value) > _cacheDuration) {
        expiredExams.add(entry.key);
      }
    }

    for (final examId in expiredExams) {
      await deviceService.removeCacheItem(AppConstants.examQuestionsKey(examId),
          isUserSpecific: true);
      _questionsByExam.remove(examId);
      _lastLoadedTime.remove(examId);
      _isLoadingExam.remove(examId);
      _examAccessChecked.remove(examId);
      _examHasAccess.remove(examId);
    }

    if (expiredExams.isNotEmpty) {
      _questionsUpdateController.add({});
      _examAccessController.add({});
      debugLog('ExamQuestionProvider',
          ' Cleared cache for ${expiredExams.length} expired exams');
    }
  }

  Future<Map<String, dynamic>> saveExamProgress(
    int examResultId,
    List<Map<String, dynamic>> answers,
  ) async {
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider',
          'Saving progress for exam result: $examResultId');

      if (_isOffline) {
        await _saveExamProgressOffline(examResultId, answers);
        return {'queued': true};
      }

      final response = await apiService.saveExamProgress(examResultId, answers);
      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', 'saveExamProgress error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _saveExamProgressOffline(
      int examResultId, List<Map<String, dynamic>> answers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_exam_progress';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);
      List<Map<String, dynamic>> pendingProgress = [];

      if (existingJson != null) {
        try {
          pendingProgress =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog(
              'ExamQuestionProvider', 'Error parsing pending progress: $e');
        }
      }

      pendingProgress.add({
        'exam_result_id': examResultId,
        'answers': answers,
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

      await prefs.setString(userPendingKey, jsonEncode(pendingProgress));
      debugLog('ExamQuestionProvider',
          '📝 Saved exam progress offline for result $examResultId');
    } catch (e) {
      debugLog(
          'ExamQuestionProvider', 'Error saving exam progress offline: $e');
    }
  }

  Future<void> syncPendingExamProgress() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_exam_progress';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingProgress = [];
      try {
        pendingProgress =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('ExamQuestionProvider', 'Error parsing pending progress: $e');
        await prefs.remove(userPendingKey);
        return;
      }

      if (pendingProgress.isEmpty) return;

      debugLog('ExamQuestionProvider',
          '🔄 Syncing ${pendingProgress.length} pending exam progress items');

      final List<Map<String, dynamic>> failedProgress = [];

      for (final progress in pendingProgress) {
        try {
          await apiService.saveExamProgress(
            progress['exam_result_id'],
            List<Map<String, dynamic>>.from(progress['answers']),
          );
          debugLog('ExamQuestionProvider',
              '✅ Synced progress for exam result ${progress['exam_result_id']}');
        } catch (e) {
          debugLog(
              'ExamQuestionProvider', '❌ Failed to sync exam progress: $e');

          final retryCount = (progress['retry_count'] ?? 0) + 1;
          if (retryCount <= 3) {
            progress['retry_count'] = retryCount;
            failedProgress.add(progress);
          }
        }
      }

      if (failedProgress.isEmpty) {
        await prefs.remove(userPendingKey);
        debugLog('ExamQuestionProvider', '✅ All pending exam progress synced');
      } else {
        await prefs.setString(userPendingKey, jsonEncode(failedProgress));
        debugLog('ExamQuestionProvider',
            '⚠️ ${failedProgress.length} exam progress items still pending');
      }
    } catch (e) {
      debugLog(
          'ExamQuestionProvider', 'Error syncing pending exam progress: $e');
    }
  }

  Future<void> clearExamAccessCache(int examId) async {
    _examAccessChecked.remove(examId);
    _examHasAccess.remove(examId);
    await deviceService.removeCacheItem(AppConstants.examAccessKey(examId),
        isUserSpecific: true);
    _notifySafely();
  }

  Future<void> refreshAllExamAccess() async {
    debugLog('ExamQuestionProvider', 'Refreshing all exam access');
    _examAccessChecked.clear();
    _examHasAccess.clear();

    await deviceService.clearCacheByPrefix('exam_access_');

    _examAccessController.add({});
    _notifySafely();
  }

  Future<void> clearExamQuestionsForExam(int examId) async {
    await deviceService.removeCacheItem(AppConstants.examQuestionsKey(examId),
        isUserSpecific: true);
    await deviceService.removeCacheItem(AppConstants.examAccessKey(examId),
        isUserSpecific: true);

    final examQuestions = _questionsByExam[examId] ?? [];
    _examQuestions.removeWhere(
        (question) => examQuestions.any((q) => q.id == question.id));

    _questionsByExam.remove(examId);
    _lastLoadedTime.remove(examId);
    _isLoadingExam.remove(examId);
    _examAccessChecked.remove(examId);
    _examHasAccess.remove(examId);

    _questionsUpdateController.add({examId: []});
    _examAccessController.add({examId: false});

    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('ExamQuestionProvider', 'Clearing exam question data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('ExamQuestionProvider',
          '✅ Same user - preserving exam question cache');
      return;
    }

    // Clear pending exam progress
    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_exam_progress_$userId');
    }

    final keys = _questionsByExam.keys.toList();
    for (final examId in keys) {
      await deviceService.removeCacheItem(AppConstants.examQuestionsKey(examId),
          isUserSpecific: true);
      await deviceService.removeCacheItem(AppConstants.examAccessKey(examId),
          isUserSpecific: true);
    }

    _examQuestions.clear();
    _questionsByExam.clear();
    _lastLoadedTime.clear();
    _isLoadingExam.clear();
    _examAccessChecked.clear();
    _examHasAccess.clear();

    await _questionsUpdateController.close();
    await _examAccessController.close();

    _questionsUpdateController =
        StreamController<Map<int, List<ExamQuestion>>>.broadcast();
    _examAccessController = StreamController<Map<int, bool>>.broadcast();

    _questionsUpdateController.add({});
    _examAccessController.add({});

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _questionsUpdateController.close();
    _examAccessController.close();
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
