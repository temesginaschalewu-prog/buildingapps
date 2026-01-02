import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../themes/app_colors.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  Color get _accessColor {
    switch (course.access) {
      case 'full':
        return AppColors.success;
      case 'limited':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String get _accessText {
    switch (course.access) {
      case 'full':
        return 'FULL ACCESS';
      case 'limited':
        return 'LIMITED ACCESS';
      default:
        return course.access.toUpperCase();
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
                      color: _accessColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _accessColor),
                    ),
                    child: Text(
                      _accessText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _accessColor,
                            fontWeight: FontWeight.w600,
                          ),
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
              if (course.message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    course.message,
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
