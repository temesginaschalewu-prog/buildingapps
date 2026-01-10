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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      chapterId: json['chapter_id'] is int
          ? json['chapter_id']
          : int.tryParse(json['chapter_id']?.toString() ?? '0') ?? 0,
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
      hasAnswer: json['has_answer'] == true,
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
