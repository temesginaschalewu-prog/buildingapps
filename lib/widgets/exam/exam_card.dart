import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../themes/app_colors.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTap;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (exam.status) {
      case 'available':
        return AppColors.success;
      case 'max_attempts_reached':
        return AppColors.error;
      case 'in_progress':
        return AppColors.warning;
      case 'upcoming':
        return AppColors.info;
      case 'ended':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (exam.status) {
      case 'available':
        return 'AVAILABLE';
      case 'max_attempts_reached':
        return 'MAX ATTEMPTS';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'upcoming':
        return 'UPCOMING';
      case 'ended':
        return 'ENDED';
      default:
        return exam.status.toUpperCase();
    }
  }

  IconData _getStatusIcon() {
    switch (exam.status) {
      case 'available':
        return Icons.play_circle_fill;
      case 'max_attempts_reached':
        return Icons.block;
      case 'in_progress':
        return Icons.hourglass_bottom;
      case 'upcoming':
        return Icons.schedule;
      case 'ended':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTakeExam = exam.canTakeExam;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: canTakeExam ? onTap : null,
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
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getStatusColor()),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          size: 12,
                          color: _getStatusColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _getStatusColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${exam.duration} min',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                exam.title,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.startDate.day}/${exam.startDate.month} - ${exam.endDate.day}/${exam.endDate.month}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.school, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      exam.courseName,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attempts: ${exam.attemptsTaken}/${exam.maxAttempts}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (!canTakeExam)
                    Text(
                      exam.message,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.error,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
