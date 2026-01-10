import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/exam_question_model.dart';
import '../utils/helpers.dart';

class ExamQuestionProvider with ChangeNotifier {
  final ApiService apiService;

  List<ExamQuestion> _examQuestions = [];
  Map<int, List<ExamQuestion>> _questionsByExam = {};
  bool _isLoading = false;
  String? _error;

  ExamQuestionProvider({required this.apiService});

  List<ExamQuestion> get examQuestions => _examQuestions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<ExamQuestion> getQuestionsByExam(int examId) {
    return _questionsByExam[examId] ?? [];
  }

  Future<void> loadExamQuestions(int examId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ExamQuestionProvider', 'Loading questions for exam: $examId');
      final response = await apiService.getExamQuestions(examId);

      // Properly handle the API response
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        // Check different possible response formats
        List<ExamQuestion> questions = [];

        if (data['questions'] is List) {
          questions = (data['questions'] as List).map((item) {
            return ExamQuestion.fromJson(item);
          }).toList();
        } else if (data['data'] is List) {
          questions = (data['data'] as List).map((item) {
            return ExamQuestion.fromJson(item);
          }).toList();
        }

        _questionsByExam[examId] = questions;
        _examQuestions = [..._questionsByExam[examId]!];

        debugLog('ExamQuestionProvider',
            'Loaded ${questions.length} questions for exam $examId');
      } else {
        // Fallback to current logic
        _questionsByExam[examId] = [];
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', 'loadExamQuestions error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveExamProgress(
    int examResultId,
    List<Map<String, dynamic>> answers,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ExamQuestionProvider',
          'Saving progress for exam result: $examResultId');
      final response = await apiService.saveExamProgress(examResultId, answers);
      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', 'saveExamProgress error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ExamQuestion? getQuestionById(int id) {
    return _examQuestions.firstWhere((q) => q.id == id);
  }

  void clearExamQuestions() {
    _examQuestions = [];
    _questionsByExam = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
