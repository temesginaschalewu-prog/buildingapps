// lib/widgets/chapter/video_card.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - FIXED BUTTONS & DOWNLOAD

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/video_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final int chapterId;
  final int index;
  final VoidCallback onPlay;
  final Function(VideoQuality) onDownload;
  final Future<VideoQuality?> Function(Video, {bool forPlayback})
      onShowQualitySelector;

  const VideoCard({
    super.key,
    required this.video,
    required this.chapterId,
    required this.index,
    required this.onPlay,
    required this.onDownload,
    required this.onShowQualitySelector,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard>
    with SingleTickerProviderStateMixin {
  late VideoProvider _videoProvider;
  late AnimationController _pulseController;
  VoidCallback? _providerListener;

  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  VideoQualityLevel? _downloadedQuality;
  int _viewCount = 0;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _viewCount = widget.video.viewCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _updateDownloadState();
      _providerListener = _updateDownloadState;
      _videoProvider.addListener(_providerListener!);

      _updateSubscription = _videoProvider.videoUpdates.listen((update) {
        if (!mounted) return;
        if (update['video_id'] == widget.video.id) {
          _updateDownloadState();

          if (update['type'] == 'download_progress') {
            setState(() {
              _downloadProgress = update['progress'] ?? 0.0;
            });
          } else if (update['type'] == 'view_count_updated') {
            setState(() {
              _viewCount = update['view_count'] ?? _viewCount;
            });
          }
        }
      });
    });
  }

  void _updateDownloadState() {
    if (mounted) {
      setState(() {
        _isDownloaded = _videoProvider.isVideoDownloaded(widget.video.id);
        _isDownloading = _videoProvider.isDownloading(widget.video.id);
        _downloadProgress = _videoProvider.getDownloadProgress(widget.video.id);
        _downloadedQuality = _videoProvider.getDownloadQuality(widget.video.id);
        _viewCount = _videoProvider.getViewCount(widget.video.id) > 0
            ? _videoProvider.getViewCount(widget.video.id)
            : widget.video.viewCount;
      });
    }
  }

  @override
  void dispose() {
    if (_providerListener != null) {
      _videoProvider.removeListener(_providerListener!);
    }
    _pulseController.dispose();
    _updateSubscription?.cancel();
    super.dispose();
  }

  Widget _buildThumbnailFallback(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramBlue.withValues(alpha: 0.3),
            AppColors.telegramPurple.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.ondemand_video_rounded,
          color: Colors.white.withValues(alpha: 0.9),
          size: isTablet ? 54 : 42,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qualities = widget.video.availableQualities;
    final hasQualities = qualities.length > 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth >= 1024;
    final downloadedQualityLabel = _downloadedQuality?.label;
    final settingsProvider = context.read<SettingsProvider>();

    return AppCard.video(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with overlay - ENTIRE AREA IS CLICKABLE
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDownloading ? null : widget.onPlay,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              splashColor: AppColors.telegramBlue.withValues(alpha: 0.3),
              highlightColor: Colors.transparent,
              child: Stack(
                children: [
                  SizedBox(
                    height: isDesktop
                        ? 188
                        : (isTablet ? 214 : 172),
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                          if (widget.video.hasThumbnail)
                            CachedNetworkImage(
                              imageUrl: widget.video.fullThumbnailUrl!,
                              fit: BoxFit.contain,
                              fadeInDuration: const Duration(milliseconds: 180),
                              placeholder: (_, __) =>
                                  _buildThumbnailFallback(isTablet),
                              errorWidget: (_, __, ___) =>
                                  _buildThumbnailFallback(isTablet),
                            )
                          else
                            _buildThumbnailFallback(isTablet),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.black.withValues(alpha: 0.36),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Center(
                    child: Container(
                      width: isTablet ? 76 : 60,
                      height: isTablet ? 76 : 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: isTablet ? 48 : 40,
                      ),
                    ),
                  ),

                  // Duration badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.video.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Quality badges
                  if (hasQualities)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: qualities.take(4).map((q) {
                          final isRecommended = q.label ==
                              widget.video.getRecommendedQuality().label;
                          final isDownloadedQuality =
                              _isDownloaded && downloadedQualityLabel == q.label;
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDownloadedQuality
                                  ? AppColors.telegramGreen
                                  : Colors.white.withValues(
                                      alpha: isRecommended ? 0.36 : 0.22,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDownloadedQuality
                                    ? AppColors.telegramGreen.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              q.label,
                              style: TextStyle(
                                color: isDownloadedQuality
                                    ? Colors.white
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: (isRecommended || isDownloadedQuality)
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Downloading overlay
                  if (_isDownloading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale:
                                    Tween<double>(begin: 0.8, end: 1.2).animate(
                                  CurvedAnimation(
                                    parent: _pulseController,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.cloud_download_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                settingsProvider.getVideoDownloadingMessage(
                                  (_downloadProgress * 100).toInt(),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  value: _downloadProgress,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF0088CC)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveValues.spacingM(context),
              ResponsiveValues.spacingM(context),
              ResponsiveValues.spacingM(context),
              ResponsiveValues.spacingS(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),

                // Metadata row
                Row(
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: AppColors.getTextSecondary(context),
                    ),
                    SizedBox(width: ResponsiveValues.spacingXXS(context)),
                    Text(
                      '$_viewCount views',
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Icon(
                      Icons.hd_rounded,
                      size: 16,
                      color: hasQualities
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
                    ),
                    SizedBox(width: ResponsiveValues.spacingXXS(context)),
                    Text(
                      '${qualities.length} quality${qualities.length > 1 ? 'ies' : ''}',
                      style: AppTextStyles.caption(context).copyWith(
                        color: hasQualities
                            ? AppColors.telegramBlue
                            : AppColors.getTextSecondary(context),
                        fontWeight: hasQualities ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons - BIGGER HIT TARGETS
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.getDivider(context).withValues(alpha: 0.75),
                ),
              ),
            ),
            child: Row(
              children: [
                // Play button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: _isDownloading ? null : widget.onPlay,
                      style: TextButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: _isDownloading
                                ? Colors.grey
                                : AppColors.telegramBlue,
                            size: 24,
                          ),
                          SizedBox(width: ResponsiveValues.spacingXS(context)),
                          Text(
                            'Play',
                            style: AppTextStyles.labelLarge(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: _isDownloading
                                  ? Colors.grey
                                  : AppColors.telegramBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 56,
                  color: AppColors.getDivider(context),
                ),
                // Download button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: _isDownloading
                          ? _showCancelDownloadDialog
                          : () async {
                              if (_isDownloaded) {
                                _showDeleteDialog();
                              } else {
                                final connectivity =
                                    context.read<ConnectivityService>();
                                if (!connectivity.isOnline) {
                                  SnackbarService()
                                      .showOffline(context, action: 'download');
                                  return;
                                }

                                final quality =
                                    await widget.onShowQualitySelector(
                                  widget.video,
                                  forPlayback: false,
                                );
                                if (quality != null) {
                                  widget.onDownload(quality);
                                }
                              }
                            },
                      style: TextButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDownloaded
                                ? Icons.delete_outline_rounded
                                : (_isDownloading
                                    ? Icons.hourglass_empty
                                    : Icons.download_rounded),
                            color: _isDownloaded
                                ? AppColors.telegramRed
                                : (_isDownloading
                                    ? Colors.orange
                                    : AppColors.telegramBlue),
                            size: 24,
                          ),
                          SizedBox(width: ResponsiveValues.spacingXS(context)),
                          Text(
                            _isDownloaded
                                ? 'Remove'
                                : (_isDownloading ? 'Downloading' : 'Download'),
                            style: AppTextStyles.labelLarge(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: _isDownloaded
                                  ? AppColors.telegramRed
                                  : (_isDownloading
                                      ? Colors.orange
                                      : AppColors.telegramBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settingsProvider.getVideoRemoveDownloadTitle()),
        content: Text(
          settingsProvider.getVideoRemoveDownloadMessage(widget.video.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _videoProvider.removeDownloadedVideo(widget.video.id);
              SnackbarService().showSuccess(
                context,
                settingsProvider.getVideoDownloadRemovedMessage(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showCancelDownloadDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settingsProvider.getVideoCancelDownloadTitle()),
        content: Text(
          settingsProvider.getVideoCancelDownloadMessage(widget.video.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _videoProvider.cancelDownload(widget.video.id);
              SnackbarService().showInfo(
                context,
                settingsProvider.getVideoDownloadCancelledMessage(),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
