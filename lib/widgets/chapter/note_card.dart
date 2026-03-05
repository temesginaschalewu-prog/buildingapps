import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/note_model.dart';
import '../../providers/progress_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/app_card.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final int chapterId;
  final int index;
  final VoidCallback? onTap;
  final Future<void> Function()? onDownload;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;

  const NoteCard({
    super.key,
    required this.note,
    required this.chapterId,
    required this.index,
    this.onTap,
    this.onDownload,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  late ProgressProvider _progressProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressProvider = context.read<ProgressProvider>();
    });
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.getTextSecondary(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingS(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: ResponsiveValues.iconSizeXXS(context),
            color: effectiveColor,
          ),
          SizedBox(width: ResponsiveValues.spacingXXS(context)),
          Text(
            label,
            style: AppTextStyles.caption(context).copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading...',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.telegramBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(widget.downloadProgress * 100).toInt()}%',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveValues.spacingXS(context)),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
          child: Stack(
            children: [
              Container(
                height: ResponsiveValues.progressBarHeight(context),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusSmall(context)),
                ),
              ),
              FractionallySizedBox(
                widthFactor: widget.downloadProgress,
                child: Container(
                  height: ResponsiveValues.progressBarHeight(context),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.blueGradient,
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.telegramBlue.withValues(alpha: 0.5),
                        blurRadius: ResponsiveValues.spacingXS(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadedBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingS(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramGreen.withValues(alpha: 0.2),
            AppColors.telegramGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        border: Border.all(
          color: AppColors.telegramGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.telegramGreen,
          ),
          SizedBox(width: ResponsiveValues.spacingXXS(context)),
          Text(
            'Downloaded',
            style: AppTextStyles.caption(context).copyWith(
              color: AppColors.telegramGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.note.filePath?.toLowerCase().endsWith('.pdf') ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AppCard.note(
        isDownloaded: widget.isDownloaded,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _progressProvider.saveChapterProgress(
                chapterId: widget.note.chapterId,
                notesViewed: true,
              );
              if (widget.onTap != null) {
                widget.onTap!();
              }
            },
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeXXL(context),
                    height: ResponsiveValues.iconSizeXXL(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPdf
                            ? [AppColors.telegramRed, AppColors.telegramOrange]
                            : [
                                AppColors.telegramBlue,
                                AppColors.telegramPurple
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusLarge(context)),
                      boxShadow: [
                        BoxShadow(
                          color: (isPdf
                                  ? AppColors.telegramRed
                                  : AppColors.telegramBlue)
                              .withValues(alpha: 0.3),
                          blurRadius: ResponsiveValues.spacingM(context),
                          offset:
                              Offset(0, ResponsiveValues.spacingXS(context)),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.note_alt_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingXL(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.title,
                          style: AppTextStyles.titleMedium(context).copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Row(
                          children: [
                            _buildMetadataChip(
                              icon: Icons.calendar_today_rounded,
                              label: widget.note.formattedDate,
                            ),
                            SizedBox(width: ResponsiveValues.spacingS(context)),
                            _buildMetadataChip(
                              icon: isPdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.description_rounded,
                              label: isPdf ? 'PDF' : 'Document',
                              color: isPdf
                                  ? AppColors.telegramRed
                                  : AppColors.telegramBlue,
                            ),
                          ],
                        ),
                        if (widget.isDownloading) ...[
                          SizedBox(height: ResponsiveValues.spacingL(context)),
                          _buildDownloadProgress(),
                        ],
                        if (widget.isDownloaded && !widget.isDownloading) ...[
                          SizedBox(height: ResponsiveValues.spacingL(context)),
                          _buildDownloadedBadge(),
                        ],
                      ],
                    ),
                  ),
                  if (widget.note.filePath != null &&
                      widget.note.filePath!.isNotEmpty)
                    _buildNoteActionButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildNoteActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.isDownloaded) {
            _showDeleteNoteDownloadDialog();
          } else if (!widget.isDownloading && widget.onDownload != null) {
            widget.onDownload!();
          }
        },
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        child: Container(
          padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
          decoration: BoxDecoration(
            color: widget.isDownloaded
                ? AppColors.telegramGreen.withValues(alpha: 0.1)
                : widget.isDownloading
                    ? AppColors.telegramBlue.withValues(alpha: 0.1)
                    : AppColors.getSurface(context).withValues(alpha: 0.1),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            border: Border.all(
              color: widget.isDownloaded
                  ? AppColors.telegramGreen.withValues(alpha: 0.3)
                  : widget.isDownloading
                      ? AppColors.telegramBlue.withValues(alpha: 0.3)
                      : AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            widget.isDownloaded
                ? Icons.check_circle_rounded
                : widget.isDownloading
                    ? Icons.hourglass_empty_rounded
                    : Icons.cloud_download_rounded,
            size: ResponsiveValues.iconSizeL(context),
            color: widget.isDownloaded
                ? AppColors.telegramGreen
                : widget.isDownloading
                    ? AppColors.telegramBlue
                    : AppColors.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  void _showDeleteNoteDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Download'),
        content: Text('Remove downloaded note "${widget.note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download removed')),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
