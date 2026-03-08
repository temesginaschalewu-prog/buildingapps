import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/exam_model.dart';
import '../../providers/payment_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive_values.dart';
import '../common/app_dialog.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTap;
  final int index;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    this.index = 0,
  });

  Color _getStatusColor(BuildContext context) {
    if (exam.isBlockedByPendingPayment) return AppColors.pending;
    if (exam.canTakeExam) return AppColors.telegramGreen;
    if (exam.requiresPayment) return AppColors.telegramBlue;
    if (exam.maxAttemptsReached) return AppColors.telegramRed;
    if (exam.isUpcoming) return AppColors.telegramBlue;
    if (exam.isEnded) return AppColors.telegramGray;
    if (exam.isInProgress) return AppColors.telegramBlue;
    return AppColors.telegramBlue;
  }

  Color _getStatusBackgroundColor(BuildContext context) {
    final color = _getStatusColor(context);
    if (color == AppColors.telegramGreen) return AppColors.greenFaded;
    if (color == AppColors.telegramBlue) return AppColors.blueFaded;
    if (color == AppColors.telegramRed) return AppColors.redFaded;
    if (color == AppColors.telegramYellow) return AppColors.yellowFaded;
    if (color == AppColors.pending) return AppColors.orangeFaded;
    if (color == AppColors.telegramGray) return AppColors.grayFaded;
    return color.withValues(alpha: 0.1);
  }

  IconData _getStatusIcon() {
    if (exam.isBlockedByPendingPayment) return Icons.schedule_rounded;
    if (exam.canTakeExam) return Icons.play_circle_rounded;
    if (exam.requiresPayment) return Icons.lock_rounded;
    if (exam.maxAttemptsReached) return Icons.block_rounded;
    if (exam.isUpcoming) return Icons.schedule_rounded;
    if (exam.isEnded) return Icons.history_rounded;
    if (exam.isInProgress) return Icons.hourglass_bottom_rounded;
    return Icons.assignment_rounded;
  }

  String _getStatusText() {
    if (exam.isBlockedByPendingPayment) return 'PENDING';
    if (exam.canTakeExam) return 'TAKE EXAM';
    if (exam.requiresPayment) return 'LOCKED';
    if (exam.maxAttemptsReached) return 'MAX ATTEMPTS';
    if (exam.isUpcoming) return 'UPCOMING';
    if (exam.isEnded) return 'ENDED';
    if (exam.isInProgress) return 'IN PROGRESS';
    return 'AVAILABLE';
  }

  String _getTimeInfo() {
    final now = DateTime.now();

    if (exam.hasUserTimeLimit) return '${exam.userTimeLimit} min';

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

  Future<void> _handleTap(BuildContext context) async {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final hasPendingPayment = paymentProvider.payments.any(
      (payment) =>
          payment.status == 'pending' &&
          payment.categoryName.toLowerCase() == exam.categoryName.toLowerCase(),
    );

    if (hasPendingPayment || exam.isBlockedByPendingPayment) {
      _showPendingPaymentDialog(context);
      return;
    }

    if (exam.requiresPayment && !exam.hasAccess) {
      _showPurchaseDialog(context);
      return;
    }

    onTap();
  }

  void _showPurchaseDialog(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'Purchase Required',
      message:
          'You need to purchase "${exam.categoryName}" to access this exam.',
      confirmText: 'Purchase Now',
    ).then((confirmed) {
      if (confirmed == true) {
        context.push('/payment', extra: {
          'category': {
            'id': exam.categoryId,
            'name': exam.categoryName,
            'isFree': false,
          },
          'paymentType': 'first_time',
        });
      }
    });
  }

  void _showPendingPaymentDialog(BuildContext context) {
    AppDialog.info(
      context: context,
      title: 'Payment Pending',
      message:
          'Your payment for "${exam.categoryName}" is being verified. Please wait for admin confirmation.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final statusBgColor = _getStatusBackgroundColor(context);

    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final titleSize = ResponsiveValues.fontTitleMedium(context);
    final badgeSize = ResponsiveValues.fontBodySmall(context);
    final padding = ResponsiveValues.cardPadding(context);
    final iconSpacing = ResponsiveValues.spacingS(context);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleTap(context),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                splashColor: statusColor.withValues(alpha: 0.1),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: padding,
                  child: Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusLarge(context)),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        child: Icon(_getStatusIcon(),
                            size: iconSize * 0.5, color: statusColor),
                      ),
                      SizedBox(width: iconSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              exam.title,
                              style:
                                  AppTextStyles.titleMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: titleSize,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                                height: ResponsiveValues.spacingS(context)),
                            Wrap(
                              spacing: iconSpacing,
                              runSpacing: iconSpacing,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: iconSpacing,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveValues.radiusFull(context)),
                                    border: Border.all(
                                        color:
                                            statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(),
                                          size: badgeSize * 1.2,
                                          color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusText(),
                                        style: TextStyle(
                                          fontSize: badgeSize,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: iconSpacing,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grayFaded,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveValues.radiusFull(context)),
                                    border: Border.all(
                                        color: AppColors.telegramGray
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_rounded,
                                        size: badgeSize * 1.2,
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTimeInfo(),
                                        style: TextStyle(
                                          fontSize: badgeSize,
                                          color: AppColors.getTextSecondary(
                                              context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (exam.attemptsTaken > 0)
                              Padding(
                                padding: EdgeInsets.only(
                                    top: ResponsiveValues.spacingS(context)),
                                child: Text(
                                  'Attempts: ${exam.attemptsTaken}/${exam.maxAttempts}',
                                  style: TextStyle(
                                    fontSize: badgeSize * 0.9,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: iconSpacing),
                        child: Container(
                          padding: EdgeInsets.all(iconSpacing),
                          decoration: BoxDecoration(
                            color: exam.canTakeExam
                                ? AppColors.telegramBlue.withValues(alpha: 0.1)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            exam.canTakeExam
                                ? Icons.chevron_right_rounded
                                : Icons.lock_rounded,
                            size: badgeSize * 1.5,
                            color: exam.canTakeExam
                                ? AppColors.telegramBlue
                                : AppColors.getTextSecondary(context),
                          ),
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
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        );
  }
}
