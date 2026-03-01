import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:shimmer/shimmer.dart';

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
    if (exam.isBlockedByPendingPayment) return AppColors.statusPending;
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
    if (color == AppColors.statusPending) return AppColors.orangeFaded;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const SizedBox(height: 20),
            _buildDialogContent(
              context,
              icon: Icons.lock_open_rounded,
              iconColor: AppColors.telegramBlue,
              title: 'Purchase Required',
              message:
                  'You need to purchase "${exam.categoryName}" to access this exam.',
              buttonText: 'Purchase Now',
              onButtonPressed: () {
                Navigator.pop(context);
                context.push('/payment', extra: {
                  'category': {
                    'id': exam.categoryId,
                    'name': exam.categoryName,
                    'isFree': false,
                  },
                  'paymentType': 'first_time',
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPendingPaymentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const SizedBox(height: 20),
            _buildDialogContent(
              context,
              icon: Icons.schedule_rounded,
              iconColor: AppColors.statusPending,
              title: 'Payment Pending',
              message:
                  'Your payment for "${exam.categoryName}" is being verified. Please wait for admin confirmation.',
              buttonText: 'OK',
              onButtonPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBottomSheet(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDialogContent(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final statusBgColor = _getStatusBackgroundColor(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final titleSize = isMobile ? 16.0 : (isTablet ? 17.0 : 18.0);
    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemes.spacingL),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleTap(context),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: statusColor,
                          size: iconSize * 0.5,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.title,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: titleSize,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
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
                                      const SizedBox(width: 4),
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
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grayFaded,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.telegramGray
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_rounded,
                                        size: 12,
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTimeInfo(),
                                        style: AppTextStyles.caption.copyWith(
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
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Attempts: ${exam.attemptsTaken}/${exam.maxAttempts}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            if (exam.requiresPayment &&
                                !exam.hasAccess &&
                                !exam.isBlockedByPendingPayment)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Purchase "${exam.categoryName}" to access',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.telegramBlue,
                                  ),
                                ),
                              ),
                            if (exam.isBlockedByPendingPayment)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Payment pending verification',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.statusPending,
                                  ),
                                ),
                              ),
                            if (isTablet || !isMobile)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: exam.canTakeExam
                              ? AppColors.telegramBlue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          exam.canTakeExam
                              ? Icons.chevron_right_rounded
                              : (exam.isBlockedByPendingPayment
                                  ? Icons.schedule_rounded
                                  : Icons.lock_rounded),
                          size: isMobile ? 20 : (isTablet ? 24 : 28),
                          color: exam.canTakeExam
                              ? AppColors.telegramBlue
                              : (exam.isBlockedByPendingPayment
                                  ? AppColors.statusPending
                                  : AppColors.getTextSecondary(context)),
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
            duration: AppThemes.animationDurationMedium, delay: (index * 50).ms)
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }
}

class ExamCardShimmer extends StatelessWidget {
  final int index;

  const ExamCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    return Container(
      margin: const EdgeInsets.only(bottom: AppThemes.spacingL),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Shimmer.fromColors(
                            baseColor:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor:
                                isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              width: 80,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Shimmer.fromColors(
                            baseColor:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor:
                                isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              width: 70,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
        duration: AppThemes.animationDurationMedium, delay: (index * 50).ms);
  }
}
