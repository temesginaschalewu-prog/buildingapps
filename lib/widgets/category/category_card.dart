import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../themes/app_colors.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final bool hasSubscription;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.hasSubscription,
    required this.onTap,
  });

  Color get _statusColor {
    if (category.status == 'active') {
      if (category.isFree) {
        return AppColors.free;
      } else if (hasSubscription) {
        return AppColors.success;
      } else {
        return AppColors.primary;
      }
    } else if (category.status == 'coming_soon') {
      return AppColors.comingSoon;
    } else {
      return Colors.grey;
    }
  }

  String get _statusText {
    if (category.status == 'active') {
      if (category.isFree) {
        return 'FREE';
      } else if (hasSubscription) {
        return 'SUBSCRIBED';
      } else {
        return 'ACTIVE';
      }
    } else if (category.status == 'coming_soon') {
      return 'COMING SOON';
    } else {
      return category.status.toUpperCase();
    }
  }

  IconData get _statusIcon {
    if (category.status == 'active') {
      if (category.isFree) {
        return Icons.lock_open;
      } else if (hasSubscription) {
        return Icons.check_circle;
      } else {
        return Icons.lock;
      }
    } else if (category.status == 'coming_soon') {
      return Icons.schedule;
    } else {
      return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: category.status == 'active' ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            minHeight: isSmallScreen ? 120 : 140,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _statusColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon,
                                size: isSmallScreen ? 10 : 12,
                                color: _statusColor,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  _statusText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: _statusColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: isSmallScreen ? 10 : 12,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (category.price != null && category.price! > 0)
                        Flexible(
                          child: Text(
                            '${category.price!.toStringAsFixed(0)} Birr',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: isSmallScreen ? 16 : 18,
                          height: 1.2,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.description != null &&
                      category.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        category.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: isSmallScreen ? 11 : 12,
                              height: 1.3,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (category.status == 'active' && !category.isFree)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.billingCycle.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                      ),
                      if (hasSubscription)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.green,
                                  fontSize: isSmallScreen ? 8 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
