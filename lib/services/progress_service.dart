import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class ProgressService {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveChapterProgressLocally(UserProgress progress) async {
    final key = 'progress_chapter_${progress.chapterId}';
    await _prefs.setString(key, json.encode(progress.toJson()));
    debugPrint('📊 Saved local progress for chapter ${progress.chapterId}');
  }

  Future<UserProgress?> getChapterProgressLocally(int chapterId) async {
    final key = 'progress_chapter_$chapterId';
    final jsonStr = _prefs.getString(key);

    if (jsonStr != null) {
      try {
        return UserProgress.fromJson(json.decode(jsonStr));
      } catch (e) {
        debugPrint('❌ Error parsing progress: $e');
      }
    }
    return null;
  }

  Future<void> updateVideoProgress(int chapterId, int progress) async {
    final existing = await getChapterProgressLocally(chapterId);
    final updated = UserProgress(
      chapterId: chapterId,
      completed: existing?.completed ?? (progress >= 90),
      videoProgress: progress,
      notesViewed: existing?.notesViewed ?? false,
      questionsAttempted: existing?.questionsAttempted ?? 0,
      questionsCorrect: existing?.questionsCorrect ?? 0,
      lastAccessed: DateTime.now(),
    );
    await saveChapterProgressLocally(updated);
  }

  Future<void> markNotesViewed(int chapterId) async {
    final existing = await getChapterProgressLocally(chapterId);
    final updated = UserProgress(
      chapterId: chapterId,
      completed: existing?.completed ?? false,
      videoProgress: existing?.videoProgress ?? 0,
      notesViewed: true,
      questionsAttempted: existing?.questionsAttempted ?? 0,
      questionsCorrect: existing?.questionsCorrect ?? 0,
      lastAccessed: DateTime.now(),
    );
    await saveChapterProgressLocally(updated);
  }

  Future<void> updateQuestionResult(int chapterId, bool isCorrect) async {
    final existing = await getChapterProgressLocally(chapterId);
    final updated = UserProgress(
      chapterId: chapterId,
      completed: existing?.completed ?? false,
      videoProgress: existing?.videoProgress ?? 0,
      notesViewed: existing?.notesViewed ?? false,
      questionsAttempted: (existing?.questionsAttempted ?? 0) + 1,
      questionsCorrect: (existing?.questionsCorrect ?? 0) + (isCorrect ? 1 : 0),
      lastAccessed: DateTime.now(),
    );
    await saveChapterProgressLocally(updated);
  }

  Future<void> markChapterCompleted(int chapterId) async {
    final existing = await getChapterProgressLocally(chapterId);
    final updated = UserProgress(
      chapterId: chapterId,
      completed: true,
      videoProgress: existing?.videoProgress ?? 100,
      notesViewed: existing?.notesViewed ?? true,
      questionsAttempted: existing?.questionsAttempted ?? 1,
      questionsCorrect: existing?.questionsCorrect ?? 1,
      lastAccessed: DateTime.now(),
    );
    await saveChapterProgressLocally(updated);
  }

  Future<double> getCourseProgressPercentage(List<int> chapterIds) async {
    if (chapterIds.isEmpty) return 0;

    double totalProgress = 0;
    for (final chapterId in chapterIds) {
      final progress = await getChapterProgressLocally(chapterId);
      totalProgress += progress?.completionPercentage ?? 0;
    }

    return totalProgress / chapterIds.length;
  }

  Future<Map<String, dynamic>> getOverallProgressStats() async {
    final keys =
        _prefs.getKeys().where((key) => key.startsWith('progress_chapter_'));

    int totalChapters = keys.length;
    double totalCompletion = 0;
    int totalQuestionsAttempted = 0;
    int totalQuestionsCorrect = 0;

    for (final key in keys) {
      final jsonStr = _prefs.getString(key);
      if (jsonStr != null) {
        try {
          final progress = UserProgress.fromJson(json.decode(jsonStr));
          totalCompletion += progress.completionPercentage;
          totalQuestionsAttempted += progress.questionsAttempted;
          totalQuestionsCorrect += progress.questionsCorrect;
        } catch (e) {}
      }
    }

    return {
      'total_chapters': totalChapters,
      'average_completion':
          totalChapters > 0 ? totalCompletion / totalChapters : 0,
      'questions_attempted': totalQuestionsAttempted,
      'questions_correct': totalQuestionsCorrect,
      'accuracy_percentage': totalQuestionsAttempted > 0
          ? (totalQuestionsCorrect / totalQuestionsAttempted) * 100
          : 0,
      'last_updated': DateTime.now(),
    };
  }

  Future<void> clearLocalProgress() async {
    final keys =
        _prefs.getKeys().where((key) => key.startsWith('progress_chapter_'));
    for (final key in keys) {
      await _prefs.remove(key);
    }
    debugPrint('🗑️ Cleared all local progress data');
  }

  Future<void> syncProgressWithBackend() async {
    debugPrint('🔄 Syncing progress with backend...');
    final stats = await getOverallProgressStats();
    debugPrint('📊 Progress stats: $stats');
  }
}
