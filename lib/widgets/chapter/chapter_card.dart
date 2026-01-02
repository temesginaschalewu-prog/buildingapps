import 'package:flutter/material.dart';
import '../../models/chapter_model.dart';
import '../../themes/app_colors.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.onTap,
  });

  Color get _statusColor {
    switch (chapter.status) {
      case 'free':
        return AppColors.free;
      case 'locked':
        return AppColors.locked;
      default:
        return Colors.grey;
    }
  }

  String get _statusText {
    switch (chapter.status) {
      case 'free':
        return 'FREE';
      case 'locked':
        return 'LOCKED';
      default:
        return chapter.status.toUpperCase();
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
        onTap: chapter.accessible ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _statusColor),
                ),
                child: Icon(
                  chapter.accessible ? Icons.play_circle : Icons.lock,
                  color: _statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              if (!chapter.accessible)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
