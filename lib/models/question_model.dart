import 'package:flutter/foundation.dart';

class Question {
  final int id;
  final String questionType;
  final int? chapterId;
  final int? examId;
  final String questionText;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? optionE;
  final String? optionF;
  final String correctOption;
  final String? explanation;
  final String difficulty;
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

  int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is double) {
      return value.toInt();
    }
    return defaultValue;
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      questionType: json['question_type']?.toString() ?? 'practice',
      chapterId: json['chapter_id'] != null
          ? (json['chapter_id'] is int
              ? json['chapter_id']
              : int.tryParse(json['chapter_id'].toString()) ?? 0)
          : null,
      examId: json['exam_id'] != null
          ? (json['exam_id'] is int
              ? json['exam_id']
              : int.tryParse(json['exam_id'].toString()) ?? 0)
          : null,
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
      hasAnswer: (json['has_answer'] is bool)
          ? json['has_answer']
          : (json['has_answer'] is int)
              ? json['has_answer'] == 1
              : (json['has_answer'] is String)
                  ? json['has_answer'].toLowerCase() == 'true' ||
                      json['has_answer'] == '1'
                  : false,
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
    if (optionA != null && optionA!.isNotEmpty) options.add(optionA!);
    if (optionB != null && optionB!.isNotEmpty) options.add(optionB!);
    if (optionC != null && optionC!.isNotEmpty) options.add(optionC!);
    if (optionD != null && optionD!.isNotEmpty) options.add(optionD!);
    if (optionE != null && optionE!.isNotEmpty) options.add(optionE!);
    if (optionF != null && optionF!.isNotEmpty) options.add(optionF!);
    return options;
  }

  bool get isMultipleChoice => options.length > 2;
  bool get isPracticeQuestion => questionType == 'practice';
  bool get isExamQuestion => questionType == 'exam';
  bool get recordsProgress => !hasAnswer;
}
