import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'exam_model.g.dart'; // NEW

@HiveType(typeId: 7) // NEW
class Exam {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String examType;

  @HiveField(3)
  final DateTime startDate;

  @HiveField(4)
  final DateTime endDate;

  @HiveField(5)
  final int duration;

  @HiveField(6)
  final int? userTimeLimit;

  @HiveField(7)
  final int passingScore;

  @HiveField(8)
  final int maxAttempts;

  @HiveField(9)
  final bool autoSubmit;

  @HiveField(10)
  final bool showResultsImmediately;

  @HiveField(11)
  final String courseName;

  @HiveField(12)
  final int courseId;

  @HiveField(13)
  final int categoryId;

  @HiveField(14)
  final String categoryName;

  @HiveField(15)
  final String categoryStatus;

  @HiveField(16)
  final int attemptsTaken;

  @HiveField(17)
  final String? lastAttemptStatus;

  @HiveField(18)
  final int questionCount;

  @HiveField(19)
  final String status;

  @HiveField(20)
  final String message;

  @HiveField(21)
  final bool canTakeExam;

  @HiveField(22)
  final bool requiresPayment;

  @HiveField(23)
  final bool hasAccess;

  @HiveField(24)
  final int actualDuration;

  @HiveField(25)
  final String timingType;

  @HiveField(26)
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
