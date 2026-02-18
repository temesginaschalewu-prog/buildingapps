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
  final String categoryStatus;
  final int attemptsTaken;
  final String? lastAttemptStatus;
  final int questionCount;
  final String status;
  final String message;
  final bool canTakeExam;
  final bool requiresPayment;
  final bool hasAccess;
  final int actualDuration;
  final String timingType;
  final bool hasPendingPayment;

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
    required this.autoSubmit,
    required this.showResultsImmediately,
    required this.courseName,
    required this.courseId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryStatus,
    required this.attemptsTaken,
    this.lastAttemptStatus,
    required this.questionCount,
    required this.status,
    required this.message,
    required this.canTakeExam,
    required this.requiresPayment,
    required this.hasAccess,
    required this.actualDuration,
    required this.timingType,
    this.hasPendingPayment = false,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      examType: json['exam_type'] ?? '',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : DateTime.now(),
      duration: json['duration'] ?? 0,
      userTimeLimit: json['user_time_limit'],
      passingScore: json['passing_score'] ?? 50,
      maxAttempts: json['max_attempts'] ?? 1,
      autoSubmit: json['auto_submit'] ?? true,
      showResultsImmediately: json['show_results_immediately'] ?? false,
      courseName: json['course_name'] ?? '',
      courseId: json['course_id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      categoryStatus: json['category_status'] ?? '',
      attemptsTaken: json['attempts_taken'] ?? 0,
      lastAttemptStatus: json['last_attempt_status'],
      questionCount: json['question_count'] ?? 0,
      status: json['status'] ?? 'unknown',
      message: json['message'] ?? '',
      canTakeExam: json['canTakeExam'] ?? false,
      requiresPayment: json['requiresPayment'] ?? false,
      hasAccess: json['hasAccess'] ?? false,
      actualDuration: json['actual_duration'] ?? json['duration'] ?? 0,
      timingType: json['timing_type'] ?? 'exam_wide',
      hasPendingPayment: json['hasPendingPayment'] ?? false,
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
      'category_status': categoryStatus,
      'attempts_taken': attemptsTaken,
      'last_attempt_status': lastAttemptStatus,
      'question_count': questionCount,
      'status': status,
      'message': message,
      'canTakeExam': canTakeExam,
      'requiresPayment': requiresPayment,
      'hasAccess': hasAccess,
      'actual_duration': actualDuration,
      'timing_type': timingType,
      'hasPendingPayment': hasPendingPayment,
    };
  }

  // Add this missing getter
  bool get hasUserTimeLimit => userTimeLimit != null && userTimeLimit! > 0;

  bool get isUpcoming => DateTime.now().isBefore(startDate);
  bool get isEnded => DateTime.now().isAfter(endDate);
  bool get isInProgress =>
      !isUpcoming && !isEnded && !canTakeExam && attemptsTaken > 0;
  bool get maxAttemptsReached => attemptsTaken >= maxAttempts;

  bool get isBlockedByPendingPayment =>
      requiresPayment && !hasAccess && hasPendingPayment;
}
