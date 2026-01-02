class Question {
  final int id;
  final int chapterId;
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
    required this.chapterId,
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
      id: json['id'],
      chapterId: json['chapter_id'],
      questionText: json['question_text'],
      optionA: json['option_a'],
      optionB: json['option_b'],
      optionC: json['option_c'],
      optionD: json['option_d'],
      optionE: json['option_e'],
      optionF: json['option_f'],
      correctOption: json['correct_option'],
      explanation: json['explanation'],
      difficulty: json['difficulty'] ?? 'medium',
      hasAnswer: json['has_answer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapter_id': chapterId,
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

  bool get recordsProgress => !hasAnswer;
}
