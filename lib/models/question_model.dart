import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'question_model.g.dart'; // NEW

@HiveType(typeId: 6) // NEW
class Question {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String questionType;

  @HiveField(2)
  final int? chapterId;

  @HiveField(3)
  final int? examId;

  @HiveField(4)
  final String questionText;

  @HiveField(5)
  final String? optionA;

  @HiveField(6)
  final String? optionB;

  @HiveField(7)
  final String? optionC;

  @HiveField(8)
  final String? optionD;

  @HiveField(9)
  final String? optionE;

  @HiveField(10)
  final String? optionF;

  @HiveField(11)
  final String correctOption;

  @HiveField(12)
  final String? explanation;

  @HiveField(13)
  final String difficulty;

  @HiveField(14)
  final bool hasAnswer;

  Question({
    required this.id,
    this.questionType = 'practice',
    this.chapterId,
    this.examId,
    required this.questionText,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.optionE,
    this.optionF,
    required this.correctOption,
    this.explanation,
    required this.difficulty,
    required this.hasAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: Parsers.parseInt(json['id']),
      questionType: json['question_type']?.toString() ?? 'practice',
      chapterId: json['chapter_id'] != null
          ? Parsers.parseInt(json['chapter_id'])
          : null,
      examId:
          json['exam_id'] != null ? Parsers.parseInt(json['exam_id']) : null,
      questionText: json['question_text']?.toString() ?? '',
      optionA: json['option_a']?.toString(),
      optionB: json['option_b']?.toString(),
      optionC: json['option_c']?.toString(),
      optionD: json['option_d']?.toString(),
      optionE: json['option_e']?.toString(),
      optionF: json['option_f']?.toString(),
      correctOption: json['correct_option']?.toString() ?? 'A',
      explanation: json['explanation']?.toString(),
      difficulty: json['difficulty']?.toString() ?? 'medium',
      hasAnswer: Parsers.parseBool(json['has_answer']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_type': questionType,
      'chapter_id': chapterId,
      'exam_id': examId,
      'question_text': questionText,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'option_e': optionE,
      'option_f': optionF,
      'correct_option': correctOption,
      'explanation': explanation,
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

  bool get isMultipleChoice => options.length > 2;
  bool get isPracticeQuestion => questionType == 'practice';
  bool get isExamQuestion => questionType == 'exam';
  bool get recordsProgress => !hasAnswer;
}
