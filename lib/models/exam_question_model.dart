class ExamQuestion {
  final int id;
  final int examId;
  final int questionId;
  final int displayOrder;
  final int marks;
  final String questionText;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? optionE;
  final String? optionF;
  final String difficulty;
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
      id: json['id'],
      examId: json['exam_id'],
      questionId: json['question_id'],
      displayOrder: json['display_order'] ?? 0,
      marks: json['marks'] ?? 1,
      questionText: json['question_text'],
      optionA: json['option_a'],
      optionB: json['option_b'],
      optionC: json['option_c'],
      optionD: json['option_d'],
      optionE: json['option_e'],
      optionF: json['option_f'],
      difficulty: json['difficulty'] ?? 'medium',
      hasAnswer: json['has_answer'] ?? false,
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
    if (optionA != null && optionA!.isNotEmpty) options.add(optionA!);
    if (optionB != null && optionB!.isNotEmpty) options.add(optionB!);
    if (optionC != null && optionC!.isNotEmpty) options.add(optionC!);
    if (optionD != null && optionD!.isNotEmpty) options.add(optionD!);
    if (optionE != null && optionE!.isNotEmpty) options.add(optionE!);
    if (optionF != null && optionF!.isNotEmpty) options.add(optionF!);
    return options;
  }
}
