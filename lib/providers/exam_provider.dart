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
      debugLog('ExamProvider', 'Loading available exams for course: $courseId');
      final response = await apiService.getAvailableExams(courseId: courseId);

      debugLog('ExamProvider', 'API Response success: ${response.success}');
      debugLog('ExamProvider', 'API Response message: ${response.message}');
      debugLog('ExamProvider',
          'API Response data type: ${response.data?.runtimeType}');
      debugLog(
          'ExamProvider', 'API Response data length: ${response.data?.length}');

      if (response.success && response.data != null) {
        _availableExams = response.data!;
        debugLog('ExamProvider', 'Loaded ${_availableExams.length} exams');

        // Store by course if courseId provided
        if (courseId != null) {
          _examsByCourse[courseId] = _availableExams;
        }

        // Debug: Print each exam
        for (var i = 0; i < _availableExams.length; i++) {
          debugLog('ExamProvider',
              'Exam $i: ${_availableExams[i].title} - ${_availableExams[i].status}');
        }
      } else {
        debugLog('ExamProvider', 'No exams data received');
        _availableExams = [];
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('ExamProvider', 'loadAvailableExams error: $e');
      debugLog('ExamProvider', 'Stack trace: $stackTrace');
      _availableExams = [];
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
