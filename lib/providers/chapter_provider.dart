import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/chapter_model.dart';
import '../utils/helpers.dart';

class ChapterProvider with ChangeNotifier {
  final ApiService apiService;

  List<Chapter> _chapters = [];
  Map<int, List<Chapter>> _chaptersByCourse = {};
  bool _isLoading = false;
  String? _error;

  ChapterProvider({required this.apiService});

  List<Chapter> get chapters => _chapters;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Chapter> getChaptersByCourse(int courseId) {
    return _chaptersByCourse[courseId] ?? [];
  }

  List<Chapter> getFreeChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isFree).toList();
  }

  List<Chapter> getLockedChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isLocked).toList();
  }

  Future<void> loadChaptersByCourse(int courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ChapterProvider', 'Loading chapters for course: $courseId');
      final response = await apiService.getChaptersByCourse(courseId);

      final responseData = response.data ?? {};
      final chaptersData =
          responseData['chapters'] ?? responseData['data'] ?? [];

      if (chaptersData is List) {
        _chaptersByCourse[courseId] =
            List<Chapter>.from(chaptersData.map((x) => Chapter.fromJson(x)));
      } else {
        _chaptersByCourse[courseId] = [];
      }

      _chapters = [..._chapters, ..._chaptersByCourse[courseId]!];

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugLog('ChapterProvider', 'loadChaptersByCourse error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Chapter? getChapterById(int id) {
    return _chapters.firstWhere((c) => c.id == id);
  }

  void clearChapters() {
    _chapters = [];
    _chaptersByCourse = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
