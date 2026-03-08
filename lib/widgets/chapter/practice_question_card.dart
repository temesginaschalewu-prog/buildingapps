import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/question_model.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';

class PracticeQuestionCard extends StatefulWidget {
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
  State<PracticeQuestionCard> createState() => _PracticeQuestionCardState();
}

class _PracticeQuestionCardState extends State<PracticeQuestionCard> {
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

  Widget _buildDifficultyBadge(String difficulty) {
    final color = _getDifficultyColor(difficulty);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ResponsiveValues.spacingXS(context),
            height: ResponsiveValues.spacingXS(context),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: ResponsiveValues.spacingXS(context))
              ],
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingS(context)),
          Text(
            difficulty.toUpperCase(),
            style: AppTextStyles.labelSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNumberBadge() {
    final questionId = widget.question.id;
    final isAnswered = widget.questionAnswered[questionId] == true;
    final isCorrect = widget.isQuestionCorrect[questionId] == true;

    Color backgroundColor;
    Color borderColor;
    IconData? icon;

    if (isAnswered) {
      if (isCorrect) {
        backgroundColor = AppColors.telegramGreen.withValues(alpha: 0.15);
        borderColor = AppColors.telegramGreen.withValues(alpha: 0.3);
        icon = Icons.check_circle_rounded;
      } else {
        backgroundColor = AppColors.telegramRed.withValues(alpha: 0.15);
        borderColor = AppColors.telegramRed.withValues(alpha: 0.3);
        icon = Icons.cancel_rounded;
      }
    } else {
      backgroundColor = Colors.transparent;
      borderColor = AppColors.getTextSecondary(context).withValues(alpha: 0.2);
      icon = null;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: ResponsiveValues.iconSizeXXS(context),
                color: isCorrect
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed),
            SizedBox(width: ResponsiveValues.spacingXS(context)),
          ],
          Text(
            'Q${widget.index + 1}',
            style: AppTextStyles.labelSmall(context).copyWith(
              color: isAnswered
                  ? (isCorrect
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed)
                  : AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuestionOptions() {
    final question = widget.question;
    final questionId = question.id;
    final options = _getQuestionOptions(question);

    return options.asMap().entries.map((entry) {
      final optionIndex = entry.key;
      final option = entry.value;
      final optionLetter = String.fromCharCode(65 + optionIndex);

      final isSelected = widget.selectedAnswers[questionId] == optionLetter;
      final showExplanation = widget.showExplanation[questionId] == true;
      final isCorrectAnswer = question.correctOption == optionLetter;
      final isUserSelection =
          optionLetter == widget.selectedAnswers[questionId];

      Color optionColor;
      Color borderColor;
      IconData? icon;

      if (showExplanation) {
        if (isCorrectAnswer) {
          optionColor = AppColors.telegramGreen.withValues(alpha: 0.1);
          borderColor = AppColors.telegramGreen.withValues(alpha: 0.5);
          icon = Icons.check_circle_rounded;
        } else if (isUserSelection) {
          optionColor = AppColors.telegramRed.withValues(alpha: 0.1);
          borderColor = AppColors.telegramRed.withValues(alpha: 0.5);
          icon = Icons.cancel_rounded;
        } else {
          optionColor = Colors.transparent;
          borderColor =
              AppColors.getTextSecondary(context).withValues(alpha: 0.1);
          icon = null;
        }
      } else {
        if (isSelected) {
          optionColor = AppColors.telegramBlue.withValues(alpha: 0.1);
          borderColor = AppColors.telegramBlue;
          icon = null;
        } else {
          optionColor = Colors.transparent;
          borderColor =
              AppColors.getTextSecondary(context).withValues(alpha: 0.1);
          icon = null;
        }
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showExplanation
                ? null
                : () => widget.onSelectAnswer(questionId, optionLetter),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            child: Container(
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                color: optionColor,
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                border:
                    Border.all(color: borderColor, width: isSelected ? 2 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected && !showExplanation
                          ? const LinearGradient(colors: AppColors.blueGradient)
                          : null,
                      color: isSelected && !showExplanation
                          ? null
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected && !showExplanation
                            ? Colors.transparent
                            : showExplanation && isCorrectAnswer
                                ? AppColors.telegramGreen
                                : showExplanation && isUserSelection
                                    ? AppColors.telegramRed
                                    : AppColors.getTextSecondary(context)
                                        .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon,
                              size: ResponsiveValues.iconSizeXS(context),
                              color: isCorrectAnswer
                                  ? AppColors.telegramGreen
                                  : AppColors.telegramRed,
                            )
                          : Text(
                              optionLetter,
                              style:
                                  AppTextStyles.labelMedium(context).copyWith(
                                color: isSelected && !showExplanation
                                    ? Colors.white
                                    : showExplanation && isCorrectAnswer
                                        ? AppColors.telegramGreen
                                        : showExplanation && isUserSelection
                                            ? AppColors.telegramRed
                                            : AppColors.getTextSecondary(
                                                context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingXL(context)),
                  Expanded(
                    child: Text(
                      option,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: showExplanation && isCorrectAnswer
                            ? AppColors.telegramGreen
                            : showExplanation &&
                                    isUserSelection &&
                                    !isCorrectAnswer
                                ? AppColors.telegramRed
                                : AppColors.getTextPrimary(context),
                        fontWeight:
                            isSelected || (showExplanation && isCorrectAnswer)
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<String> _getQuestionOptions(Question question) {
    final options = <String>[];
    if (question.optionA?.isNotEmpty ?? false) options.add(question.optionA!);
    if (question.optionB?.isNotEmpty ?? false) options.add(question.optionB!);
    if (question.optionC?.isNotEmpty ?? false) options.add(question.optionC!);
    if (question.optionD?.isNotEmpty ?? false) options.add(question.optionD!);
    if (question.optionE?.isNotEmpty ?? false) options.add(question.optionE!);
    if (question.optionF?.isNotEmpty ?? false) options.add(question.optionF!);
    return options;
  }

  Widget _buildCheckAnswerButton() {
    final questionId = widget.question.id;
    final isSelected = widget.selectedAnswers[questionId] != null;
    final showExplanation = widget.showExplanation[questionId] == true;
    final isCorrect = widget.isQuestionCorrect[questionId] == true;

    if (showExplanation) {
      return Container(
        padding: ResponsiveValues.cardPadding(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCorrect
                ? [
                    AppColors.telegramGreen.withValues(alpha: 0.1),
                    AppColors.telegramGreen.withValues(alpha: 0.05)
                  ]
                : [
                    AppColors.telegramRed.withValues(alpha: 0.1),
                    AppColors.telegramRed.withValues(alpha: 0.05)
                  ],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          border: Border.all(
            color: isCorrect
                ? AppColors.telegramGreen.withValues(alpha: 0.3)
                : AppColors.telegramRed.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.telegramGreen.withValues(alpha: 0.2)
                    : AppColors.telegramRed.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check_rounded : Icons.close_rounded,
                color:
                    isCorrect ? AppColors.telegramGreen : AppColors.telegramRed,
                size: ResponsiveValues.iconSizeS(context),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect ? 'Correct Answer!' : 'Incorrect',
                    style: AppTextStyles.titleSmall(context).copyWith(
                      color: isCorrect
                          ? AppColors.telegramGreen
                          : AppColors.telegramRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isCorrect)
                    Text(
                      'The correct answer is option ${widget.question.correctOption.toUpperCase()}',
                      style: AppTextStyles.caption(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: AppButton.primary(
        label: 'Check Answer',
        onPressed: isSelected
            ? () => widget.onCheckAnswer(
                questionId, widget.selectedAnswers[questionId]!)
            : null,
        expanded: true,
      ),
    );
  }

  Widget _buildExplanationSection() {
    final questionId = widget.question.id;
    final isCorrect = widget.isQuestionCorrect[questionId] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 20),
      child: AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        EdgeInsets.all(ResponsiveValues.spacingXS(context)),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppColors.telegramGreen.withValues(alpha: 0.2)
                          : AppColors.telegramBlue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCorrect ? Icons.lightbulb_rounded : Icons.info_rounded,
                      color: isCorrect
                          ? AppColors.telegramGreen
                          : AppColors.telegramBlue,
                      size: ResponsiveValues.iconSizeXS(context),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingS(context)),
                  Text(
                    'Explanation',
                    style: AppTextStyles.titleSmall(context).copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(
                widget.question.explanation ?? 'No explanation provided.',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.6,
                ),
              ),
              if (!isCorrect) ...[
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Container(
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.telegramGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                    border: Border.all(
                        color: AppColors.telegramGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.telegramGreen, size: 20),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: Text(
                          'Correct answer: Option ${widget.question.correctOption.toUpperCase()}',
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.telegramGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionId = widget.question.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDifficultyBadge(widget.question.difficulty),
                  _buildQuestionNumberBadge(),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              Text(
                widget.question.questionText,
                style: AppTextStyles.titleMedium(context).copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              ..._buildQuestionOptions(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildCheckAnswerButton(),
              if (widget.showExplanation[questionId] == true)
                _buildExplanationSection(),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
