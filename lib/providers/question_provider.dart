import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/question_model.dart';
import '../utils/helpers.dart';

class QuestionProvider with ChangeNotifier {
  final ApiService apiService;

  List<Question> _questions = [];
  Map<int, List<Question>> _questionsByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  static const Duration cacheDuration = Duration(minutes: 20);

  QuestionProvider({required this.apiService});

  List<Question> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

        debugLog('QuestionProvider',
            '✅ Loaded ${questionList.length} questions for chapter $chapterId');
      } else {
        _questionsByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', '❌ loadPracticeQuestions error: $e');

      if (!_hasLoadedForChapter[chapterId]!) {
        _questionsByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
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
        _questions[index] = Question(
          id: _questions[index].id,
          chapterId: _questions[index].chapterId,
          questionText: _questions[index].questionText,
          optionA: _questions[index].optionA,
          optionB: _questions[index].optionB,
          optionC: _questions[index].optionC,
          optionD: _questions[index].optionD,
          optionE: _questions[index].optionE,
          optionF: _questions[index].optionF,
          correctOption: _questions[index].correctOption,
          explanation: response.data?['explanation'],
          difficulty: _questions[index].difficulty,
          hasAnswer: true,
        );
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

  void clearQuestionsForChapter(int chapterId) {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterQuestions = _questionsByChapter[chapterId] ?? [];
    _questions.removeWhere(
        (question) => chapterQuestions.any((q) => q.id == question.id));
    _questionsByChapter.remove(chapterId);

    notifyListeners();
  }

  void clearAllQuestions() {
    _questions.clear();
    _questionsByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
