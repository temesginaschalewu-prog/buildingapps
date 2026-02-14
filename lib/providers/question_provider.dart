import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/question_model.dart';
import '../utils/helpers.dart';

class QuestionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Question> _questions = [];
  Map<int, List<Question>> _questionsByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, Map<int, bool>> _answerResults = {};
  Map<int, Map<int, String>> _selectedAnswers = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<String, dynamic>> _questionUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _answerUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 20);
  static const Duration answerCacheDuration = Duration(days: 7);

  QuestionProvider({required this.apiService, required this.deviceService});

  List<Question> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> loadPracticeQuestions(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[chapterId];
    final hasCache = _hasLoadedForChapter[chapterId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog('QuestionProvider',
          '✅ Using cached questions for chapter: $chapterId');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('QuestionProvider',
          '❓ Loading practice questions for chapter: $chapterId');
      final response = await apiService.getPracticeQuestions(chapterId);

      final responseData = response.data ?? {};
      final questionsData = responseData['questions'] ?? [];

      if (questionsData is List) {
        final questionList = <Question>[];
        for (var questionJson in questionsData) {
          try {
            questionList.add(Question.fromJson(questionJson));
          } catch (e) {
            debugLog('QuestionProvider',
                'Error parsing question: $e, data: $questionJson');
          }
        }

        _questionsByChapter[chapterId] = questionList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final question in questionList) {
          if (!_questions.any((q) => q.id == question.id)) {
            _questions.add(question);
          }
        }

        await deviceService.saveCacheItem(
          'questions_chapter_$chapterId',
          questionList.map((q) => q.toJson()).toList(),
          ttl: cacheDuration,
        );

        await _loadAnswerResults(chapterId);

        debugLog('QuestionProvider',
            '✅ Loaded ${questionList.length} questions for chapter $chapterId');

        _questionUpdateController.add({
          'type': 'questions_loaded',
          'chapter_id': chapterId,
          'count': questionList.length
        });
      } else {
        _questionsByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', '❌ loadPracticeQuestions error: $e');

      try {
        final cachedQuestions = await deviceService
            .getCacheItem<List<dynamic>>('questions_chapter_$chapterId');
        if (cachedQuestions != null) {
          final questionList = <Question>[];
          for (var questionJson in cachedQuestions) {
            try {
              questionList.add(Question.fromJson(questionJson));
            } catch (e) {}
          }
          _questionsByChapter[chapterId] = questionList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();

          await _loadAnswerResults(chapterId);
        }
      } catch (cacheError) {
        debugLog('QuestionProvider', 'Cache load error: $cacheError');
      }

      if (!_hasLoadedForChapter[chapterId]!) {
        _questionsByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAnswerResults(int chapterId) async {
    final questions = _questionsByChapter[chapterId] ?? [];

    if (!_answerResults.containsKey(chapterId)) {
      _answerResults[chapterId] = {};
    }
    if (!_selectedAnswers.containsKey(chapterId)) {
      _selectedAnswers[chapterId] = {};
    }

    for (final question in questions) {
      final result = await deviceService
          .getCacheItem<bool>('answer_result_${question.id}');
      if (result != null) {
        _answerResults[chapterId]![question.id] = result;
      }

      final selected = await deviceService
          .getCacheItem<String>('selected_answer_${question.id}');
      if (selected != null) {
        _selectedAnswers[chapterId]![question.id] = selected;
      }
    }
  }

  Future<Map<String, dynamic>> checkAnswer(
    int questionId,
    String selectedOption,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('QuestionProvider',
          '✅ Checking answer for question:$questionId option:$selectedOption');
      final response = await apiService.checkAnswer(questionId, selectedOption);

      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1) {
        final question = _questions[index];
        final isCorrect = response.data?['is_correct'] == true;

        _questions[index] = Question(
          id: question.id,
          chapterId: question.chapterId,
          questionText: question.questionText,
          optionA: question.optionA,
          optionB: question.optionB,
          optionC: question.optionC,
          optionD: question.optionD,
          optionE: question.optionE,
          optionF: question.optionF,
          correctOption: question.correctOption,
          explanation: response.data?['explanation'] ?? question.explanation,
          difficulty: question.difficulty,
          hasAnswer: true,
        );

        int? chapterId;
        for (final entry in _questionsByChapter.entries) {
          if (entry.value.any((q) => q.id == questionId)) {
            chapterId = entry.key;
            break;
          }
        }

        if (chapterId != null) {
          if (!_answerResults.containsKey(chapterId)) {
            _answerResults[chapterId] = {};
          }
          if (!_selectedAnswers.containsKey(chapterId)) {
            _selectedAnswers[chapterId] = {};
          }

          _answerResults[chapterId]![questionId] = isCorrect;
          _selectedAnswers[chapterId]![questionId] = selectedOption;

          await deviceService.saveCacheItem(
            'answer_result_$questionId',
            isCorrect,
            ttl: answerCacheDuration,
          );
          await deviceService.saveCacheItem(
            'selected_answer_$questionId',
            selectedOption,
            ttl: answerCacheDuration,
          );

          _answerUpdateController.add({
            'type': 'answer_checked',
            'question_id': questionId,
            'chapter_id': chapterId,
            'is_correct': isCorrect,
            'selected_option': selectedOption,
            'correct_option': question.correctOption,
            'explanation': response.data?['explanation']
          });
        }

        notifyListeners();
      }

      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', '❌ checkAnswer error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Question? getQuestionById(int id) {
    try {
      return _questions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
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

  Future<void> clearQuestionsForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterQuestions = _questionsByChapter[chapterId] ?? [];
    _questions.removeWhere(
        (question) => chapterQuestions.any((q) => q.id == question.id));
    _questionsByChapter.remove(chapterId);

    _answerResults.remove(chapterId);
    _selectedAnswers.remove(chapterId);

    await deviceService.removeCacheItem('questions_chapter_$chapterId');

    for (final question in chapterQuestions) {
      await deviceService.removeCacheItem('answer_result_${question.id}');
      await deviceService.removeCacheItem('selected_answer_${question.id}');
    }

    _questionUpdateController
        .add({'type': 'questions_cleared', 'chapter_id': chapterId});

    notifyListeners();
  }

  Future<void> clearUserData() async {
    debugLog('QuestionProvider', 'Clearing question data');

    _questions.clear();
    _questionsByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _answerResults.clear();
    _selectedAnswers.clear();

    await deviceService.clearCacheByPrefix('questions_');
    await deviceService.clearCacheByPrefix('answer_result_');
    await deviceService.clearCacheByPrefix('selected_answer_');

    _questionUpdateController.close();
    _answerUpdateController.close();

    _questionUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();
    _answerUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();

    _questionUpdateController.add({'type': 'all_questions_cleared'});
    _answerUpdateController.add({'type': 'all_answers_cleared'});

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _questionUpdateController.close();
    _answerUpdateController.close();
    super.dispose();
  }
}
