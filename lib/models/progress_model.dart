import '../utils/parsers.dart';

class UserProgress {
  final int chapterId;
  final bool completed;
  final int videoProgress;
  final bool notesViewed;
  final int questionsAttempted;
  final int questionsCorrect;
  final DateTime? lastAccessed;

  UserProgress({
    required this.chapterId,
    required this.completed,
    required this.videoProgress,
    required this.notesViewed,
    required this.questionsAttempted,
    required this.questionsCorrect,
    this.lastAccessed,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      chapterId: Parsers.parseInt(json['chapter_id']),
      completed: Parsers.parseBool(json['completed']),
      videoProgress: Parsers.parseInt(json['video_progress']),
      notesViewed: Parsers.parseBool(json['notes_viewed']),
      questionsAttempted: Parsers.parseInt(json['questions_attempted']),
      questionsCorrect: Parsers.parseInt(json['questions_correct']),
      lastAccessed: Parsers.parseDate(json['last_accessed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapter_id': chapterId,
      'completed': completed ? 1 : 0,
      'video_progress': videoProgress,
      'notes_viewed': notesViewed ? 1 : 0,
      'questions_attempted': questionsAttempted,
      'questions_correct': questionsCorrect,
      'last_accessed': lastAccessed?.toIso8601String(),
    };
  }

  double get completionPercentage {
    if (completed) return 100.0;

    const totalItems = 3;
    var completedItems = 0;

    if (videoProgress >= 90) completedItems++;
    if (notesViewed) completedItems++;
    if (questionsAttempted > 0) completedItems++;

    return (completedItems / totalItems) * 100;
  }

  double get accuracyPercentage {
    if (questionsAttempted == 0) return 0;
    return (questionsCorrect / questionsAttempted) * 100;
  }

  String get timeAgo {
    if (lastAccessed == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastAccessed!);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
