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
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/utils/app_enums.dart';
import 'package:shimmer/shimmer.dart';
import '../common/responsive_widgets.dart';

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

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
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
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
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
            padding: ResponsiveValues.dialogPadding(context),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: ResponsiveValues.spacingXXL(context),
        height: ResponsiveValues.spacingXS(context),
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withValues(alpha: 0.3),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: ResponsiveValues.spacingS(context),
              offset: Offset(0, ResponsiveValues.spacingXS(context)),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingM(context),
              ),
              alignment: Alignment.center,
              child: ResponsiveText(
                label,
                style: AppTextStyles.labelLarge(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
    return ResponsiveColumn(
      children: [
        ResponsiveRow(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: ResponsiveIcon(
                icon,
                size: ResponsiveValues.iconSizeL(context),
                color: iconColor,
              ),
            ),
            const ResponsiveSizedBox(width: AppSpacing.l),
            Expanded(
              child: ResponsiveColumn(
                children: [
                  ResponsiveText(
                    title,
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    message,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const ResponsiveSizedBox(height: AppSpacing.xl),
        ResponsiveRow(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                ),
                child: ResponsiveText(
                  'Cancel',
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: AppColors.blueGradient,
              ),
            ),
          ],
        ),
      ],
    );
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
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const ResponsiveSizedBox(height: AppSpacing.xl),
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
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const ResponsiveSizedBox(height: AppSpacing.xl),
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final statusBgColor = _getStatusBackgroundColor(context);

    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final titleSize = ResponsiveValues.fontTitleMedium(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveValues.spacingL(context),
      ),
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
                child: Padding(
                  padding: padding,
                  child: ResponsiveRow(
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
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusLarge(context),
                          ),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ResponsiveIcon(
                          _getStatusIcon(),
                          size: iconSize * 0.5,
                          color: statusColor,
                        ),
                      ),
                      const ResponsiveSizedBox(width: AppSpacing.l),
                      Expanded(
                        child: ResponsiveColumn(
                          children: [
                            ResponsiveText(
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
                            const ResponsiveSizedBox(height: AppSpacing.s),
                            ResponsiveRow(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        ResponsiveValues.spacingS(context),
                                    vertical:
                                        ResponsiveValues.spacingXXS(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveValues.radiusFull(context),
                                    ),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: ResponsiveRow(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ResponsiveIcon(
                                        _getStatusIcon(),
                                        size: ResponsiveValues.iconSizeXXS(
                                            context),
                                        color: statusColor,
                                      ),
                                      const ResponsiveSizedBox(
                                          width: AppSpacing.xs),
                                      ResponsiveText(
                                        _getStatusText(),
                                        style: AppTextStyles.caption(context)
                                            .copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const ResponsiveSizedBox(width: AppSpacing.s),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        ResponsiveValues.spacingS(context),
                                    vertical:
                                        ResponsiveValues.spacingXXS(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.grayFaded,
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveValues.radiusFull(context),
                                    ),
                                    border: Border.all(
                                      color: AppColors.telegramGray
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: ResponsiveRow(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_rounded,
                                        size: ResponsiveValues.iconSizeXXS(
                                            context),
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                      const ResponsiveSizedBox(
                                          width: AppSpacing.xs),
                                      ResponsiveText(
                                        _getTimeInfo(),
                                        style: AppTextStyles.caption(context)
                                            .copyWith(
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
                                  top: ResponsiveValues.spacingS(context),
                                ),
                                child: ResponsiveText(
                                  'Attempts: ${exam.attemptsTaken}/${exam.maxAttempts}',
                                  style:
                                      AppTextStyles.caption(context).copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            if (exam.requiresPayment &&
                                !exam.hasAccess &&
                                !exam.isBlockedByPendingPayment)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: ResponsiveValues.spacingS(context),
                                ),
                                child: ResponsiveText(
                                  'Purchase "${exam.categoryName}" to access',
                                  style:
                                      AppTextStyles.caption(context).copyWith(
                                    color: AppColors.telegramBlue,
                                  ),
                                ),
                              ),
                            if (exam.isBlockedByPendingPayment)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: ResponsiveValues.spacingS(context),
                                ),
                                child: ResponsiveText(
                                  'Payment pending verification',
                                  style:
                                      AppTextStyles.caption(context).copyWith(
                                    color: AppColors.statusPending,
                                  ),
                                ),
                              ),
                            if (ScreenSize.isTablet(context) ||
                                !ScreenSize.isMobile(context))
                              Padding(
                                padding: EdgeInsets.only(
                                  top: ResponsiveValues.spacingS(context),
                                ),
                                child: ResponsiveText(
                                  exam.courseName,
                                  style:
                                      AppTextStyles.caption(context).copyWith(
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
                        padding:
                            EdgeInsets.all(ResponsiveValues.spacingS(context)),
                        decoration: BoxDecoration(
                          color: exam.canTakeExam
                              ? AppColors.telegramBlue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: ResponsiveIcon(
                          exam.canTakeExam
                              ? Icons.chevron_right_rounded
                              : (exam.isBlockedByPendingPayment
                                  ? Icons.schedule_rounded
                                  : Icons.lock_rounded),
                          size: ResponsiveValues.iconSizeL(context),
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
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveValues.spacingL(context),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
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
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: ResponsiveRow(
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
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                    ),
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    children: [
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: ResponsiveValues.spacingXL(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context),
                            ),
                          ),
                        ),
                      ),
                      const ResponsiveSizedBox(height: AppSpacing.m),
                      ResponsiveRow(
                        children: [
                          Shimmer.fromColors(
                            baseColor:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor:
                                isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              width: ResponsiveValues.spacingXXL(context) * 2,
                              height: ResponsiveValues.spacingXL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context),
                                ),
                              ),
                            ),
                          ),
                          const ResponsiveSizedBox(width: AppSpacing.s),
                          Shimmer.fromColors(
                            baseColor:
                                isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor:
                                isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              width: ResponsiveValues.spacingXXL(context) * 1.5,
                              height: ResponsiveValues.spacingXL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context),
                                ),
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
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
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
