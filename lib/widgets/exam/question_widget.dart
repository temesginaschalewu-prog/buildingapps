import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../models/exam_question_model.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import '../common/responsive_widgets.dart';

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

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.3),
                AppColors.getCard(context).withValues(alpha: 0.1),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.question.options;
    final optionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

    final questionFontSize = ResponsiveValues.fontBodyLarge(context);
    final padding = ResponsiveValues.cardPadding(context);

    final difficultyColor = _getDifficultyColor(widget.question.difficulty);
    final difficultyBgColor =
        _getDifficultyBackgroundColor(widget.question.difficulty);

    return ResponsiveColumn(
      children: [
        ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              padding: EdgeInsets.all((padding / 1.5) as double),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withValues(alpha: 0.3),
                    AppColors.getCard(context).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                border: Border.all(
                  color: AppColors.telegramBlue.withValues(alpha: 0.2),
                ),
              ),
              child: ResponsiveRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ResponsiveRow(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingS(context),
                          vertical: ResponsiveValues.spacingXXS(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                          border: Border.all(
                            color:
                                AppColors.telegramBlue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ResponsiveText(
                          '${widget.question.marks} mark${widget.question.marks > 1 ? 's' : ''}',
                          style: AppTextStyles.caption(context).copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const ResponsiveSizedBox(width: AppSpacing.s),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingS(context),
                          vertical: ResponsiveValues.spacingXXS(context),
                        ),
                        decoration: BoxDecoration(
                          color: difficultyBgColor,
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                          border: Border.all(
                            color: difficultyColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ResponsiveRow(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: ResponsiveValues.spacingXS(context),
                              height: ResponsiveValues.spacingXS(context),
                              decoration: BoxDecoration(
                                color: difficultyColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        difficultyColor.withValues(alpha: 0.5),
                                    blurRadius:
                                        ResponsiveValues.spacingXS(context),
                                  ),
                                ],
                              ),
                            ),
                            const ResponsiveSizedBox(width: AppSpacing.xs),
                            ResponsiveText(
                              widget.question.difficulty.toUpperCase(),
                              style: AppTextStyles.caption(context).copyWith(
                                color: difficultyColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingS(context),
                      vertical: ResponsiveValues.spacingXXS(context),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.grayFaded,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context),
                      ),
                      border: Border.all(
                        color: AppColors.telegramGray.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ResponsiveText(
                      'Q${widget.question.displayOrder}',
                      style: AppTextStyles.caption(context).copyWith(
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
        const ResponsiveSizedBox(height: AppSpacing.l),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withValues(alpha: 0.4),
                    AppColors.getCard(context).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusLarge(context)),
                border: Border.all(
                  color: AppColors.telegramBlue.withValues(alpha: 0.2),
                ),
              ),
              child: ResponsiveText(
                widget.question.questionText,
                style: AppTextStyles.bodyLarge(context).copyWith(
                  fontSize: questionFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingXS(context),
          ),
          child: ResponsiveText(
            'Select your answer:',
            style: AppTextStyles.labelLarge(context).copyWith(
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.m),
        ...List.generate(options.length, (index) {
          final option = options[index];
          final optionLetter = optionLetters[index];
          final isSelected = _selectedOption == optionLetter;

          return Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveValues.spacingM(context),
            ),
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
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  if (isSelected)
                    AppColors.telegramBlue.withValues(alpha: 0.15)
                  else
                    AppColors.getCard(context).withValues(alpha: 0.2),
                  if (isSelected)
                    AppColors.telegramBlue.withValues(alpha: 0.05)
                  else
                    AppColors.getCard(context).withValues(alpha: 0.1),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
              border: Border.all(
                color: isSelected
                    ? AppColors.telegramBlue.withValues(alpha: 0.5)
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: ResponsiveRow(
                    children: [
                      Container(
                        width: ResponsiveValues.iconSizeL(context),
                        height: ResponsiveValues.iconSizeL(context),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: AppColors.blueGradient,
                                )
                              : null,
                          color: isSelected ? null : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: ResponsiveText(
                            optionLetter,
                            style: AppTextStyles.labelLarge(context).copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const ResponsiveSizedBox(width: AppSpacing.l),
                      Expanded(
                        child: ResponsiveText(
                          option,
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: isSelected
                                ? AppColors.telegramBlue
                                : AppColors.getTextPrimary(context),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: EdgeInsets.all(
                              ResponsiveValues.spacingXXS(context)),
                          decoration: BoxDecoration(
                            color:
                                AppColors.telegramBlue.withValues(alpha: 0.2),
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
