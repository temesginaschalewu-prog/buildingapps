class Exam {
  final int id;
  final String title;
  final String examType; // 'weekly', 'mid', 'final'
  final DateTime startDate;
  final DateTime endDate;
  final int duration; // in minutes
  final int passingScore;
  final int maxAttempts;
  final String courseName;
  final int courseId;
  final String categoryName;
  final int attemptsTaken;
  final String? lastAttemptStatus;
  final String
      status; // 'available', 'max_attempts_reached', 'in_progress', 'upcoming', 'ended'
  final String message;

  Exam({
    required this.id,
    required this.title,
    required this.examType,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.passingScore,
    required this.maxAttempts,
    required this.courseName,
    required this.courseId,
    required this.categoryName,
    required this.attemptsTaken,
    this.lastAttemptStatus,
    required this.status,
    required this.message,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      examType: json['exam_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      duration: json['duration'],
      passingScore: json['passing_score'],
      maxAttempts: json['max_attempts'],
      courseName: json['course_name'],
      courseId: json['course_id'],
      categoryName: json['category_name'],
      attemptsTaken: json['attempts_taken'] ?? 0,
      lastAttemptStatus: json['last_attempt_status'],
      status: json['status'] ?? 'available',
      message: json['message'] ?? 'Available for attempt',
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
      'passing_score': passingScore,
      'max_attempts': maxAttempts,
      'course_name': courseName,
      'course_id': courseId,
      'category_name': categoryName,
      'attempts_taken': attemptsTaken,
      'last_attempt_status': lastAttemptStatus,
      'status': status,
      'message': message,
    };
  }

  bool get isAvailable => status == 'available';
  bool get isUpcoming => status == 'upcoming';
  bool get isEnded => status == 'ended';
  bool get isInProgress => status == 'in_progress';
  bool get maxAttemptsReached => status == 'max_attempts_reached';

  bool get canTakeExam => isAvailable && !maxAttemptsReached && !isInProgress;

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
