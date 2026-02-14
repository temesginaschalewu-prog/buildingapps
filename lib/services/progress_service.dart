import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import '../services/device_service.dart';

class ProgressService {
  final DeviceService deviceService;

  ProgressService({required this.deviceService});

  Future<void> saveChapterProgressLocally(UserProgress progress) async {
    final key = 'progress_chapter_${progress.chapterId}';
    await deviceService.saveCacheItem(key, progress.toJson(),
        ttl: Duration(days: 30), isUserSpecific: true);
    debugPrint('📊 Saved local progress for chapter ${progress.chapterId}');
  }

  Future<UserProgress?> getChapterProgressLocally(int chapterId) async {
    final key = 'progress_chapter_$chapterId';
    final progressJson = await deviceService
        .getCacheItem<Map<String, dynamic>>(key, isUserSpecific: true);

    if (progressJson != null) {
      try {
        return UserProgress.fromJson(progressJson);
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
    // This now uses DeviceService cache instead of SharedPreferences directly
    // We'll get all progress items from cache
    debugPrint('🔄 Getting overall progress stats from cache');

    // Note: Since we're using DeviceService cache, we can't directly list all keys
    // We'll track progress keys separately or use a different approach

    // For now, return empty stats - the actual progress data is managed by ProgressProvider
    return {
      'total_chapters': 0,
      'average_completion': 0,
      'questions_attempted': 0,
      'questions_correct': 0,
      'accuracy_percentage': 0,
      'last_updated': DateTime.now(),
    };
  }

  Future<void> clearLocalProgress() async {
    // Clear all progress cache
    await deviceService.clearCacheByPrefix('progress_');
    debugPrint('🗑️ Cleared all local progress data');
  }

  Future<void> syncProgressWithBackend() async {
    debugPrint('🔄 Syncing progress with backend...');
    final stats = await getOverallProgressStats();
    debugPrint('📊 Progress stats: $stats');
  }

  // Clear all progress data (for logout)
  Future<void> clearUserProgress() async {
    await clearLocalProgress();
    debugPrint('✅ Cleared user progress data');
  }
}
