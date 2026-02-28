import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../models/payment_model.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../providers/settings_provider.dart';

class PaymentCard extends StatelessWidget {
  final Payment payment;
  final VoidCallback? onTap;
  final bool showDetails;
  final bool compact;

  const PaymentCard({
    super.key,
    required this.payment,
    this.onTap,
    this.showDetails = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final paymentMethod =
        _getPaymentMethodInfo(settingsProvider, payment.paymentMethod);

    if (compact) return _buildCompactCard(context, paymentMethod);

    return _buildDetailedCard(context, paymentMethod);
  }

  Widget _buildCompactCard(BuildContext context, PaymentMethod? paymentMethod) {
    final statusColor = AppColors.getStatusColor(payment.status, context);
    final statusBgColor =
        AppColors.getStatusBackground(payment.status, context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          splashColor: AppColors.telegramBlue.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border:
                  Border.all(color: Theme.of(context).dividerColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1))
              ],
            ),
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: statusColor)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.categoryName,
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          _getPaymentMethodDisplayText(
                              paymentMethod, payment.paymentMethod),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.getTextSecondary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${payment.amount.toStringAsFixed(0)} Birr',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_formatCompactDate(payment.createdAt),
                          style: AppTextStyles.caption.copyWith(
                              color: statusColor, fontWeight: FontWeight.w500)),
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
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0, duration: 300.ms);
  }

  Widget _buildDetailedCard(
      BuildContext context, PaymentMethod? paymentMethod) {
    final statusColor = AppColors.getStatusColor(payment.status, context);
    final statusBgColor =
        AppColors.getStatusBackground(payment.status, context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final padding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);
    final titleSize = isMobile ? 16.0 : (isTablet ? 17.0 : 18.0);
    final amountSize = isMobile ? 22.0 : (isTablet ? 23.0 : 24.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          splashColor: AppColors.telegramBlue.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              border:
                  Border.all(color: Theme.of(context).dividerColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                          border: Border.all(color: statusColor, width: 1)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(payment.status),
                              size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(_getStatusText(payment.status),
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${payment.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: amountSize,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                        Text('Birr',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(payment.categoryName,
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontSize: titleSize)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (paymentMethod != null)
                      Icon(paymentMethod.iconData,
                          size: isMobile ? 16 : (isTablet ? 17 : 18),
                          color: AppColors.getTextSecondary(context)),
                    if (paymentMethod != null) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPaymentMethodDisplayText(
                            paymentMethod, payment.paymentMethod),
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontSize: isMobile ? 14 : (isTablet ? 15 : 16)),
                      ),
                    ),
                    Text(_formatDate(payment.createdAt),
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ],
                ),
                if (payment.accountHolderName != null &&
                    payment.accountHolderName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: isMobile ? 14 : (isTablet ? 15 : 16),
                          color: AppColors.getTextSecondary(context)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Account Holder: ${payment.accountHolderName}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context)))),
                    ],
                  ),
                ],
                if (showDetails) ...[
                  if (payment.rejectionReason != null) ...[
                    const SizedBox(height: 16),
                    _buildRejectionReason(context),
                  ],
                  if (payment.verifiedAt != null) ...[
                    const SizedBox(height: 12),
                    _buildVerificationDate(context),
                  ],
                  if (paymentMethod != null) ...[
                    const SizedBox(height: 16),
                    _buildPaymentMethodDetails(context, paymentMethod),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildRejectionReason(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.telegramRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(color: AppColors.telegramRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.telegramRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rejection Reason',
                    style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.telegramRed)),
                const SizedBox(height: 4),
                Text(payment.rejectionReason!,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.telegramRed.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDate(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 18, color: AppColors.telegramGreen),
        const SizedBox(width: 8),
        Text('Verified: ${_formatDate(payment.verifiedAt!)}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.telegramGreen)),
      ],
    );
  }

  Widget _buildPaymentMethodDetails(
      BuildContext context, PaymentMethod paymentMethod) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(paymentMethod.iconData,
                  size: 18, color: AppColors.telegramBlue),
              const SizedBox(width: 8),
              Text(paymentMethod.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 8),
          if (paymentMethod.accountInfo.isNotEmpty)
            Text('Account: ${paymentMethod.accountInfo}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.getTextSecondary(context))),
          if (payment.accountHolderName != null &&
              payment.accountHolderName!.isNotEmpty)
            Text('Account Holder: ${payment.accountHolderName}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500)),
          if (paymentMethod.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Instructions: ${paymentMethod.instructions}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  PaymentMethod? _getPaymentMethodInfo(
      SettingsProvider provider, String methodKey) {
    try {
      final methods = provider.getPaymentMethods();
      return methods.firstWhere(
        (method) => method.method == methodKey,
        orElse: () => PaymentMethod(
          method: methodKey,
          name: _formatMethodName(methodKey),
          accountInfo: 'Contact support for details',
          instructions: '',
          iconData: Icons.payment_rounded,
        ),
      );
    } catch (e) {
      return PaymentMethod(
        method: methodKey,
        name: _formatMethodName(methodKey),
        accountInfo: 'Contact support for details',
        instructions: '',
        iconData: Icons.payment_rounded,
      );
    }
  }

  String _getPaymentMethodDisplayText(
      PaymentMethod? paymentMethod, String methodKey) {
    return paymentMethod != null
        ? paymentMethod.name
        : _formatMethodName(methodKey);
  }

  String _formatMethodName(String methodKey) {
    return methodKey
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) return '${difference.inMinutes}m';
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    return '${date.day}/${date.month}';
  }
}
