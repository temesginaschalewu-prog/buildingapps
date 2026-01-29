import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/subscription_provider.dart';
import '../../themes/app_colors.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final int categoryId;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.categoryId,
    required this.onTap,
  });

  String _getAccessText(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return 'FULL ACCESS';
    } else if (course.hasPendingPayment) {
      return 'PENDING VERIFICATION';
    } else {
      return 'LIMITED ACCESS';
    }
  }

  Color _getAccessColor(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return AppColors.success;
    } else if (course.hasPendingPayment) {
      return AppColors.info;
    } else {
      return AppColors.warning;
    }
  }

  IconData _getAccessIcon(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return Icons.check_circle;
    } else if (course.hasPendingPayment) {
      return Icons.pending;
    } else {
      return Icons.lock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final hasActiveSubscription =
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getAccessColor(hasActiveSubscription)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _getAccessColor(hasActiveSubscription)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getAccessIcon(hasActiveSubscription),
                          size: 12,
                          color: _getAccessColor(hasActiveSubscription),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getAccessText(hasActiveSubscription),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: _getAccessColor(hasActiveSubscription),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${course.chapterCount} chapters',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.name,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (course.description != null && course.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    course.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (course.message != null && course.message!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    course.message!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
