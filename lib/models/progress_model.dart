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
      chapterId: json['chapter_id'],
      completed: json['completed'] ?? false,
      videoProgress: json['video_progress'] ?? 0,
      notesViewed: json['notes_viewed'] ?? false,
      questionsAttempted: json['questions_attempted'] ?? 0,
      questionsCorrect: json['questions_correct'] ?? 0,
      lastAccessed: json['last_accessed'] != null
          ? DateTime.parse(json['last_accessed'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapter_id': chapterId,
      'completed': completed,
      'video_progress': videoProgress,
      'notes_viewed': notesViewed,
      'questions_attempted': questionsAttempted,
      'questions_correct': questionsCorrect,
      'last_accessed': lastAccessed?.toIso8601String(),
    };
  }

  double get completionPercentage {
    final totalItems = 3; // Videos, Notes, Questions
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
}
