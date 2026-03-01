import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/exam_question_model.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class ExamQuestionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  BuildContext? _context;

  final List<ExamQuestion> _examQuestions = [];
  final Map<int, List<ExamQuestion>> _questionsByExam = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, bool> _isLoadingExam = {};
  final Map<int, bool> _examAccessChecked = {};
  final Map<int, bool> _examHasAccess = {};
  bool _isLoading = false;
  String? _error;
  Timer? _cacheCleanupTimer;

  StreamController<Map<int, List<ExamQuestion>>> _questionsUpdateController =
      StreamController<Map<int, List<ExamQuestion>>>.broadcast();
  StreamController<Map<int, bool>> _examAccessController =
      StreamController<Map<int, bool>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);

  ExamQuestionProvider({
    required this.apiService,
    required this.deviceService,
  }) {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
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
  Stream<Map<int, List<ExamQuestion>>> get questionsUpdates =>
      _questionsUpdateController.stream;
  Stream<Map<int, bool>> get examAccessUpdates => _examAccessController.stream;

  bool hasExamAccess(int examId) => _examHasAccess[examId] ?? false;
  bool isExamAccessChecked(int examId) => _examAccessChecked[examId] ?? false;
  bool isLoadingExam(int examId) => _isLoadingExam[examId] ?? false;

  List<ExamQuestion> getQuestionsByExam(int examId) {
    return List.unmodifiable(_questionsByExam[examId] ?? []);
  }

  Future<bool> checkExamAccess(int examId, {bool forceCheck = false}) async {
    final lastChecked = _examAccessChecked[examId];
    if (lastChecked == true && !forceCheck) {
      final hasAccess = _examHasAccess[examId] ?? false;
      debugLog('ExamQuestionProvider',
          'Using cached access for exam $examId: $hasAccess');
      return hasAccess;
    }

    _examAccessChecked[examId] = true;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider', 'Checking access for exam: $examId');

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

    if (checkAccess) {
      final hasAccess = await checkExamAccess(examId, forceCheck: forceRefresh);
      if (!hasAccess) {
        debugLog('ExamQuestionProvider',
            'No access to exam $examId, skipping question load');
        return;
      }
    }

    if (!forceRefresh) {
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
      final response = await apiService.getExamQuestions(examId);

      debugLog(
          'ExamQuestionProvider', 'API Response success: ${response.success}');
      debugLog('ExamQuestionProvider',
          'API Response data type: ${response.data.runtimeType}');

      List<ExamQuestion> questions = [];

      // ✅ CRITICAL FIX: Directly use the response.data if it's already a List
      if (response.data is List) {
        final items = response.data as List;
        debugLog('ExamQuestionProvider',
            'Response is direct List with ${items.length} items');

        // The items should already be ExamQuestion objects from ApiService
        questions = items.whereType<ExamQuestion>().toList();
        debugLog('ExamQuestionProvider',
            '✅ Directly got ${questions.length} ExamQuestion objects');
      }
      // If it's a Map, try to extract the data
      else if (response.data is Map<String, dynamic>) {
        final dataMap = response.data as Map<String, dynamic>;
        debugLog('ExamQuestionProvider',
            'Response is Map with keys: ${dataMap.keys}');

        if (dataMap.containsKey('data') && dataMap['data'] is List) {
          final items = dataMap['data'] as List;
          debugLog('ExamQuestionProvider',
              'Found data list with ${items.length} items');

          for (var item in items) {
            if (item is Map<String, dynamic>) {
              try {
                final examQuestion = ExamQuestion(
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

      // Save to cache if we have questions
      if (questions.isNotEmpty) {
        await _cacheExamQuestions(examId, questions);
      } else {
        debugLog('ExamQuestionProvider',
            '⚠️ No questions parsed from response for exam $examId');

        // Try to use cached questions as fallback
        final cachedQuestions = await _getCachedExamQuestions(examId);
        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          questions = cachedQuestions;
          debugLog(
              'ExamQuestionProvider', '✅ Using cached questions as fallback');
        }
      }

      // ALWAYS update the state
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
      final cached = await deviceService
          .getCacheItem<List<Map<String, dynamic>>>('exam_questions_$examId',
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
        'exam_questions_$examId',
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

  Future<void> clearExamAccessCache(int examId) async {
    _examAccessChecked.remove(examId);
    _examHasAccess.remove(examId);
    await deviceService.removeCacheItem('exam_access_$examId',
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

  ExamQuestion? getQuestionById(int id) {
    try {
      return _examQuestions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
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
      await deviceService.removeCacheItem('exam_questions_$examId',
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
          '🧹 Cleared cache for ${expiredExams.length} expired exams');
    }
  }

  Future<void> clearUserData() async {
    debugLog('ExamQuestionProvider', 'Clearing exam question data');

    final keys = _questionsByExam.keys.toList();
    for (final examId in keys) {
      await deviceService.removeCacheItem('exam_questions_$examId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('exam_access_$examId',
          isUserSpecific: true);
    }

    _examQuestions.clear();
    _questionsByExam.clear();
    _lastLoadedTime.clear();
    _isLoadingExam.clear();
    _examAccessChecked.clear();
    _examHasAccess.clear();

    _questionsUpdateController.close();
    _examAccessController.close();

    _questionsUpdateController =
        StreamController<Map<int, List<ExamQuestion>>>.broadcast();
    _examAccessController = StreamController<Map<int, bool>>.broadcast();

    _questionsUpdateController.add({});
    _examAccessController.add({});

    _notifySafely();
  }

  Future<void> clearExamQuestionsForExam(int examId) async {
    await deviceService.removeCacheItem('exam_questions_$examId',
        isUserSpecific: true);
    await deviceService.removeCacheItem('exam_access_$examId',
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

  int min(int a, int b) => a < b ? a : b;
}
