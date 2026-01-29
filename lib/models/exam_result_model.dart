class ExamResult {
  final int id;
  final int examId;
  final int userId;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final int timeTaken;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;
  final String? examCode;
  final List<dynamic>? answerDetails;
  final String title;
  final String examType;
  final int duration;
  final int passingScore;
  final String courseName;

  ExamResult({
    required this.id,
    required this.examId,
    required this.userId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeTaken,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.examCode,
    this.answerDetails,
    required this.title,
    required this.examType,
    required this.duration,
    required this.passingScore,
    required this.courseName,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'],
      examId: json['exam_id'],
      userId: json['user_id'],
      score: double.parse(json['score'].toString()),
      totalQuestions: json['total_questions'],
      correctAnswers: json['correct_answers'],
      timeTaken: json['time_taken'],
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      status: json['status'],
      examCode: json['exam_code'],
      answerDetails: json['answer_details'],
      title: json['title'],
      examType: json['exam_type'],
      duration: json['duration'],
      passingScore: json['passing_score'],
      courseName: json['course_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'user_id': userId,
      'score': score,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'time_taken': timeTaken,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status,
      'exam_code': examCode,
      'answer_details': answerDetails,
      'title': title,
      'exam_type': examType,
      'duration': duration,
      'passing_score': passingScore,
      'course_name': courseName,
    };
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isAbandoned => status == 'abandoned';

  bool get passed => score >= passingScore;

  double get percentage => (correctAnswers / totalQuestions) * 100;

  String get formattedTime {
    final minutes = (timeTaken / 60).floor();
    final seconds = timeTaken % 60;
    return '${minutes}m ${seconds}s';
  }

  String get formattedScore => '${score.toStringAsFixed(2)}%';
}
