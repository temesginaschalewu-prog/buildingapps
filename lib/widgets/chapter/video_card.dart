import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/video_model.dart';
import '../../providers/video_provider.dart';
import '../../providers/progress_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';
import '../common/app_dialog.dart';
import '../../services/snackbar_service.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final int chapterId;
  final int index;
  final VoidCallback? onPlay;
  final Future<void> Function(VideoQuality? quality)? onDownload;
  final Future<VideoQuality?> Function(Video video, {bool forPlayback})?
      onShowQualitySelector;

  const VideoCard({
    super.key,
    required this.video,
    required this.chapterId,
    required this.index,
    this.onPlay,
    this.onDownload,
    this.onShowQualitySelector,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  late VideoProvider _videoProvider;
  late ProgressProvider _progressProvider;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
      _updateDownloadState();
    });
  }

  void _initProviders() {
    _videoProvider = context.read<VideoProvider>();
    _progressProvider = context.read<ProgressProvider>();

    _videoProvider.videoUpdates.listen((update) {
      if (!mounted) return;
      if (update['video_id'] == widget.video.id) {
        _updateDownloadState();
      }
    });
  }

  void _updateDownloadState() {
    if (mounted) {
      setState(() {
        _isDownloaded = _videoProvider.isVideoDownloaded(widget.video.id);
        _isDownloading = _videoProvider.isDownloading(widget.video.id);
        _downloadProgress = _videoProvider.getDownloadProgress(widget.video.id);
      });
    }
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
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: ResponsiveValues.iconSizeXXS(context),
              color: effectiveColor),
          SizedBox(width: ResponsiveValues.spacingXXS(context)),
          Text(
            label,
            style: AppTextStyles.caption(context)
                .copyWith(color: effectiveColor, fontWeight: FontWeight.w500),
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
              '${(_downloadProgress * 100).toInt()}%',
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
                widthFactor: _downloadProgress,
                child: Container(
                  height: ResponsiveValues.progressBarHeight(context),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: AppColors.blueGradient),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.telegramBlue.withValues(alpha: 0.5),
                          blurRadius: ResponsiveValues.spacingXS(context))
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

  void _showDeleteDownloadDialog() {
    AppDialog.delete(
      context: context,
      title: 'Remove Download',
      message: 'Remove downloaded video "${widget.video.title}"?',
    ).then((confirmed) {
      if (confirmed == true) {
        _videoProvider.removeDownload(widget.video.id).then((_) {
          setState(() => _isDownloaded = false);
          SnackbarService().showSuccess(context, 'Download removed');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleQualities = widget.video.hasQualities;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AppCard.video(
        isDownloaded: _isDownloaded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: widget.video.hasThumbnail
                        ? CachedNetworkImage(
                            imageUrl: widget.video.fullThumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.getSurface(context)
                                        .withValues(alpha: 0.5),
                                    AppColors.getSurface(context)
                                        .withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.movie,
                                  size: ResponsiveValues.iconSizeXL(context),
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.getSurface(context)
                                        .withValues(alpha: 0.5),
                                    AppColors.getSurface(context)
                                        .withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: ResponsiveValues.iconSizeXL(context),
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getSurface(context)
                                      .withValues(alpha: 0.5),
                                  AppColors.getSurface(context)
                                      .withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: ResponsiveValues.iconSizeXXL(context),
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7)
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: ResponsiveValues.spacingM(context),
                  right: ResponsiveValues.spacingM(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingS(context),
                      vertical: ResponsiveValues.spacingXS(context),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: ResponsiveValues.iconSizeXXS(context),
                            color: Colors.white),
                        SizedBox(width: ResponsiveValues.spacingXXS(context)),
                        Text(
                          widget.video.formattedDuration,
                          style: AppTextStyles.caption(context).copyWith(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasMultipleQualities)
                  Positioned(
                    bottom: ResponsiveValues.spacingM(context),
                    left: ResponsiveValues.spacingM(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingS(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.blueGradient),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hd,
                              size: ResponsiveValues.iconSizeXXS(context),
                              color: Colors.white),
                          SizedBox(width: ResponsiveValues.spacingXXS(context)),
                          Text(
                            'HD',
                            style: AppTextStyles.caption(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (widget.onPlay != null) {
                          widget.onPlay!();
                        } else if (widget.onShowQualitySelector != null) {
                          widget.onShowQualitySelector!
                                  (widget.video, forPlayback: true)
                              .then((quality) {
                            if (widget.onDownload != null)
                              widget.onDownload!(quality);
                          });
                        }
                      },
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Center(
                        child: Container(
                          width: ResponsiveValues.iconSizeXXL(context) * 1.5,
                          height: ResponsiveValues.iconSizeXXL(context) * 1.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.blueGradient),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.telegramBlue
                                    .withValues(alpha: 0.5),
                                blurRadius: ResponsiveValues.spacingXL(context),
                                spreadRadius:
                                    ResponsiveValues.spacingXS(context),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: AppTextStyles.titleMedium(context).copyWith(
                        fontWeight: FontWeight.w600, letterSpacing: -0.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Row(
                    children: [
                      _buildMetadataChip(
                        icon: Icons.visibility_rounded,
                        label: '${widget.video.viewCount} views',
                      ),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      _buildMetadataChip(
                        icon: Icons.calendar_today_rounded,
                        label: widget.video.createdAt
                            .toLocal()
                            .toString()
                            .split(' ')[0],
                      ),
                    ],
                  ),
                  if (_isDownloading) ...[
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    _buildDownloadProgress(),
                  ],
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingS(context),
                vertical: ResponsiveValues.spacingXS(context),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.glass(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        if (widget.onPlay != null) {
                          widget.onPlay!();
                        } else if (widget.onShowQualitySelector != null) {
                          widget.onShowQualitySelector!
                                  (widget.video, forPlayback: true)
                              .then((quality) {
                            if (widget.onDownload != null)
                              widget.onDownload!(quality);
                          });
                        }
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: ResponsiveValues.spacingXL(context),
                    color: AppColors.getDivider(context).withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: AppButton.glass(
                      label: _isDownloaded
                          ? 'Downloaded'
                          : (_isDownloading ? 'Downloading' : 'Download'),
                      icon: _isDownloaded
                          ? Icons.check_circle_rounded
                          : (_isDownloading
                              ? Icons.hourglass_empty_rounded
                              : Icons.cloud_download_rounded),
                      onPressed: _isDownloading
                          ? null
                          : () {
                              if (_isDownloaded) {
                                _showDeleteDownloadDialog();
                              } else if (widget.onShowQualitySelector != null) {
                                widget.onShowQualitySelector!
                                        (widget.video, forPlayback: false)
                                    .then((quality) {
                                  if (widget.onDownload != null)
                                    widget.onDownload!(quality);
                                });
                              } else if (widget.onDownload != null) {
                                widget.onDownload!(null);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: (widget.index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
