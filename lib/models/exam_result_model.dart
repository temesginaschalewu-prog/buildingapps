import 'dart:ui';

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
    // Parse score correctly - handle both string and number
    double parsedScore = 0.0;
    if (json['score'] != null) {
      if (json['score'] is double) {
        parsedScore = json['score'];
      } else if (json['score'] is int) {
        parsedScore = (json['score'] as int).toDouble();
      } else if (json['score'] is String) {
        parsedScore = double.tryParse(json['score']) ?? 0.0;
      }
    }

    return ExamResult(
      id: json['id'] ?? 0,
      examId: json['exam_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      score: parsedScore,
      totalQuestions: json['total_questions'] ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      timeTaken: json['time_taken'] ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at']).toLocal()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at']).toLocal()
          : null,
      status: json['status'] ?? 'unknown',
      examCode: json['exam_code'],
      answerDetails: json['answer_details'],
      title: json['title'] ?? 'Unknown Exam',
      examType: json['exam_type'] ?? 'unknown',
      duration: json['duration'] ?? 0,
      passingScore: json['passing_score'] ?? 50,
      courseName: json['course_name'] ?? 'Unknown Course',
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
    if (totalQuestions == 0) return 0;
    return (correctAnswers / totalQuestions) * 100;
  }

  String get formattedTime {
    final minutes = (timeTaken / 60).floor();
    final seconds = timeTaken % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String get formattedScore {
    if (score == 0 && totalQuestions > 0 && correctAnswers > 0) {
      // Calculate from correct answers if score is 0 but we have data
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

  Color get statusColor {
    if (isCompleted) {
      return passed ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    }
    if (isInProgress) return const Color(0xFF007AFF);
    return const Color(0xFF8E8E93);
  }
}
