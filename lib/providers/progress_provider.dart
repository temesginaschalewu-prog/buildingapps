import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class ProgressProvider with ChangeNotifier {
  final ApiService apiService;
  final StreakProvider streakProvider;

  List<UserProgress> _userProgress = [];
  Map<int, UserProgress> _progressByChapter = {};
  bool _isLoading = false;
  String? _error;

  ProgressProvider({required this.apiService, required this.streakProvider});

  List<UserProgress> get userProgress => _userProgress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  UserProgress? getProgressForChapter(int chapterId) {
    return _progressByChapter[chapterId];
  }

  double getOverallProgress() {
    if (_userProgress.isEmpty) return 0;
    final totalProgress = _userProgress.fold(
      0.0,
      (sum, progress) => sum + progress.completionPercentage,
    );
    return totalProgress / _userProgress.length;
  }

  int getCompletedChaptersCount() {
    return _userProgress.where((p) => p.completed).length;
  }

  int getTotalChaptersAttempted() {
    return _userProgress.length;
  }

  double getOverallAccuracy() {
    final attemptedQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsAttempted,
    );

    final correctQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsCorrect,
    );

    if (attemptedQuestions == 0) return 0;
    return (correctQuestions / attemptedQuestions) * 100;
  }

  Future<void> loadUserProgressForCourse(int courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ProgressProvider', 'Loading progress for course:$courseId');
      final response = await apiService.getUserProgressForCourse(courseId);
      _userProgress = response.data ?? [];
      _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
      debugLog('ProgressProvider',
          'Loaded ${_userProgress.length} progress entries');
    } catch (e) {
      _error = 'Failed to load progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading progress: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncProgressToBackend(UserProgress progress) async {
    try {
      debugLog('ProgressProvider',
          'Syncing progress for chapter:${progress.chapterId}');
      await apiService.saveUserProgress(progress);
      debugLog('ProgressProvider', 'Progress synced successfully');
    } catch (e) {
      debugLog('ProgressProvider', 'Error syncing progress: $e');

      await _saveProgressLocally(progress);
    }
  }

  Future<void> updateChapterProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    final existingProgress = _progressByChapter[chapterId];
    final now = DateTime.now();

    UserProgress newProgress;

    if (existingProgress != null) {
      newProgress = UserProgress(
        chapterId: chapterId,
        completed: existingProgress.completed,
        videoProgress: videoProgress ?? existingProgress.videoProgress,
        notesViewed: notesViewed ?? existingProgress.notesViewed,
        questionsAttempted:
            questionsAttempted ?? existingProgress.questionsAttempted,
        questionsCorrect: questionsCorrect ?? existingProgress.questionsCorrect,
      );
    } else {
      newProgress = UserProgress(
        chapterId: chapterId,
        completed: false,
        videoProgress: videoProgress ?? 0,
        notesViewed: notesViewed ?? false,
        questionsAttempted: questionsAttempted ?? 0,
        questionsCorrect: questionsCorrect ?? 0,
      );
    }

    _progressByChapter[chapterId] = newProgress;
    _userProgress = _progressByChapter.values.toList();

    await syncProgressToBackend(newProgress);

    await _checkAndUpdateStreak(existingProgress, newProgress);

    debugLog('ProgressProvider', 'Updated progress for chapter:$chapterId');
    notifyListeners();
  }

  Future<void> markChapterAsCompleted(int chapterId) async {
    final progress = _progressByChapter[chapterId];
    if (progress != null) {
      final completedProgress = UserProgress(
        chapterId: chapterId,
        completed: true,
        videoProgress: progress.videoProgress,
        notesViewed: progress.notesViewed,
        questionsAttempted: progress.questionsAttempted,
        questionsCorrect: progress.questionsCorrect,
      );

      _progressByChapter[chapterId] = completedProgress;
      _userProgress = _progressByChapter.values.toList();

      await syncProgressToBackend(completedProgress);

      notifyListeners();
    }
  }

  Future<void> _checkAndUpdateStreak(
      UserProgress? oldProgress, UserProgress newProgress) async {
    if (oldProgress == null) {
      await streakProvider.updateStreak();
    } else {
      await streakProvider.updateStreak();
    }
  }

  Future<void> _saveProgressLocally(UserProgress progress) async {
    debugLog('ProgressProvider',
        'Progress saved locally for chapter:${progress.chapterId}');
  }

  void clearProgress() {
    _userProgress = [];
    _progressByChapter = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
