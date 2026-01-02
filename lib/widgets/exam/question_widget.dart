import 'package:flutter/material.dart';
import '../../models/exam_question_model.dart';

class QuestionWidget extends StatefulWidget {
  final ExamQuestion question;
  final String? selectedAnswer;
  final Function(String?) onAnswerSelected;

  const QuestionWidget({
    super.key,
    required this.question,
    this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.selectedAnswer;
  }

  @override
  void didUpdateWidget(covariant QuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _selectedOption = widget.selectedAnswer;
    }
  }

  void _selectOption(String option) {
    setState(() => _selectedOption = option);
    widget.onAnswerSelected(option);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question Text
        Text(
          'Question ${widget.question.displayOrder}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.question.questionText,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // Options
        Column(
          children: widget.question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final optionLetter =
                String.fromCharCode(65 + index); // A, B, C, etc.
            final isSelected = _selectedOption == optionLetter;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : null,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _selectOption(optionLetter),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            optionLetter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Question Info
        const SizedBox(height: 24),
        Row(
          children: [
            Chip(
              label: Text(
                'Marks: ${widget.question.marks}',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.blue.withOpacity(0.1),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                widget.question.difficulty.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _getDifficultyColor(widget.question.difficulty),
            ),
          ],
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.withOpacity(0.1);
      case 'medium':
        return Colors.orange.withOpacity(0.1);
      case 'hard':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }
}
