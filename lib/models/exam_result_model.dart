import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'exam_result_model.g.dart'; // NEW

@HiveType(typeId: 8) // NEW
class ExamResult {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int examId;

  @HiveField(2)
  final int userId;

  @HiveField(3)
  final double score;

  @HiveField(4)
  final int totalQuestions;

  @HiveField(5)
  final int correctAnswers;

  @HiveField(6)
  final int timeTaken;

  @HiveField(7)
  final DateTime startedAt;

  @HiveField(8)
  final DateTime? completedAt;

  @HiveField(9)
  final String status;

  @HiveField(10)
  final String? examCode;

  @HiveField(11)
  final List<dynamic>? answerDetails;

  @HiveField(12)
  final String title;

  @HiveField(13)
  final String examType;

  @HiveField(14)
  final int duration;

  @HiveField(15)
  final int passingScore;

  @HiveField(16)
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
      title: json['title']?.toString() ??
          json['exam_title']?.toString() ??
          'Unknown Exam',
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

  double get percentage {
    if (score > 0) return score;
    if (answerDetails != null && answerDetails!.isNotEmpty) {
      double earned = 0;
      double possible = 0;
      for (final item in answerDetails!) {
        if (item is Map) {
          earned += Parsers.parseDouble(item['marks_earned']);
          possible += Parsers.parseDouble(item['marks_possible'], 1);
        }
      }
      if (possible > 0) {
        return (earned / possible) * 100;
      }
    }
    return totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
  }

  String get formattedTime {
    final minutes = (timeTaken / 60).floor();
    final seconds = timeTaken % 60;
    return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
  }

  String get formattedScore {
    return '${percentage.toStringAsFixed(1)}%';
  }

  String get statusDisplay {
    if (isCompleted) return passed ? 'Passed' : 'Failed';
    if (isInProgress) return 'In Progress';
    return status;
  }
}
