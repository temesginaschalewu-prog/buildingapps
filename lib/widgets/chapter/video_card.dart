// lib/widgets/chapter/video_card.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - FIXED BUTTONS & DOWNLOAD

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../providers/video_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../common/app_card.dart';
import '../common/app_dialog.dart';

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

  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoProvider = context.read<VideoProvider>();
      _updateDownloadState();

      _updateSubscription = _videoProvider.videoUpdates.listen((update) {
        if (!mounted) return;
        if (update['video_id'] == widget.video.id) {
          _updateDownloadState();

          if (update['type'] == 'download_progress') {
            setState(() {
              _downloadProgress = update['progress'] ?? 0.0;
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
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qualities = widget.video.availableQualities;
    final hasQualities = qualities.length > 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

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
                  // Thumbnail placeholder
                  Container(
                    height: isTablet ? 220 : 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramBlue.withValues(alpha: 0.3),
                          AppColors.telegramPurple.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: isTablet ? 80 : 64,
                        height: isTablet ? 80 : 64,
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
                        children: qualities.take(3).map((q) {
                          final isRecommended = q.label ==
                              widget.video.getRecommendedQuality().label;
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: isRecommended
                                  ? const LinearGradient(colors: [
                                      Color(0xFF0088CC),
                                      Color(0xFF0055AA)
                                    ])
                                  : null,
                              color: isRecommended ? null : Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              q.label,
                              style: TextStyle(
                                color: isRecommended
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 10,
                                fontWeight:
                                    isRecommended ? FontWeight.bold : null,
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
                                'Downloading... ${(_downloadProgress * 100).toInt()}%',
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

                  // Downloaded badge
                  if (_isDownloaded && !_isDownloading)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Downloaded',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 8),

                // Metadata row
                Row(
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.video.viewCount} views',
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.hd_rounded,
                      size: 16,
                      color: hasQualities
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
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

                // Download progress bar (when downloading)
                if (_isDownloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0088CC)),
                  ),
                  const SizedBox(height: 4),
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
                ],
              ],
            ),
          ),

          // Action buttons - BIGGER HIT TARGETS
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.getDivider(context)),
              ),
            ),
            child: Row(
              children: [
                // Play button
                Expanded(
                  child: Container(
                    height: 56,
                    child: TextButton(
                      onPressed: _isDownloading ? null : widget.onPlay,
                      style: TextButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          const SizedBox(width: 8),
                          Text(
                            'Play',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
                  child: Container(
                    height: 56,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isDownloaded
                                ? Icons.check_circle
                                : (_isDownloading
                                    ? Icons.hourglass_empty
                                    : Icons.download_rounded),
                            color: _isDownloaded
                                ? Colors.green
                                : (_isDownloading
                                    ? Colors.orange
                                    : AppColors.telegramBlue),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isDownloaded
                                ? 'Downloaded'
                                : (_isDownloading ? 'Downloading' : 'Download'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _isDownloaded
                                  ? Colors.green
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Download'),
        content: Text('Remove "${widget.video.title}" from your downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _videoProvider.removeDownloadedVideo(widget.video.id);
              SnackbarService().showSuccess(context, 'Download removed');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showCancelDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text('Cancel downloading "${widget.video.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _videoProvider.cancelDownload(widget.video.id);
              SnackbarService().showInfo(context, 'Download cancelled');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
