import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../themes/app_colors.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  Color get _statusColor {
    switch (category.status) {
      case 'active':
        return category.isFree ? AppColors.free : AppColors.primary;
      case 'coming_soon':
        return AppColors.comingSoon;
      default:
        return Colors.grey;
    }
  }

  String get _statusText {
    switch (category.status) {
      case 'active':
        return category.isFree ? 'FREE' : 'ACTIVE';
      case 'coming_soon':
        return 'COMING SOON';
      default:
        return category.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: category.status == 'active' ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _statusColor),
                        ),
                        child: Text(
                          _statusText,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      if (category.price != null && category.price! > 0)
                        Text(
                          '${category.price} Birr',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category.description != null &&
                      category.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        category.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (category.status == 'active' && !category.isFree)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    category.billingCycle.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
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
