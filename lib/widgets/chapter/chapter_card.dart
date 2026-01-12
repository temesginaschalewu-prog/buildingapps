import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';

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

  Color _getStatusColor() {
    if (chapter.accessible) {
      return AppColors.success;
    } else {
      return chapter.isFree ? Colors.orange : AppColors.locked;
    }
  }

  IconData _getStatusIcon() {
    if (chapter.accessible) {
      return Icons.play_circle_fill;
    } else {
      return chapter.isFree ? Icons.schedule : Icons.lock;
    }
  }

  String _getStatusText() {
    if (chapter.accessible) {
      return 'ACCESSIBLE';
    } else {
      return chapter.isFree ? 'COMING SOON' : 'LOCKED';
    }
  }

  void _showPaymentDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
                  'category': {
                    'id': categoryId,
                    'name': categoryName,
                  },
                  'paymentType': authProvider.user?.accountStatus == 'active'
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

    final hasAccess = chapter.isFree ||
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (hasAccess) {
            context.push('/chapter/${chapter.id}', extra: chapter);
          } else {
            _showPaymentDialog(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                          child: Text(
                            _getStatusText(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: _getStatusColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (chapter.releaseDate != null)
                          Text(
                            '${chapter.releaseDate!.day}/${chapter.releaseDate!.month}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
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
                          'Purchase "$categoryName" to unlock',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange,
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
