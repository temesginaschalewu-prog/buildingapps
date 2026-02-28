import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_service.dart';

class ProgressService {
  final DeviceService deviceService;
  String? _currentUserId;

  ProgressService({required this.deviceService});

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('current_user_id');
  }

  String _getUserSpecificKey(String key) {
    if (_currentUserId == null) return key;
    return '${key}_$_currentUserId';
  }

  Future<void> saveChapterProgressLocally(UserProgress progress) async {
    await _getCurrentUserId();
    final key = _getUserSpecificKey('progress_chapter_${progress.chapterId}');
    await deviceService.saveCacheItem(key, progress.toJson(),
        ttl: Duration(days: 30), isUserSpecific: true);
  }

  Future<UserProgress?> getChapterProgressLocally(int chapterId) async {
    await _getCurrentUserId();
    final key = _getUserSpecificKey('progress_chapter_$chapterId');
    final progressJson = await deviceService
        .getCacheItem<Map<String, dynamic>>(key, isUserSpecific: true);

    if (progressJson != null) {
      try {
        return UserProgress.fromJson(progressJson);
      } catch (e) {}
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
    await _getCurrentUserId();
    await deviceService.clearCacheByPrefix(_getUserSpecificKey('progress_'));
  }

  Future<void> syncProgressWithBackend() async {}

  Future<void> clearUserProgress() async {
    await clearLocalProgress();
  }
}
