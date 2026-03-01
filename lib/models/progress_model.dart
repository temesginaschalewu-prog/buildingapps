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
      chapterId: json['chapter_id'] ?? 0,
      completed: json['completed'] == 1 || json['completed'] == true,
      videoProgress: json['video_progress'] ?? 0,
      notesViewed: json['notes_viewed'] == 1 || json['notes_viewed'] == true,
      questionsAttempted: json['questions_attempted'] ?? 0,
      questionsCorrect: json['questions_correct'] ?? 0,
      lastAccessed: json['last_accessed'] != null
          ? DateTime.parse(json['last_accessed']).toLocal()
          : null,
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
    // Chapter is complete when: video >= 90% + notes viewed + questions attempted
    if (completed) return 100.0;

    const totalItems = 3; // Videos, Notes, Questions
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

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
