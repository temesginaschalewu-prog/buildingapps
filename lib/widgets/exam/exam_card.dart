// lib/widgets/exam/exam_card.dart
// PRODUCTION-READY FINAL VERSION - WITH PENDING PAYMENT CHECK

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/exam_model.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';
import '../common/app_dialog.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTap;
  final int index;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool canTake = exam.canTakeExam;
    final bool isCompleted = exam.status == 'completed';
    final bool isInProgress = exam.status == 'in_progress';
    final bool isUpcoming = exam.isUpcoming;
    final bool isEnded = exam.isEnded;

    final Color statusColor = canTake
        ? AppColors.telegramGreen
        : (isEnded
            ? AppColors.telegramRed
            : (isUpcoming ? AppColors.telegramYellow : AppColors.telegramGray));

    String statusText = exam.status.toUpperCase();
    if (isCompleted) statusText = 'COMPLETED';
    if (isInProgress) statusText = 'IN PROGRESS';
    if (isUpcoming) statusText = 'UPCOMING';
    if (isEnded) statusText = 'ENDED';

    return AppCard.exam(
      onTap: () => _handleTap(context),
      statusColor: statusColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  decoration: BoxDecoration(
                    color: canTake
                        ? AppColors.telegramGreen.withValues(alpha: 0.09)
                        : statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context)),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : (isInProgress
                            ? Icons.hourglass_empty_rounded
                            : Icons.quiz_rounded),
                    size: ResponsiveValues.iconSizeL(context),
                    color: canTake ? AppColors.telegramGreen : statusColor,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: ResponsiveValues.iconSizeXXS(context),
                            color: AppColors.getTextSecondary(context),
                          ),
                          SizedBox(width: ResponsiveValues.spacingXXS(context)),
                          Text(
                            _formatDuration(exam.duration),
                            style: AppTextStyles.caption(context).copyWith(
                                color: AppColors.getTextSecondary(context)),
                          ),
                          SizedBox(width: ResponsiveValues.spacingM(context)),
                          Icon(
                            Icons.repeat_rounded,
                            size: ResponsiveValues.iconSizeXXS(context),
                            color: AppColors.getTextSecondary(context),
                          ),
                          SizedBox(width: ResponsiveValues.spacingXXS(context)),
                          Text(
                            '${exam.attemptsTaken}/${exam.maxAttempts}',
                            style: AppTextStyles.caption(context).copyWith(
                                color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                      if (exam.message.isNotEmpty) ...[
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          exam.message,
                          style: AppTextStyles.caption(context).copyWith(
                            color: statusColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingS(context),
                        vertical: ResponsiveValues.spacingXXS(context),
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context)),
                      ),
                      child: Text(
                        statusText,
                        style: AppTextStyles.statusBadge(context).copyWith(
                          color: statusColor,
                          fontSize:
                              ResponsiveValues.fontStatusBadge(context) * 0.9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      '${exam.questionCount} questions',
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: (index * 50).ms,
        );
  }

  Future<void> _handleTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final paymentProvider = context.read<PaymentProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final connectivity = context.read<ConnectivityService>();

    if (!authProvider.isAuthenticated) {
      SnackbarService().showError(context, 'Please login to access exams');
      return;
    }

    final category = categoryProvider.getCategoryById(exam.categoryId);
    if (category == null) {
      SnackbarService().showError(context, 'Category not found');
      return;
    }

    final bool hasAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(exam.categoryId);

    if (hasAccess) {
      onTap();
      return;
    }

    if (exam.canTakeExam) {
      onTap();
      return;
    }

    final hasPendingPayment = paymentProvider.getPendingPayments().any(
          (payment) =>
              payment.categoryId == exam.categoryId ||
              payment.categoryName.toLowerCase() == category.name.toLowerCase(),
        );

    if (hasPendingPayment) {
      await AppDialog.info(
        context: context,
        title: 'Payment Pending',
        message:
            'You have a pending payment for "${category.name}". Please wait for admin verification.',
      );
      return;
    }

    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'make payment');
      return;
    }

    _showPaymentDialog(context, category);
  }

  void _showPaymentDialog(BuildContext context, Category category) {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasExpiredSubscription = subscriptionProvider.expiredSubscriptions
        .any((sub) => sub.categoryId == category.id);

    final paymentType = hasExpiredSubscription ? 'repayment' : 'first_time';

    AppDialog.confirm(
      context: context,
      title: 'Unlock Exam',
      message: hasExpiredSubscription
          ? 'Your subscription for "${category.name}" has expired. Renew to access this exam.'
          : 'This exam requires access to "${category.name}". Purchase to unlock.',
      confirmText: hasExpiredSubscription ? 'Renew Now' : 'Purchase Access',
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.push('/payment', extra: {
          'category': category,
          'paymentType': paymentType,
        });
      }
    });
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes > 0) {
        return '${hours}h ${remainingMinutes}m';
      } else {
        return '${hours}h';
      }
    }
  }
}
