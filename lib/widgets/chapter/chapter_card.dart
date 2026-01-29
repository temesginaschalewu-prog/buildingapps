import 'package:familyacademyclient/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import '../../themes/app_colors.dart';
import '../../utils/helpers.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int courseId;
  final int categoryId;
  final String categoryName;
  final VoidCallback onTap;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.courseId,
    required this.categoryId,
    required this.categoryName,
    required this.onTap,
  });

  Color _getStatusColor(bool hasAccess) {
    if (hasAccess) {
      return AppColors.success;
    } else {
      return chapter.isFree ? Colors.orange : AppColors.locked;
    }
  }

  IconData _getStatusIcon(bool hasAccess) {
    if (hasAccess) {
      return Icons.play_circle_fill;
    } else {
      return chapter.isFree ? Icons.schedule : Icons.lock;
    }
  }

  String _getStatusText(bool hasAccess) {
    if (hasAccess) {
      return 'ACCESSIBLE';
    } else {
      return chapter.isFree ? 'COMING SOON' : 'LOCKED';
    }
  }

  void _handleTap(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    final category = categoryProvider.getCategoryById(categoryId);
    final isCategoryFree = category?.isFree ?? false;

    final hasAccess = chapter.isFree ||
        isCategoryFree ||
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    if (hasAccess) {
      onTap();
    } else {
      _showPaymentDialog(context, category);
    }
  }

  void _showPaymentDialog(BuildContext context, Category? category) {
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    if (category == null) {
      showSnackBar(context, 'Category not found', isError: true);
      return;
    }

    final pendingPayments = paymentProvider.getPendingPayments();
    final hasPendingPayment = pendingPayments.any((payment) =>
        payment.categoryName.toLowerCase() == category.name.toLowerCase());

    if (hasPendingPayment) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Pending'),
          content: const Text(
            'You already have a pending payment for this category. '
            'Please wait for admin verification (1-3 working days).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Text(
          'You need to purchase "$categoryName" to access this chapter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                '/payment',
                extra: {
                  'category': category,
                  'paymentType': subscriptionProvider
                          .hasActiveSubscriptionForCategory(categoryId)
                      ? 'repayment'
                      : 'first_time',
                },
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    final category = categoryProvider.getCategoryById(categoryId);
    final isCategoryFree = category?.isFree ?? false;

    final hasAccess = chapter.isFree ||
        isCategoryFree ||
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(hasAccess).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(hasAccess),
                  color: _getStatusColor(hasAccess),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(hasAccess).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _getStatusColor(hasAccess)),
                      ),
                      child: Text(
                        _getStatusText(hasAccess),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getStatusColor(hasAccess),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chapter.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!hasAccess && !chapter.isFree)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          isCategoryFree
                              ? 'Free category access'
                              : 'Purchase "$categoryName" to unlock',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isCategoryFree
                                        ? AppColors.success
                                        : Colors.orange,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                hasAccess ? Icons.arrow_forward_ios : Icons.lock_outline,
                size: 16,
                color: hasAccess ? AppColors.primary : AppColors.locked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
