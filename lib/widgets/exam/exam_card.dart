import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';

class ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTap;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
  });

  Color _getStatusColor() {
    if (exam.canTakeExam) {
      return AppColors.success;
    } else if (exam.requiresPayment) {
      return AppColors.locked;
    } else if (exam.maxAttemptsReached) {
      return AppColors.error;
    } else if (exam.isUpcoming) {
      return Colors.blue;
    } else if (exam.isEnded) {
      return Colors.grey;
    }
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (exam.canTakeExam) {
      return Icons.assignment_turned_in;
    } else if (exam.requiresPayment) {
      return Icons.lock;
    } else if (exam.maxAttemptsReached) {
      return Icons.block;
    } else if (exam.isUpcoming) {
      return Icons.schedule;
    } else if (exam.isEnded) {
      return Icons.assignment_late;
    }
    return Icons.assignment;
  }

  String _getStatusText() {
    if (exam.canTakeExam) {
      return 'TAKE EXAM';
    } else if (exam.requiresPayment) {
      return 'PAYMENT REQUIRED';
    } else if (exam.maxAttemptsReached) {
      return 'MAX ATTEMPTS';
    } else if (exam.isUpcoming) {
      return 'UPCOMING';
    } else if (exam.isEnded) {
      return 'ENDED';
    } else if (exam.isInProgress) {
      return 'IN PROGRESS';
    }
    return 'AVAILABLE';
  }

  String _getTimeInfo() {
    if (exam.hasUserTimeLimit) {
      return '${exam.userTimeLimit} min/attempt';
    }

    final now = DateTime.now();
    if (now.isBefore(exam.startDate)) {
      final days = exam.startDate.difference(now).inDays;
      return 'Starts in $days ${days == 1 ? 'day' : 'days'}';
    } else if (now.isBefore(exam.endDate)) {
      final hours = exam.endDate.difference(now).inHours;
      if (hours < 24) {
        return 'Ends in $hours ${hours == 1 ? 'hour' : 'hours'}';
      }
      final days = exam.endDate.difference(now).inDays;
      return 'Ends in $days ${days == 1 ? 'day' : 'days'}';
    }
    return 'Ended';
  }

  Widget _buildTimeIndicator() {
    if (exam.hasUserTimeLimit) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 10, color: Colors.blue),
            const SizedBox(width: 2),
            Text(
              '${exam.userTimeLimit}min',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group, size: 10, color: Colors.grey),
          const SizedBox(width: 2),
          Text(
            '${exam.duration}min',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: exam.canTakeExam ? onTap : null,
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
                  _buildTimeIndicator(),
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
                  const Icon(Icons.book,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    exam.courseName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.category,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    exam.categoryName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _getTimeInfo(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (exam.attemptsTaken > 0)
                    Text(
                      '${exam.attemptsTaken}/${exam.maxAttempts} attempts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              if (exam.requiresPayment && !exam.canTakeExam)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Purchase "${exam.categoryName}" to unlock',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange,
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
