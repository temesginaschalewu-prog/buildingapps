import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'exam_question_model.g.dart'; // NEW

@HiveType(typeId: 19) // NEW - Using 19 since 7-8 are taken
class ExamQuestion {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int examId;

  @HiveField(2)
  final int questionId;

  @HiveField(3)
  final int displayOrder;

  @HiveField(4)
  final int marks;

  @HiveField(5)
  final String questionText;

  @HiveField(6)
  final String? optionA;

  @HiveField(7)
  final String? optionB;

  @HiveField(8)
  final String? optionC;

  @HiveField(9)
  final String? optionD;

  @HiveField(10)
  final String? optionE;

  @HiveField(11)
  final String? optionF;

  @HiveField(12)
  final String difficulty;

  @HiveField(13)
  final bool hasAnswer;

  ExamQuestion({
    required this.id,
    required this.examId,
    required this.questionId,
    required this.displayOrder,
    required this.marks,
    required this.questionText,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.optionE,
    this.optionF,
    required this.difficulty,
    required this.hasAnswer,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: Parsers.parseInt(json['id']),
      examId: Parsers.parseInt(json['exam_id']),
      questionId: Parsers.parseInt(json['question_id']),
      displayOrder: Parsers.parseInt(json['display_order']),
      marks: Parsers.parseInt(json['marks'], 1),
      questionText: json['question_text']?.toString() ?? '',
      optionA: json['option_a']?.toString(),
      optionB: json['option_b']?.toString(),
      optionC: json['option_c']?.toString(),
      optionD: json['option_d']?.toString(),
      optionE: json['option_e']?.toString(),
      optionF: json['option_f']?.toString(),
      difficulty: (json['difficulty']?.toString() ?? 'medium').toLowerCase(),
      hasAnswer: Parsers.parseBool(json['has_answer']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'question_id': questionId,
      'display_order': displayOrder,
      'marks': marks,
      'question_text': questionText,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'option_e': optionE,
      'option_f': optionF,
      'difficulty': difficulty,
      'has_answer': hasAnswer,
    };
  }

  List<String> get options {
    final options = <String>[];
    if (optionA?.isNotEmpty ?? false) options.add(optionA!);
    if (optionB?.isNotEmpty ?? false) options.add(optionB!);
    if (optionC?.isNotEmpty ?? false) options.add(optionC!);
    if (optionD?.isNotEmpty ?? false) options.add(optionD!);
    if (optionE?.isNotEmpty ?? false) options.add(optionE!);
    if (optionF?.isNotEmpty ?? false) options.add(optionF!);
    return options;
  }

  String? get correctOption => null;
  String? get explanation => null;

  @override
  String toString() {
    return 'ExamQuestion(id: $id, examId: $examId, questionText: ${questionText.substring(0, Parsers.min(30, questionText.length))}...)';
  }
}
