import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:shimmer/shimmer.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTap;
  final int index; // For staggered animations

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    this.index = 0,
  });

  Color _getStatusColor(BuildContext context) {
    if (exam.isBlockedByPendingPayment) {
      return AppColors.statusPending;
    } else if (exam.canTakeExam) {
      return AppColors.telegramGreen;
    } else if (exam.requiresPayment) {
      return AppColors.telegramBlue;
    } else if (exam.maxAttemptsReached) {
      return AppColors.telegramRed;
    } else if (exam.isUpcoming) {
      return AppColors.telegramYellow;
    } else if (exam.isEnded) {
      return AppColors.telegramGray;
    } else if (exam.isInProgress) {
      return AppColors.telegramBlue;
    }
    return AppColors.telegramBlue;
  }

  Color _getStatusBackgroundColor(BuildContext context) {
    final color = _getStatusColor(context);
    return color.withOpacity(0.1);
  }

  IconData _getStatusIcon() {
    if (exam.isBlockedByPendingPayment) {
      return Icons.schedule_rounded;
    } else if (exam.canTakeExam) {
      return Icons.play_circle_rounded;
    } else if (exam.requiresPayment) {
      return Icons.lock_rounded;
    } else if (exam.maxAttemptsReached) {
      return Icons.block_rounded;
    } else if (exam.isUpcoming) {
      return Icons.schedule_rounded;
    } else if (exam.isEnded) {
      return Icons.history_rounded;
    } else if (exam.isInProgress) {
      return Icons.hourglass_bottom_rounded;
    }
    return Icons.assignment_rounded;
  }

  String _getStatusText() {
    if (exam.isBlockedByPendingPayment) {
      return 'PENDING';
    } else if (exam.canTakeExam) {
      return 'TAKE EXAM';
    } else if (exam.requiresPayment) {
      return 'LOCKED';
    } else if (exam.maxAttemptsReached) {
      return 'MAX ATTEMPTS';
    } else if (exam.isUpcoming) {
      return 'UPCOMING';
    } else if (exam.isEnded) {
      return 'ENDED';
    } else if (exam.isInProgress) {
      return 'IN PROGRESS';
    }
    return 'AVAILABLE';
  }

  String _getTimeInfo() {
    final now = DateTime.now();

    if (exam.hasUserTimeLimit) {
      return '${exam.userTimeLimit} min';
    }

    if (now.isBefore(exam.startDate)) {
      final days = exam.startDate.difference(now).inDays;
      if (days < 1) {
        final hours = exam.startDate.difference(now).inHours;
        return 'Starts in $hours h';
      }
      return 'Starts in $days d';
    } else if (now.isBefore(exam.endDate)) {
      final days = exam.endDate.difference(now).inDays;
      if (days < 1) {
        final hours = exam.endDate.difference(now).inHours;
        return 'Ends in $hours h';
      }
      return 'Ends in $days d';
    }
    return 'Ended';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final statusBgColor = _getStatusBackgroundColor(context);

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingL),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          splashColor: AppColors.telegramBlue.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL,
            )),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              border: Border.all(
                color: Theme.of(context).dividerTheme.color ??
                    AppColors.lightDivider,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Left side - Status indicator
                Container(
                  width: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 48,
                    tablet: 56,
                    desktop: 64,
                  ),
                  height: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 48,
                    tablet: 56,
                    desktop: 64,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: statusColor,
                    size: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 24,
                      tablet: 28,
                      desktop: 32,
                    ),
                  ),
                ),

                SizedBox(width: AppThemes.spacingL),

                // Middle - Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        exam.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontSize: ScreenSize.responsiveFontSize(
                            context: context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: AppThemes.spacingS),

                      // Metadata row
                      Row(
                        children: [
                          // Status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                              border: Border.all(
                                color: statusColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(),
                                  size: 12,
                                  color: statusColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _getStatusText(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: AppThemes.spacingM),

                          // Time badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_rounded,
                                  size: 12,
                                  color: AppColors.getTextSecondary(context),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _getTimeInfo(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Access message if blocked by pending payment
                      if (exam.isBlockedByPendingPayment)
                        Padding(
                          padding: EdgeInsets.only(top: AppThemes.spacingS),
                          child: Text(
                            'Payment pending verification',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.statusPending,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Access message if requires payment
                      if (exam.requiresPayment &&
                          !exam.hasAccess &&
                          !exam.isBlockedByPendingPayment)
                        Padding(
                          padding: EdgeInsets.only(top: AppThemes.spacingS),
                          child: Text(
                            'Purchase "${exam.categoryName}" to access',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Attempts info
                      if (exam.attemptsTaken > 0)
                        Padding(
                          padding: EdgeInsets.only(top: AppThemes.spacingS),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Attempts: ${exam.attemptsTaken}/${exam.maxAttempts}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Course info (on tablet/desktop)
                      if (ScreenSize.isTablet(context) ||
                          ScreenSize.isDesktop(context))
                        Padding(
                          padding: EdgeInsets.only(top: AppThemes.spacingS),
                          child: Row(
                            children: [
                              Icon(
                                Icons.book_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  exam.courseName,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Right arrow
                Icon(
                  exam.canTakeExam
                      ? Icons.chevron_right_rounded
                      : exam.isBlockedByPendingPayment
                          ? Icons.schedule_rounded
                          : Icons.lock_rounded,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                  color: exam.canTakeExam
                      ? AppColors.telegramBlue
                      : exam.isBlockedByPendingPayment
                          ? AppColors.statusPending
                          : AppColors.getTextSecondary(context),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }
}

// Skeleton loader for ExamCard
class ExamCardShimmer extends StatelessWidget {
  final int index;

  const ExamCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingL),
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: isDark
              ? AppColors.darkDivider.withOpacity(0.3)
              : AppColors.lightDivider.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator shimmer
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              height: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
            ),
          ),

          SizedBox(width: AppThemes.spacingL),

          // Content shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                    ),
                  ),
                ),
                SizedBox(height: AppThemes.spacingS),
                Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                        width: 80,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right arrow shimmer
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }
}
