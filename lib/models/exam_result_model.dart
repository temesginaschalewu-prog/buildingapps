import '../utils/parsers.dart';

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
      id: Parsers.parseInt(json['id']),
      examId: Parsers.parseInt(json['exam_id']),
      userId: Parsers.parseInt(json['user_id']),
      score: Parsers.parseDouble(json['score']),
      totalQuestions: Parsers.parseInt(json['total_questions']),
      correctAnswers: Parsers.parseInt(json['correct_answers']),
      timeTaken: Parsers.parseInt(json['time_taken']),
      startedAt: Parsers.parseDate(json['started_at']) ?? DateTime.now(),
      completedAt: Parsers.parseDate(json['completed_at']),
      status: json['status']?.toString() ?? 'unknown',
      examCode: json['exam_code']?.toString(),
      answerDetails: json['answer_details'],
      title: json['title']?.toString() ?? 'Unknown Exam',
      examType: json['exam_type']?.toString() ?? 'unknown',
      duration: Parsers.parseInt(json['duration']),
      passingScore: Parsers.parseInt(json['passing_score'], 50),
      courseName: json['course_name']?.toString() ?? 'Unknown Course',
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
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
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
  bool get passed => totalQuestions > 0 && score >= passingScore;

  double get percentage =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;

  String get formattedTime {
    final minutes = (timeTaken / 60).floor();
    final seconds = timeTaken % 60;
    return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
  }

  String get formattedScore {
    if (score == 0 && totalQuestions > 0 && correctAnswers > 0) {
      final calculatedScore = (correctAnswers / totalQuestions) * 100;
      return '${calculatedScore.toStringAsFixed(1)}%';
    }
    return '${score.toStringAsFixed(1)}%';
  }

  String get statusDisplay {
    if (isCompleted) return passed ? 'Passed' : 'Failed';
    if (isInProgress) return 'In Progress';
    return status;
  }
}
