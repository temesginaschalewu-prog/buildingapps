import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.telegramGreen;
      case 'medium':
        return AppColors.telegramYellow;
      case 'hard':
        return AppColors.telegramRed;
      default:
        return AppColors.telegramBlue;
    }
  }

  Color _getDifficultyBackgroundColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.greenFaded;
      case 'medium':
        return AppColors.yellowFaded;
      case 'hard':
        return AppColors.redFaded;
      default:
        return AppColors.blueFaded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.question.options;
    final optionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final questionFontSize = isMobile ? 16.0 : (isTablet ? 17.0 : 18.0);
    final padding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);

    final difficultyColor = _getDifficultyColor(widget.question.difficulty);
    final difficultyBgColor =
        _getDifficultyBackgroundColor(widget.question.difficulty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with marks and difficulty
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding: EdgeInsets.all(padding / 1.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withOpacity(0.3),
                    AppColors.getCard(context).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.telegramBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Marks badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.telegramBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${widget.question.marks} mark${widget.question.marks > 1 ? 's' : ''}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Difficulty badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: difficultyBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: difficultyColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: difficultyColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: difficultyColor.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.question.difficulty.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                color: difficultyColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Question number badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.grayFaded,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.telegramGray.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Q${widget.question.displayOrder}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Question text with glass morphism
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withOpacity(0.4),
                    AppColors.getCard(context).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.telegramBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                widget.question.questionText,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: questionFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Options header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Select your answer:',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Options
        ...List.generate(options.length, (index) {
          final option = options[index];
          final optionLetter = optionLetters[index];
          final isSelected = _selectedOption == optionLetter;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOptionTile(
              context,
              optionLetter: optionLetter,
              option: option,
              isSelected: isSelected,
              onTap: () => _selectOption(optionLetter),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String optionLetter,
    required String option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isSelected
                      ? AppColors.telegramBlue.withOpacity(0.15)
                      : AppColors.getCard(context).withOpacity(0.2),
                  isSelected
                      ? AppColors.telegramBlue.withOpacity(0.05)
                      : AppColors.getCard(context).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.telegramBlue.withOpacity(0.5)
                    : AppColors.getTextSecondary(context).withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Option letter circle
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2AABEE),
                                    Color(0xFF5856D6)
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.getTextSecondary(context)
                                    .withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            optionLetter,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Option text
                      Expanded(
                        child: Text(
                          option,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.telegramBlue
                                : AppColors.getTextPrimary(context),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),

                      // Selected checkmark
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.telegramBlue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.telegramBlue,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(
          duration: 200.ms,
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }
}
