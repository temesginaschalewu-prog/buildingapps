import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../utils/helpers.dart';

class ExamProvider with ChangeNotifier {
  final ApiService apiService;

  List<Exam> _availableExams = [];
  List<ExamResult> _myExamResults = [];
  Map<int, List<Exam>> _examsByCourse = {};
  bool _isLoading = false;
  String? _error;

  ExamProvider({required this.apiService});

  List<Exam> get availableExams => List.unmodifiable(_availableExams);
  List<ExamResult> get myExamResults => List.unmodifiable(_myExamResults);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Exam> getExamsByCourse(int courseId) {
    return List.unmodifiable(_examsByCourse[courseId] ?? []);
  }

  Future<void> loadAvailableExams({int? courseId}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading available exams');
      final response = await apiService.getAvailableExams(courseId: courseId);
      _availableExams = response.data ?? [];
    } catch (e) {
      _error = e.toString();
      debugLog('ExamProvider', 'loadAvailableExams error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadMyExamResults() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading my exam results');
      final response = await apiService.getMyExamResults();
      _myExamResults = response.data ?? [];
    } catch (e) {
      _error = e.toString();
      debugLog('ExamProvider', 'loadMyExamResults error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadExamsByCourse(int courseId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading exams for course: $courseId');
      final response = await apiService.getAvailableExams(courseId: courseId);
      _examsByCourse[courseId] = response.data ?? [];
    } catch (e) {
      _error = e.toString();
      debugLog('ExamProvider', 'loadExamsByCourse error: $e');
      rethrow;
    } finally {
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

  void clearExams() {
    _availableExams = [];
    _examsByCourse = {};
    _myExamResults = [];
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
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
