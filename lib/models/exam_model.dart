class Exam {
  final int id;
  final String title;
  final String examType;
  final DateTime startDate;
  final DateTime endDate;
  final int duration;
  final int? userTimeLimit;
  final int passingScore;
  final int maxAttempts;
  final bool autoSubmit;
  final bool showResultsImmediately;
  final String courseName;
  final int courseId;
  final int categoryId;
  final String categoryName;
  final int attemptsTaken;
  final String? lastAttemptStatus;
  final String status;
  final String message;
  final bool canTakeExam;
  final bool requiresPayment;
  final int actualDuration;
  final String timingType;

  Exam({
    required this.id,
    required this.title,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.duration,
    this.userTimeLimit,
    required this.passingScore,
    required this.maxAttempts,
    this.autoSubmit = true,
    this.showResultsImmediately = false,
    required this.courseName,
    required this.courseId,
    required this.categoryId,
    required this.categoryName,
    required this.attemptsTaken,
    this.lastAttemptStatus,
    required this.status,
    required this.message,
    required this.canTakeExam,
    this.requiresPayment = false,
    required this.actualDuration,
    this.timingType = 'exam_wide',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      examType: json['exam_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      duration: json['duration'],
      userTimeLimit: json['user_time_limit'],
      passingScore: json['passing_score'],
      maxAttempts: json['max_attempts'],
      autoSubmit: json['auto_submit'] ?? true,
      showResultsImmediately: json['show_results_immediately'] ?? false,
      courseName: json['course_name'],
      courseId: json['course_id'],
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'],
      attemptsTaken: json['attempts_taken'] ?? 0,
      lastAttemptStatus: json['last_attempt_status'],
      status: json['status'] ?? 'available',
      message: json['message'] ?? 'Available for attempt',
      canTakeExam: json['canTakeExam'] ?? false,
      requiresPayment: json['requiresPayment'] ?? false,
      actualDuration: json['actual_duration'] ?? json['duration'],
      timingType: json['timing_type'] ?? 'exam_wide',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'exam_type': examType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'duration': duration,
      'user_time_limit': userTimeLimit,
      'passing_score': passingScore,
      'max_attempts': maxAttempts,
      'auto_submit': autoSubmit,
      'show_results_immediately': showResultsImmediately,
      'course_name': courseName,
      'course_id': courseId,
      'category_id': categoryId,
      'category_name': categoryName,
      'attempts_taken': attemptsTaken,
      'last_attempt_status': lastAttemptStatus,
      'status': status,
      'message': message,
      'canTakeExam': canTakeExam,
      'requiresPayment': requiresPayment,
      'actual_duration': actualDuration,
      'timing_type': timingType,
    };
  }

  bool get isAvailable => status == 'available';
  bool get isUpcoming => status == 'upcoming';
  bool get isEnded => status == 'ended';
  bool get isInProgress => status == 'in_progress';
  bool get maxAttemptsReached => status == 'max_attempts_reached';
  bool get hasUserTimeLimit => userTimeLimit != null;

  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isBefore(startDate)) {
      return startDate.difference(now);
    } else if (now.isBefore(endDate)) {
      return endDate.difference(now);
    }
    return Duration.zero;
  }
}
