import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/question_model.dart';
import '../utils/helpers.dart';

class QuestionProvider with ChangeNotifier {
  final ApiService apiService;

  List<Question> _questions = [];
  Map<int, List<Question>> _questionsByChapter = {};
  bool _isLoading = false;
  String? _error;

  QuestionProvider({required this.apiService});

  List<Question> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Question> getQuestionsByChapter(int chapterId) {
    return _questionsByChapter[chapterId] ?? [];
  }

  Future<void> loadPracticeQuestions(int chapterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('QuestionProvider',
          'Loading practice questions for chapter: $chapterId');
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
      } else {
        _questionsByChapter[chapterId] = [];
      }

      _questions = [..._questions, ..._questionsByChapter[chapterId]!];

      debugLog('QuestionProvider',
          'Loaded ${_questionsByChapter[chapterId]!.length} questions for chapter $chapterId');
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', 'loadPracticeQuestions error: $e');
      _questionsByChapter[chapterId] = [];
    } finally {
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
          'Checking answer for question:$questionId option:$selectedOption');
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
      debugLog('QuestionProvider', 'checkAnswer error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Question? getQuestionById(int id) {
    return _questions.firstWhere((q) => q.id == id);
  }

  void clearQuestions() {
    _questions = [];
    _questionsByChapter = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
