import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'app_card.dart';
import 'app_button.dart';

class AccessBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const AccessBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
  });

  factory AccessBanner.fullAccess() {
    return const AccessBanner(
      icon: Icons.check_circle_rounded,
      color: AppColors.telegramGreen,
      title: 'Full Access',
      message: 'You have access to all content',
    );
  }

  factory AccessBanner.freeCategory() {
    return const AccessBanner(
      icon: Icons.lock_open_rounded,
      color: AppColors.telegramGreen,
      title: 'Free Category',
      message: 'All content is free and accessible',
    );
  }

  factory AccessBanner.limitedAccess({VoidCallback? onPurchase}) {
    return AccessBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: 'Limited Access',
      message: 'Free chapters only. Purchase to unlock all content.',
      actionText: 'Purchase',
      onAction: onPurchase,
    );
  }

  factory AccessBanner.paymentPending({String? message}) {
    return AccessBanner(
      icon: Icons.schedule_rounded,
      color: AppColors.pending,
      title: 'Payment Pending',
      message: message ?? 'Please wait for admin verification',
    );
  }

  factory AccessBanner.paymentRejected({
    required String reason,
    required VoidCallback onPayNow,
  }) {
    return AccessBanner(
      icon: Icons.error_outline_rounded,
      color: AppColors.telegramRed,
      title: 'Payment Rejected',
      message: 'Reason: $reason',
      actionText: 'Pay Now',
      onAction: onPayNow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.sectionPadding(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: AppCard.glass(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context)),
                ),
                child: Icon(icon,
                    size: ResponsiveValues.iconSizeL(context), color: color),
              ),
              SizedBox(width: ResponsiveValues.spacingL(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall(context).copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      message,
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (actionText != null && onAction != null) ...[
                SizedBox(width: ResponsiveValues.spacingM(context)),
                AppButton.glass(
                  label: actionText,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
