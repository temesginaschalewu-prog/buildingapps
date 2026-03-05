import '../utils/parsers.dart';

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
      id: Parsers.parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      examType: json['exam_type']?.toString() ?? '',
      startDate: Parsers.parseDate(json['start_date']) ?? DateTime.now(),
      endDate: Parsers.parseDate(json['end_date']) ?? DateTime.now(),
      duration: Parsers.parseInt(json['duration']),
      userTimeLimit: json['user_time_limit'] != null
          ? Parsers.parseInt(json['user_time_limit'])
          : null,
      passingScore: Parsers.parseInt(json['passing_score'], 50),
      maxAttempts: Parsers.parseInt(json['max_attempts'], 1),
      autoSubmit: Parsers.parseBool(json['auto_submit'], true),
      showResultsImmediately:
          Parsers.parseBool(json['show_results_immediately']),
      courseName: json['course_name']?.toString() ?? '',
      courseId: Parsers.parseInt(json['course_id']),
      categoryId: Parsers.parseInt(json['category_id']),
      categoryName: json['category_name']?.toString() ?? '',
      categoryStatus: json['category_status']?.toString() ?? '',
      attemptsTaken: Parsers.parseInt(json['attempts_taken']),
      lastAttemptStatus: json['last_attempt_status']?.toString(),
      questionCount: Parsers.parseInt(json['question_count']),
      status: json['status']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? '',
      canTakeExam: Parsers.parseBool(json['canTakeExam']),
      requiresPayment: Parsers.parseBool(json['requiresPayment']),
      hasAccess: Parsers.parseBool(json['hasAccess']),
      actualDuration:
          Parsers.parseInt(json['actual_duration'] ?? json['duration']),
      timingType: json['timing_type']?.toString() ?? 'exam_wide',
      hasPendingPayment: Parsers.parseBool(json['hasPendingPayment']),
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

  bool get hasUserTimeLimit => userTimeLimit != null && userTimeLimit! > 0;
  bool get isUpcoming => DateTime.now().isBefore(startDate);
  bool get isEnded => DateTime.now().isAfter(endDate);
  bool get isInProgress =>
      !isUpcoming && !isEnded && !canTakeExam && attemptsTaken > 0;
  bool get maxAttemptsReached => attemptsTaken >= maxAttempts;
  bool get isBlockedByPendingPayment =>
      requiresPayment && !hasAccess && hasPendingPayment;
}
