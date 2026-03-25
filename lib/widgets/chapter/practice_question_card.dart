// lib/widgets/chapter/practice_question_card.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';

/// PRODUCTION-READY PRACTICE QUESTION CARD - Based on actual Question model
class PracticeQuestionCard extends StatelessWidget {
  final Question question;
  final int index;
  final Map<int, String?> selectedAnswers;
  final Map<int, bool> showExplanation;
  final Map<int, bool> isQuestionCorrect;
  final Map<int, bool> questionAnswered;
  final Function(int, String) onSelectAnswer;
  final Function(int, String) onCheckAnswer;

  const PracticeQuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.selectedAnswers,
    required this.showExplanation,
    required this.isQuestionCorrect,
    required this.questionAnswered,
    required this.onSelectAnswer,
    required this.onCheckAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final questionId = question.id;
    final selected = selectedAnswers[questionId];
    final isAnswered = questionAnswered[questionId] ?? false;
    final isCorrect = isQuestionCorrect[questionId] ?? false;
    final showExp = showExplanation[questionId] ?? false;

    final List<Map<String, dynamic>> options = [
      if (question.optionA != null && question.optionA!.isNotEmpty)
        {'letter': 'A', 'text': question.optionA},
      if (question.optionB != null && question.optionB!.isNotEmpty)
        {'letter': 'B', 'text': question.optionB},
      if (question.optionC != null && question.optionC!.isNotEmpty)
        {'letter': 'C', 'text': question.optionC},
      if (question.optionD != null && question.optionD!.isNotEmpty)
        {'letter': 'D', 'text': question.optionD},
      if (question.optionE != null && question.optionE!.isNotEmpty)
        {'letter': 'E', 'text': question.optionE},
      if (question.optionF != null && question.optionF!.isNotEmpty)
        {'letter': 'F', 'text': question.optionF},
    ];

    return AppCard.solid(
      child: Container(
        margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeL(context) * 1.1,
                    height: ResponsiveValues.iconSizeL(context) * 1.1,
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? (isCorrect
                              ? AppColors.telegramGreen
                              : AppColors.telegramRed)
                          : AppColors.telegramBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusSmall(context)),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppTextStyles.titleSmall(context).copyWith(
                          color: isAnswered
                              ? Colors.white
                              : AppColors.telegramBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${index + 1}',
                          style: AppTextStyles.titleSmall(context)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          margin: EdgeInsets.only(
                              top: ResponsiveValues.spacingXXS(context)),
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingS(context),
                            vertical: ResponsiveValues.spacingXXS(context),
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(question.difficulty)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusSmall(context)),
                          ),
                      child: Text(
                            question.difficulty.toUpperCase(),
                            style:
                                AppTextStyles.statusBadge(context).copyWith(
                              color: _getDifficultyColor(question.difficulty),
                              fontSize:
                                  ResponsiveValues.fontStatusBadge(context) *
                                      0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Question type indicator
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingS(context),
                      vertical: ResponsiveValues.spacingXXS(context),
                    ),
                    decoration: BoxDecoration(
                      color: question.isPracticeQuestion
                          ? AppColors.telegramBlue.withValues(alpha: 0.10)
                          : AppColors.telegramPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusSmall(context)),
                    ),
                    child: Text(
                      question.isPracticeQuestion ? 'Practice' : 'Exam',
                      style: AppTextStyles.statusBadge(context).copyWith(
                        color: question.isPracticeQuestion
                            ? AppColors.telegramBlue
                            : AppColors.telegramPurple,
                        fontSize:
                            ResponsiveValues.fontStatusBadge(context) * 0.9,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              // Question text
              Text(
                question.questionText,
                      style: AppTextStyles.bodyLarge(context)
                    .copyWith(fontWeight: FontWeight.w500, height: 1.55),
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              // Options
              ...options.map((option) => _buildOption(
                    context,
                    option['letter'],
                    option['text'],
                    selected == option['letter'],
                    question.correctOption == option['letter'],
                    isAnswered,
                    isCorrect,
                  )),
              // Check button
              if (!isAnswered)
                Padding(
                  padding:
                      EdgeInsets.only(top: ResponsiveValues.spacingL(context)),
                  child: AppButton.primary(
                    label: 'Check Answer',
                    onPressed: selected != null
                        ? () => onCheckAnswer(
                            question.id, selected) // ✅ FIXED: Use question.id
                        : null,
                    expanded: true,
                  ),
                ),
              // Explanation
              if (showExp && question.explanation != null)
                Padding(
                  padding:
                      EdgeInsets.only(top: ResponsiveValues.spacingL(context)),
                  child: AppCard.solid(
                    child: Container(
                      width: double.infinity,
                      padding: ResponsiveValues.cardPadding(context),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.telegramGreen.withValues(alpha: 0.06)
                            : AppColors.telegramRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.info_rounded,
                                size: ResponsiveValues.iconSizeS(context),
                                color: isCorrect
                                    ? AppColors.telegramGreen
                                    : AppColors.telegramRed,
                              ),
                              SizedBox(
                                  width: ResponsiveValues.spacingS(context)),
                              Text(
                                isCorrect ? 'Correct!' : 'Explanation',
                                style:
                                    AppTextStyles.titleSmall(context).copyWith(
                                  color: isCorrect
                                      ? AppColors.telegramGreen
                                      : AppColors.telegramRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ResponsiveValues.spacingS(context)),
                          Text(
                            question.explanation!,
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String letter,
    String text,
    bool isSelected,
    bool isActualCorrect,
    bool isAnswered,
    bool isCorrect,
  ) {
    Color borderColor = AppColors.getDivider(context).withValues(alpha: 0.9);
    Color bgColor = AppColors.getSurface(context).withValues(alpha: 0.45);
    Color textColor = AppColors.getTextPrimary(context);
    IconData? icon;

    if (isAnswered) {
      if (isActualCorrect) {
        borderColor = AppColors.telegramGreen;
        bgColor = AppColors.telegramGreen.withValues(alpha: 0.08);
        icon = Icons.check_circle_rounded;
        textColor = AppColors.telegramGreen;
      } else if (isSelected) {
        if (isCorrect) {
          borderColor = AppColors.telegramGreen;
          bgColor = AppColors.telegramGreen.withValues(alpha: 0.08);
          icon = Icons.check_circle_rounded;
          textColor = AppColors.telegramGreen;
        } else {
          borderColor = AppColors.telegramRed;
          bgColor = AppColors.telegramRed.withValues(alpha: 0.08);
          icon = Icons.cancel_rounded;
          textColor = AppColors.telegramRed;
        }
      }
    } else if (isSelected) {
      borderColor = AppColors.telegramBlue;
      bgColor = AppColors.telegramBlue.withValues(alpha: 0.08);
      textColor = AppColors.telegramBlue;
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingS(context)),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        color: bgColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAnswered
              ? null
              : () => onSelectAnswer(
                  question.id, letter), // ✅ FIXED: Use question.id
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
            child: Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? borderColor.withValues(alpha: 0.1)
                        : AppColors.getSurface(context).withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? borderColor : textColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.bodyLarge(context)
                        .copyWith(color: textColor),
                  ),
                ),
                if (icon != null)
                  Icon(icon,
                      color: borderColor,
                      size: ResponsiveValues.iconSizeS(context)),
              ],
            ),
          ),
        ),
      ),
    );
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
}
