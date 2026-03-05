import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;

import '../../models/chapter_model.dart';
import '../../models/video_model.dart';
import '../../models/note_model.dart';
import '../../models/question_model.dart';
import '../../models/course_model.dart';
import '../../models/category_model.dart';

import '../../providers/video_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';

import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';

import '../../widgets/chapter/video_card.dart';
import '../../widgets/chapter/note_card.dart';
import '../../widgets/chapter/practice_question_card.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';

import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';

class ChapterContentScreen extends StatefulWidget {
  final int chapterId;
  final Chapter? chapter;
  final Course? course;
  final Category? category;
  final bool? hasAccess;

  const ChapterContentScreen({
    super.key,
    required this.chapterId,
    this.chapter,
    this.course,
    this.category,
    this.hasAccess,
  });

  @override
  State<ChapterContentScreen> createState() => _ChapterContentScreenState();
}

class _ChapterContentScreenState extends State<ChapterContentScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  Chapter? _chapter;
  Course? _course;
  Category? _category;

  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isCheckingAccess = true;
  String? _errorMessage;

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  media_kit.Player? _mediaKitPlayer;
  media_kit_video.VideoController? _mediaKitVideoController;
  int? _currentPlayingVideoId;
  bool _isPlayingVideo = false;
  bool _isVideoDialogOpen = false;
  bool _useMediaKit =
      !Platform.isLinux && (Platform.isMacOS || Platform.isWindows);
  bool _isPlayerInitialized = false;

  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _showExplanation = {};
  final Map<int, bool> _isQuestionCorrect = {};
  final Map<int, bool> _questionAnswered = {};
  bool _showAllExplanations = false;

  final Map<int, String> _cachedVideoPaths = {};
  final Map<int, String> _cachedNotePaths = {};
  final Map<int, bool> _isDownloading = {};
  final Map<int, double> _downloadProgress = {};
  final Map<int, VideoQuality> _downloadQuality = {};
  final Dio _dio = Dio();

  StreamSubscription? _videoUpdateSubscription;
  StreamSubscription? _noteUpdateSubscription;
  StreamSubscription? _questionUpdateSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _refreshTimer;

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    if (_useMediaKit) {
      try {
        media_kit.MediaKit.ensureInitialized();
        debugLog('ChapterContent', 'MediaKit initialized for desktop');
      } catch (e) {
        debugLog('ChapterContent', 'MediaKit init error: $e');
        _useMediaKit = false;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    _setupConnectivityListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupStreamListeners();
    _getCurrentUserId();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOffline = !isOnline);
        if (isOnline && !_isRefreshing && _chapter != null) {
          _refreshInBackground();
        }
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  @override
  void dispose() {
    _disposeAllPlayers();
    _cleanupResources();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _disposeAllPlayers() {
    _isVideoDialogOpen = false;
    _isPlayingVideo = false;
    _isPlayerInitialized = false;

    try {
      if (_mediaKitPlayer != null) {
        _mediaKitPlayer?.pause();
        _mediaKitPlayer?.dispose();
        _mediaKitPlayer = null;
      }
    } finally {
      _mediaKitVideoController = null;
    }

    try {
      if (_chewieController != null) {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;
      }
      if (_videoController != null) {
        _videoController?.pause();
        _videoController?.dispose();
        _videoController = null;
      }
    } catch (e) {}

    try {
      WakelockPlus.disable();
    } catch (e) {}

    _currentPlayingVideoId = null;
  }

  void _cleanupResources() {
    _refreshTimer?.cancel();
    _videoUpdateSubscription?.cancel();
    _noteUpdateSubscription?.cancel();
    _questionUpdateSubscription?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _dio.close();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    await _loadCachedContent();
    await _initializeFromCache();

    if (_chapter != null && _hasCachedData) {
      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
      if (!_isOffline) {
        _refreshInBackground();
      }
    } else {
      await _checkAccessAndLoadData();
    }

    if (!_isOffline) {
      _setupBackgroundRefresh();
    }
  }

  Future<Directory> _getAppCacheDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/.familyacademy_cache/videos');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  Future<void> _loadCachedContent() async {
    if (_currentUserId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final videoPaths = await deviceService.getCacheItem<Map<String, dynamic>>(
          'cached_videos_chapter_${widget.chapterId}_$_currentUserId',
          isUserSpecific: true);
      if (videoPaths != null) {
        for (final entry in videoPaths.entries) {
          final videoId = int.tryParse(entry.key);
          final videoPath = entry.value as String?;
          if (videoId != null && videoPath != null) {
            final file = File(videoPath);
            if (await file.exists()) {
              _cachedVideoPaths[videoId] = videoPath;
            }
          }
        }
      }

      final notePaths = await deviceService.getCacheItem<Map<String, dynamic>>(
          'cached_notes_chapter_${widget.chapterId}_$_currentUserId',
          isUserSpecific: true);
      if (notePaths != null) {
        for (final entry in notePaths.entries) {
          final noteId = int.tryParse(entry.key);
          final notePath = entry.value as String?;
          if (noteId != null && notePath != null) {
            final file = File(notePath);
            if (await file.exists()) _cachedNotePaths[noteId] = notePath;
          }
        }
      }

      final qualities = await deviceService.getCacheItem<Map<String, dynamic>>(
          'download_qualities_chapter_${widget.chapterId}_$_currentUserId',
          isUserSpecific: true);
      if (qualities != null) {
        qualities.forEach((key, value) {
          final videoId = int.tryParse(key);
          if (videoId != null) {
            _downloadQuality[videoId] = VideoQuality(
              label: value.toString(),
              url: '',
              height: _getHeightFromLabel(value.toString()),
            );
          }
        });
      }

      debugLog('ChapterContent',
          'Loaded ${_cachedVideoPaths.length} cached videos, ${_cachedNotePaths.length} cached notes');
    } catch (e) {
      debugLog('ChapterContent', 'Error loading cache: $e');
    }
  }

  int _getHeightFromLabel(String label) {
    switch (label) {
      case '360p':
        return 360;
      case '480p':
        return 480;
      case '720p':
        return 720;
      case '1080p':
        return 1080;
      default:
        return 480;
    }
  }

  Future<void> _initializeFromCache() async {
    final chapterProvider = context.read<ChapterProvider>();
    final courseProvider = context.read<CourseProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (widget.chapter != null) {
      _chapter = widget.chapter;
      _course = widget.course;
      _category = widget.category;
      _hasAccess = widget.hasAccess ?? false;
      _hasCachedData = true;
      return;
    }

    for (final category in categoryProvider.categories) {
      final courses = courseProvider.getCoursesByCategory(category.id);
      for (final course in courses) {
        final chapters = chapterProvider.getChaptersByCourse(course.id);
        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            _chapter = chapter;
            _course = course;
            _category = category;
            _hasCachedData = true;
            break;
          }
        }
        if (_chapter != null) break;
      }
      if (_chapter != null) break;
    }

    if (_category != null) {
      _hasAccess =
          subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
      if (mounted) SnackbarService().showSuccess(context, 'Content updated');
    } catch (e) {
      setState(() => _isOffline = true);
      if (mounted) {
        SnackbarService()
            .showError(context, 'Refresh failed, using cached data');
      }
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _checkAccessAndLoadData({bool forceRefresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!authProvider.isAuthenticated) {
      _errorMessage = 'Authentication required';
      setState(() => _isCheckingAccess = false);
      return;
    }

    if (_chapter == null) await _loadChapterData(forceRefresh);
    if (_chapter == null) {
      _errorMessage = 'Chapter not found';
      setState(() => _isCheckingAccess = false);
      return;
    }

    if (_chapter!.isFree) {
      _hasAccess = true;
    } else if (_category != null) {
      if (!_isOffline && forceRefresh) {
        _hasAccess = await subscriptionProvider
            .checkHasActiveSubscriptionForCategory(_category!.id);
      } else {
        _hasAccess = subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);
      }
    } else {
      _hasAccess = false;
    }

    setState(() => _isCheckingAccess = false);

    if (_hasAccess) {
      await _loadContent(forceRefresh: forceRefresh && !_isOffline);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadChapterData(bool forceRefresh) async {
    final chapterProvider = context.read<ChapterProvider>();
    final courseProvider = context.read<CourseProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    if (categoryProvider.categories.isEmpty) {
      await categoryProvider.loadCategories(
          forceRefresh: forceRefresh && !_isOffline);
    }

    for (final category in categoryProvider.categories) {
      if (!courseProvider.hasLoadedCategory(category.id)) {
        await courseProvider.loadCoursesByCategory(category.id,
            forceRefresh: forceRefresh && !_isOffline);
      }

      final courses = courseProvider.getCoursesByCategory(category.id);
      for (final course in courses) {
        if (!chapterProvider.hasLoadedForCourse(course.id)) {
          await chapterProvider.loadChaptersByCourse(course.id,
              forceRefresh: forceRefresh && !_isOffline);
        }

        final chapters = chapterProvider.getChaptersByCourse(course.id);
        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            _chapter = chapter;
            _course = course;
            _category = category;
            return;
          }
        }
      }
    }
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    final videoProvider = context.read<VideoProvider>();
    final noteProvider = context.read<NoteProvider>();
    final questionProvider = context.read<QuestionProvider>();

    try {
      await Future.wait([
        videoProvider.loadVideosByChapter(widget.chapterId,
            forceRefresh: forceRefresh),
        noteProvider.loadNotesByChapter(widget.chapterId,
            forceRefresh: forceRefresh),
        questionProvider.loadPracticeQuestions(widget.chapterId,
            forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      setState(() => _isOffline = true);
    }
  }

  void _setupBackgroundRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (mounted && _hasAccess && !_isRefreshing && !_isOffline) {
        await _refreshInBackground();
      }
    });
  }

  void _setupStreamListeners() {
    final videoProvider = context.read<VideoProvider>();
    final noteProvider = context.read<NoteProvider>();
    final questionProvider = context.read<QuestionProvider>();

    _videoUpdateSubscription = videoProvider.videoUpdates
        .listen((_) => mounted ? setState(() {}) : null);
    _noteUpdateSubscription = noteProvider.noteUpdates
        .listen((_) => mounted ? setState(() {}) : null);
    _questionUpdateSubscription = questionProvider.questionUpdates
        .listen((_) => mounted ? setState(() {}) : null);
  }

  void _pauseVideo() {
    if (!_isPlayingVideo || _isVideoDialogOpen) return;
    try {
      if (_useMediaKit) {
        if (_mediaKitPlayer?.state.playing == true) _mediaKitPlayer?.pause();
      } else {
        if (_chewieController?.isPlaying == true) _chewieController?.pause();
      }
    } catch (e) {}
    try {
      WakelockPlus.disable();
    } catch (e) {}
  }

  void _resumeVideoIfNeeded() {
    if (!_isPlayingVideo || _isVideoDialogOpen || !_isPlayerInitialized) return;
    try {
      if (_useMediaKit) {
        if (_mediaKitPlayer != null && !_mediaKitPlayer!.state.playing) {
          _mediaKitPlayer?.play();
        }
      } else {
        if (_chewieController != null && !_chewieController!.isPlaying) {
          _chewieController?.play();
        }
      }
    } catch (e) {}
    try {
      WakelockPlus.enable();
    } catch (e) {}
  }

  void _showDeleteDownloadDialog(Video video) {
    AppDialog.delete(
      context: context,
      title: 'Remove Download',
      message: 'Remove downloaded video "${video.title}"?',
    ).then((confirmed) {
      if (confirmed == true) {
        final videoProvider = context.read<VideoProvider>();
        videoProvider.removeDownload(video.id).then((_) {
          setState(() {
            _cachedVideoPaths.remove(video.id);
            _downloadQuality.remove(video.id);
          });
          SnackbarService().showSuccess(context, 'Download removed');
        });
      }
    });
  }

  /// 🔵 FIXED: Quality selector now properly handles "Recommended" option
  Future<VideoQuality?> _showQualitySelector(Video video,
      {bool forPlayback = false}) async {
    if (_cachedVideoPaths.containsKey(video.id)) return null;

    final availableQualities = video.availableQualities;

    if (availableQualities.isEmpty) {
      return VideoQuality(label: '480p', url: video.fullVideoUrl, height: 480);
    }

    final recommendedQuality = video.getRecommendedQuality();
    final currentQuality = _downloadQuality[video.id] ??
        (forPlayback ? recommendedQuality : availableQualities.first);

    final Completer<VideoQuality?> completer = Completer();

    bool didSelectQuality = false;

    await AppDialog.showBottomSheet(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  forPlayback ? 'Select Quality' : 'Download Quality',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppButton.icon(
                  icon: Icons.close,
                  onPressed: () {
                    Navigator.pop(context);
                    completer.complete(null);
                  },
                ),
              ],
            ),
          ),
          if (forPlayback) ...[
            _buildQualityOption(
              context,
              quality: null,
              label: 'Auto (Recommended)',
              subtitle:
                  '${recommendedQuality.label} - Optimized for your connection',
              isSelected: currentQuality.label == recommendedQuality.label,
              onTap: () {
                didSelectQuality = true;
                Navigator.pop(context);
                // Return the recommended quality
                completer.complete(recommendedQuality);
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          ...availableQualities.map(
            (quality) => _buildQualityOption(
              context,
              quality: quality,
              label: quality.label,
              subtitle: _getQualityDescription(quality),
              isSelected: currentQuality.label == quality.label,
              onTap: () {
                didSelectQuality = true;
                Navigator.pop(context);
                completer.complete(quality);
              },
            ),
          ),
          const ResponsiveSizedBox(height: AppSpacing.l),
          Padding(
            padding: ResponsiveValues.screenPadding(context),
            child: AppButton.outline(
              label: 'Cancel',
              onPressed: () {
                Navigator.pop(context);
                completer.complete(null);
              },
              expanded: true,
            ),
          ),
          const ResponsiveSizedBox(height: AppSpacing.s),
        ],
      ),
    );

    if (!didSelectQuality && !completer.isCompleted) {
      completer.complete(null);
    }

    return completer.future;
  }

  Widget _buildQualityOption(
    BuildContext context, {
    required VideoQuality? quality,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: ResponsiveValues.listItemPadding(context),
          child: Row(
            children: [
              Container(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.telegramBlue.withValues(alpha: 0.1)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    quality?.height.toString() ?? 'A',
                    style: AppTextStyles.labelMedium(context).copyWith(
                      color: isSelected
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const ResponsiveSizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.telegramBlue
                            : AppColors.getTextPrimary(context),
                      ),
                    ),
                    const ResponsiveSizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: const BoxDecoration(
                    color: AppColors.telegramBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityDescription(VideoQuality quality) {
    switch (quality.height) {
      case 360:
        return 'Low - Good for mobile data';
      case 480:
        return 'Medium - Balanced quality';
      case 720:
        return 'High - HD quality';
      case 1080:
        return 'Highest - Full HD';
      default:
        return '${quality.height}p';
    }
  }

  Future<void> _playVideo(Video video) async {
    if (_isVideoDialogOpen) return;

    // Handle local files
    if (_cachedVideoPaths.containsKey(video.id)) {
      final localPath = _cachedVideoPaths[video.id]!;
      debugLog('VideoCard', 'Playing from local file: $localPath');

      // For local files, always use video_player (more reliable)
      _useMediaKit = false;
      final uri = Uri.file(localPath);
      _playWithUrl(video, uri.toString());
      return;
    }

    VideoQuality? selectedQuality;

    if (video.hasQualities) {
      selectedQuality = await _showQualitySelector(video, forPlayback: true);
      if (selectedQuality == null) {
        // If user cancelled, use recommended quality
        selectedQuality = video.getRecommendedQuality();
      }
    } else {
      selectedQuality = video.getRecommendedQuality();
    }

    if (selectedQuality == null) {
      debugLog('VideoCard', 'Playback cancelled by user');
      return;
    }

    final String videoUrl = selectedQuality.url;
    debugLog('VideoCard', 'Playing from URL: $videoUrl');

    // Try with current player, fallback to other if it fails
    try {
      await _playWithUrl(video, videoUrl);
    } catch (e) {
      debugLog('VideoCard', 'Primary player failed: $e, trying fallback');
      // Toggle player and retry
      _useMediaKit = !_useMediaKit;
      await _playWithUrl(video, videoUrl);
    }
  }

  Future<void> _playWithUrl(Video video, String videoUrl) async {
    _disposeAllPlayers();

    try {
      setState(() {
        _currentPlayingVideoId = video.id;
        _isPlayingVideo = true;
        _isVideoDialogOpen = true;
        _isPlayerInitialized = false;
      });

      debugLog('VideoCard', 'Playing URL: $videoUrl');

      if (_useMediaKit) {
        await _playWithMediaKit(video, videoUrl);
      } else {
        await _playWithVideoPlayer(video, videoUrl);
      }
    } catch (e) {
      setState(() {
        _isVideoDialogOpen = false;
        _isPlayingVideo = false;
        _isPlayerInitialized = false;
      });

      if (_useMediaKit) {
        _useMediaKit = false;
        await _playVideo(video);
      } else {
        if (mounted) {
          SnackbarService().showError(context, 'Failed to play video: $e');
        }
      }
    }
  }

  /// 🔵 CROSS-PLATFORM: Bulletproof MediaKit player with proper error handling
  Future<void> _playWithMediaKit(Video video, String videoUrl) async {
    // Always dispose previous player first
    _disposeAllPlayers();

    try {
      _mediaKitPlayer = media_kit.Player();
      _mediaKitVideoController =
          media_kit_video.VideoController(_mediaKitPlayer!);

      // Set up error handler with proper null checks
      _mediaKitPlayer!.stream.error.listen((error) {
        debugLog('VideoCard', 'MediaKit error: $error');
        if (mounted) {
          // On error, fall back to video_player
          _useMediaKit = false;
          SnackbarService()
              .showInfo(context, 'Switching to alternate player...');
          _playVideo(video);
        }
      });

      // Set playback options
      await _mediaKitPlayer!.open(media_kit.Media(videoUrl), play: true);
      await _mediaKitPlayer!.setVolume(1.0);
      await _mediaKitPlayer!.setRate(1.0);

      if (!mounted) return;

      setState(() => _isPlayerInitialized = true);

      // Enable wakelock on all platforms
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugLog('VideoCard', 'Wakelock error (non-critical): $e');
      }

      if (!mounted) return;

      // Create dialog with proper context handling
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Create local references to avoid closure issues
          final player = _mediaKitPlayer;
          final videoController = _mediaKitVideoController;

          return Dialog(
            insetPadding: EdgeInsets.all(
              ScreenSize.responsiveDouble(
                context: dialogContext,
                mobile: 8, // Smaller on mobile
                tablet: 16,
                desktop: 32,
              ),
            ),
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusLarge(dialogContext)),
              child: Stack(
                children: [
                  if (videoController != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: media_kit_video.Video(
                        controller: videoController,
                        controls: media_kit_video.MaterialVideoControls,
                      ),
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  Positioned(
                    top: ResponsiveValues.spacingM(dialogContext),
                    right: ResponsiveValues.spacingM(dialogContext),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          // Clean up player
                          if (player != null) {
                            try {
                              player.pause();
                              player.dispose();
                            } catch (e) {
                              debugLog(
                                  'VideoCard', 'Error disposing player: $e');
                            }
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            _onVideoClosed(video);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugLog('VideoCard', 'Error in _playWithMediaKit: $e');
      if (mounted) {
        // Try fallback to video_player
        _useMediaKit = false;
        await _playWithVideoPlayer(video, videoUrl);
      }
    }
  }

  /// 🔵 FIXED: Cross-platform video_player implementation
  Future<void> _playWithVideoPlayer(Video video, String videoUrl) async {
    try {
      // Dispose any existing controllers
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }

      String fixedUrl = videoUrl;

      // Handle different URL types
      if (fixedUrl.startsWith('file://')) {
        // Local file
        final filePath = fixedUrl.replaceFirst('file://', '');
        _videoController = VideoPlayerController.file(File(filePath));
      } else if (fixedUrl.startsWith('http')) {
        // Network URL
        try {
          final uri = Uri.parse(fixedUrl);
          _videoController = VideoPlayerController.networkUrl(uri);
        } catch (e) {
          debugLog('VideoCard', 'URL parsing error: $e');
          _videoController = VideoPlayerController.network(
            Uri.encodeFull(fixedUrl),
          );
        }
      } else {
        // Assume it's a file path
        _videoController = VideoPlayerController.file(File(fixedUrl));
      }

      // Initialize with timeout
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timeout');
        },
      );

      if (!mounted) return;

      // Create Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.telegramBlue,
          handleColor: AppColors.telegramBlue,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          bufferedColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        placeholder: Container(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: AppTextStyles.bodySmall(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.telegramRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading video: $errorMessage',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      setState(() => _isPlayerInitialized = true);

      // Enable wakelock
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugLog('VideoCard', 'Wakelock error (non-critical): $e');
      }

      if (!mounted) return;

      // Show video dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final chewieController = _chewieController;

          return Dialog(
            insetPadding: EdgeInsets.all(
              ScreenSize.responsiveDouble(
                context: dialogContext,
                mobile: 8,
                tablet: 16,
                desktop: 32,
              ),
            ),
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusLarge(dialogContext)),
              child: Stack(
                children: [
                  if (chewieController != null &&
                      chewieController
                          .videoPlayerController.value.isInitialized)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Chewie(controller: chewieController),
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  Positioned(
                    top: ResponsiveValues.spacingM(dialogContext),
                    right: ResponsiveValues.spacingM(dialogContext),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          if (_chewieController != null) {
                            try {
                              _chewieController?.pause();
                            } catch (e) {}
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            _onVideoClosed(video);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugLog('VideoCard', 'Error in _playWithVideoPlayer: $e');
      if (mounted) {
        SnackbarService().showError(
          context,
          'Failed to play video. Please try downloading first.',
        );
      }
      rethrow;
    }
  }

  Future<void> _onVideoClosed(Video video) async {
    setState(() => _isVideoDialogOpen = false);

    try {
      final videoProvider = context.read<VideoProvider>();
      final progressProvider = context.read<ProgressProvider>();

      int progress = 0;
      if (_useMediaKit && _mediaKitPlayer != null) {
        try {
          final position = _mediaKitPlayer!.state.position;
          final duration = _mediaKitPlayer!.state.duration;
          progress = duration.inSeconds > 0
              ? (position.inSeconds / duration.inSeconds * 100).toInt()
              : 0;
        } catch (e) {}
      } else if (_videoController != null &&
          _videoController!.value.isInitialized) {
        try {
          final position = _videoController!.value.position;
          final duration = _videoController!.value.duration;
          progress = duration.inSeconds > 0
              ? (position.inSeconds / duration.inSeconds * 100).toInt()
              : 0;
        } catch (e) {}
      }

      await progressProvider.saveChapterProgress(
          chapterId: widget.chapterId, videoProgress: progress);
      if (progress >= 30) await videoProvider.incrementViewCount(video.id);
    } finally {
      _disposeAllPlayers();
    }
  }

  Future<void> _showDownloadQualityDialog(Video video) async {
    if (_cachedVideoPaths.containsKey(video.id)) {
      _showDeleteDownloadDialog(video);
      return;
    }

    final selectedQuality = await _showQualitySelector(video);

    if (selectedQuality != null) {
      setState(() {
        _downloadQuality[video.id] = selectedQuality;
      });
      _downloadVideo(video);
    }
  }

  Future<void> _downloadVideo(Video video) async {
    if (_isDownloading[video.id] == true) return;
    if (_currentUserId == null) {
      SnackbarService().showError(context, 'Please login to download');
      return;
    }

    final quality = _downloadQuality[video.id] ??
        VideoQuality(label: '480p', url: video.fullVideoUrl, height: 480);

    setState(() {
      _isDownloading[video.id] = true;
      _downloadProgress[video.id] = 0.0;
    });

    try {
      final cacheDir = await _getAppCacheDirectory();
      final fileName =
          'vid_${video.id}_${quality.height}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${cacheDir.path}/$fileName';

      // 🔵 FIX: Ensure download URL is properly formatted
      String downloadUrl = quality.url;

      // Fix common URL issues
      if (downloadUrl.startsWith('https:/') &&
          !downloadUrl.startsWith('https://')) {
        downloadUrl = downloadUrl.replaceFirst('https:/', 'https://');
      }
      if (downloadUrl.startsWith('http:/') &&
          !downloadUrl.startsWith('http://')) {
        downloadUrl = downloadUrl.replaceFirst('http:/', 'http://');
      }

      debugLog('VideoCard', 'Downloading from: $downloadUrl');

      // Create a cancel token for potential cancellation
      final cancelToken = CancelToken();

      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          headers: {
            'Accept-Encoding': 'identity',
            'User-Agent': 'FamilyAcademy/1.0',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress[video.id] = received / total);
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Download failed - file not created');
      }

      // Verify file size
      final fileSize = await file.length();
      if (fileSize < 1024) {
        // Less than 1KB - probably an error page
        await file.delete();
        throw Exception(
            'Downloaded file is too small ($fileSize bytes) - possibly an error page');
      }

      setState(() {
        _cachedVideoPaths[video.id] = filePath;
        _isDownloading[video.id] = false;
        _downloadProgress.remove(video.id);
      });

      await _saveCacheMetadata();

      if (mounted) {
        SnackbarService().showSuccess(context,
            '${quality.label} video downloaded (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      }
    } on DioException catch (e) {
      String errorMessage = 'Download failed';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout - check your internet';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Receive timeout - server too slow';
      } else if (e.type == DioExceptionType.cancel) {
        errorMessage = 'Download cancelled';
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'Video not found on server';
      } else if (e.response?.statusCode == 403) {
        errorMessage = 'Access denied to video';
      } else {
        errorMessage = 'Network error: ${e.message}';
      }

      if (mounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        SnackbarService().showError(context, errorMessage);
      }
      debugLog('VideoCard', 'Download error: $e');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        SnackbarService()
            .showError(context, 'Download failed: ${e.toString()}');
      }
      debugLog('VideoCard', 'Download error: $e');
    }
  }

  Future<void> _downloadNote(Note note) async {
    if (_isDownloading[note.id] == true) return;
    if (_currentUserId == null) {
      SnackbarService().showError(context, 'Please login to download');
      return;
    }

    setState(() {
      _isDownloading[note.id] = true;
      _downloadProgress[note.id] = 0.0;
    });

    try {
      if (note.filePath == null || note.filePath!.isEmpty) {
        SnackbarService().showError(context, 'Note has no downloadable file');
        setState(() {
          _isDownloading[note.id] = false;
          _downloadProgress.remove(note.id);
        });
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final cacheDir =
          Directory('${appDocDir.path}/.familyacademy_cache/notes');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final fullFilePath = note.fullNoteFilePath;
      if (fullFilePath == null || fullFilePath.isEmpty) {
        throw Exception('Invalid file path');
      }

      final extension = path.extension(note.filePath!) ?? '.pdf';
      final fileName =
          'note_${note.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '${cacheDir.path}/$fileName';

      await _dio.download(
        fullFilePath,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress[note.id] = received / total);
          }
        },
      );

      setState(() {
        _cachedNotePaths[note.id] = filePath;
        _isDownloading[note.id] = false;
        _downloadProgress.remove(note.id);
      });

      await _saveCacheMetadata();

      if (mounted) {
        SnackbarService()
            .showSuccess(context, 'Note downloaded for offline viewing');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[note.id] = false;
          _downloadProgress.remove(note.id);
        });
        SnackbarService().showError(context, 'Download failed: $e');
      }
    }
  }

  Future<void> _saveCacheMetadata() async {
    if (_currentUserId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final videoPaths = <String, String>{};
      for (final entry in _cachedVideoPaths.entries) {
        videoPaths[entry.key.toString()] = entry.value;
      }

      final notePaths = <String, String>{};
      for (final entry in _cachedNotePaths.entries) {
        notePaths[entry.key.toString()] = entry.value;
      }

      final downloadQualities = <String, String>{};
      for (final entry in _downloadQuality.entries) {
        downloadQualities[entry.key.toString()] = entry.value.label;
      }

      await deviceService.saveCacheItem(
        'cached_videos_chapter_${widget.chapterId}_$_currentUserId',
        videoPaths,
        isUserSpecific: true,
        ttl: const Duration(days: 30),
      );
      await deviceService.saveCacheItem(
        'cached_notes_chapter_${widget.chapterId}_$_currentUserId',
        notePaths,
        isUserSpecific: true,
        ttl: const Duration(days: 30),
      );
      await deviceService.saveCacheItem(
        'download_qualities_chapter_${widget.chapterId}_$_currentUserId',
        downloadQualities,
        isUserSpecific: true,
        ttl: const Duration(days: 30),
      );
    } catch (e) {}
  }

  Future<void> _saveQuestionProgress() async {
    if (_currentUserId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final progressData = {
        'selected_answers':
            _selectedAnswers.map((k, v) => MapEntry(k.toString(), v)),
        'show_explanations':
            _showExplanation.map((k, v) => MapEntry(k.toString(), v)),
        'is_correct':
            _isQuestionCorrect.map((k, v) => MapEntry(k.toString(), v)),
        'question_answered':
            _questionAnswered.map((k, v) => MapEntry(k.toString(), v)),
      };

      await deviceService.saveCacheItem(
        'question_progress_chapter_${widget.chapterId}_$_currentUserId',
        progressData,
        isUserSpecific: true,
        ttl: const Duration(days: 365),
      );
    } catch (e) {}
  }

  Future<void> _clearAllDownloads() async {
    final confirmed = await AppDialog.delete(
      context: context,
      title: 'Clear Downloads',
      message:
          'Are you sure you want to remove all downloaded videos and notes?',
    );

    if (confirmed != true) return;

    AppDialog.showLoading(context, message: 'Clearing downloads...');

    try {
      for (final path in _cachedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {}
      }
      for (final path in _cachedNotePaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {}
      }

      setState(() {
        _cachedVideoPaths.clear();
        _cachedNotePaths.clear();
        _downloadQuality.clear();
      });

      await _saveCacheMetadata();

      AppDialog.hideLoading(context);

      SnackbarService().showSuccess(context, 'All downloads cleared');
    } catch (e) {
      AppDialog.hideLoading(context);
      SnackbarService().showError(context, 'Error clearing downloads');
    }
  }

  Future<void> _checkAllAnswers(List<Question> questions) async {
    final questionProvider = context.read<QuestionProvider>();
    bool hasError = false;
    int correctCount = 0;

    AppDialog.showLoading(context, message: 'Checking answers...');

    for (final question in questions) {
      final questionId = question.id;
      final selectedAnswer = _selectedAnswers[questionId];

      if (selectedAnswer == null || selectedAnswer.isEmpty) {
        hasError = true;
        continue;
      }

      try {
        final result =
            await questionProvider.checkAnswer(questionId, selectedAnswer);
        final isCorrect = result['is_correct'] == true;

        setState(() {
          _showExplanation[questionId] = true;
          _isQuestionCorrect[questionId] = isCorrect;
          _questionAnswered[questionId] = true;
        });

        if (isCorrect) correctCount++;
      } catch (e) {
        hasError = true;
      }
    }

    AppDialog.hideLoading(context);

    await _saveQuestionProgress();

    if (mounted) {
      SnackbarService().showSuccess(
        context,
        hasError
            ? 'Checked ${questions.length} questions, $correctCount correct'
            : 'All questions checked! $correctCount/${questions.length} correct',
      );
    }
  }

  void _resetAllQuestions() {
    setState(() {
      _selectedAnswers.clear();
      _showExplanation.clear();
      _isQuestionCorrect.clear();
      _questionAnswered.clear();
      _showAllExplanations = false;
    });
    _saveQuestionProgress();
  }

  void _toggleAllExplanations() {
    setState(() {
      _showAllExplanations = !_showAllExplanations;
      for (final questionId in _questionAnswered.keys) {
        if (_questionAnswered[questionId] == true) {
          _showExplanation[questionId] = _showAllExplanations;
        }
      }
    });
    _saveQuestionProgress();
  }

  void _selectAnswer(int questionId, String option) {
    setState(() {
      _selectedAnswers[questionId] = option;
      _showExplanation[questionId] = false;
    });
    _saveQuestionProgress();
  }

  Future<void> _checkAnswer(int questionId, String selectedOption) async {
    final questionProvider = context.read<QuestionProvider>();

    try {
      final result =
          await questionProvider.checkAnswer(questionId, selectedOption);
      final isCorrect = result['is_correct'] == true;

      setState(() {
        _showExplanation[questionId] = true;
        _isQuestionCorrect[questionId] = isCorrect;
        _questionAnswered[questionId] = true;
      });

      await _saveQuestionProgress();
    } catch (e) {
      if (mounted) {
        SnackbarService().showError(context, 'Failed to check answer');
      }
    }
  }

  Widget _buildAccessDeniedScreen() {
    final isFree = _chapter?.isFree ?? false;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _chapter?.name ?? 'Chapter',
          style: AppTextStyles.titleMedium(context),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveValues.sectionPadding(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
                decoration: BoxDecoration(
                  color: isFree
                      ? AppColors.telegramYellow.withValues(alpha: 0.1)
                      : AppColors.telegramRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFree ? Icons.schedule_rounded : Icons.lock_rounded,
                  size: ResponsiveValues.iconSizeXXL(context),
                  color:
                      isFree ? AppColors.telegramYellow : AppColors.telegramRed,
                ),
              ),
              const ResponsiveSizedBox(height: AppSpacing.xxl),
              Text(
                isFree ? 'Coming Soon' : 'Chapter Locked',
                style: AppTextStyles.headlineMedium(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const ResponsiveSizedBox(height: AppSpacing.l),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.sectionPadding(context) * 2,
                ),
                child: Text(
                  isFree
                      ? 'This chapter will be available soon. Stay tuned for updates!'
                      : 'Access to "${_chapter?.name ?? "this chapter"}" requires a subscription to "${_category?.name ?? "the category"}".',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
              ),
              if (!isFree) ...[
                const ResponsiveSizedBox(height: AppSpacing.xxxl),
                AppButton.primary(
                  label: 'Purchase Access',
                  onPressed: () => context.push('/payment', extra: {
                    'category': _category,
                    'paymentType': 'first_time'
                  }),
                ),
              ],
              const ResponsiveSizedBox(height: AppSpacing.xl),
              AppButton.outline(
                label: 'Go Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideosTab() {
    final videoProvider = context.watch<VideoProvider>();
    final videos = videoProvider.getVideosByChapter(widget.chapterId);

    if (videoProvider.isLoadingForChapter(widget.chapterId) && videos.isEmpty) {
      return ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.videoCard, index: index),
        ),
      );
    }

    if (videos.isEmpty) {
      return Center(
        child: AppEmptyState.noData(
          dataType: 'Videos',
          customMessage: _isOffline
              ? 'No cached videos available. Connect to load videos.'
              : 'There are no videos for this chapter yet.',
          onRefresh: () => videoProvider.loadVideosByChapter(
            widget.chapterId,
            forceRefresh: true,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.getBackground(context).withValues(alpha: 0.95),
            AppColors.getBackground(context),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () => videoProvider.loadVideosByChapter(
          widget.chapterId,
          forceRefresh: true,
        ),
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getBackground(context),
        child: ListView.builder(
          controller: _scrollController,
          padding: ResponsiveValues.screenPadding(context),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveValues.spacingL(context),
              ),
              child: VideoCard(
                video: video,
                chapterId: widget.chapterId,
                index: index,
                onPlay: () => _playVideo(video),
                onDownload: (quality) async {
                  if (quality != null) {
                    setState(() {
                      _downloadQuality[video.id] = quality;
                    });
                    await _downloadVideo(video);
                  }
                },
                onShowQualitySelector: _showQualitySelector,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotesTab() {
    final noteProvider = context.watch<NoteProvider>();
    final notes = noteProvider.getNotesByChapter(widget.chapterId);

    if (noteProvider.isLoadingForChapter(widget.chapterId) && notes.isEmpty) {
      return ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.noteCard, index: index),
        ),
      );
    }

    if (notes.isEmpty) {
      return Center(
        child: AppEmptyState.noData(
          dataType: 'Notes',
          customMessage: _isOffline
              ? 'No cached notes available. Connect to load notes.'
              : 'There are no notes for this chapter yet.',
          onRefresh: () => noteProvider.loadNotesByChapter(
            widget.chapterId,
            forceRefresh: true,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.getBackground(context).withValues(alpha: 0.95),
            AppColors.getBackground(context),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () => noteProvider.loadNotesByChapter(
          widget.chapterId,
          forceRefresh: true,
        ),
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getBackground(context),
        child: ListView.builder(
          controller: _scrollController,
          padding: ResponsiveValues.screenPadding(context),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final isDownloaded = _cachedNotePaths.containsKey(note.id);
            final isDownloading = _isDownloading[note.id] == true;
            final downloadProgress = _downloadProgress[note.id] ?? 0.0;

            return Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveValues.spacingL(context),
              ),
              child: NoteCard(
                note: note,
                chapterId: widget.chapterId,
                index: index,
                isDownloaded: isDownloaded,
                isDownloading: isDownloading,
                downloadProgress: downloadProgress,
                onTap: () {
                  final progressProvider = context.read<ProgressProvider>();
                  progressProvider.saveChapterProgress(
                    chapterId: note.chapterId,
                    notesViewed: true,
                  );
                  noteProvider.markNoteAsViewed(note.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(
                        note: note,
                        cachedPath: _cachedNotePaths[note.id],
                      ),
                    ),
                  );
                },
                onDownload: () => _downloadNote(note),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPracticeTab() {
    final questionProvider = context.watch<QuestionProvider>();
    final questions = questionProvider.getQuestionsByChapter(widget.chapterId);

    if (questionProvider.isLoadingForChapter(widget.chapterId) &&
        questions.isEmpty) {
      return ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child:
              const AppShimmer(type: ShimmerType.rectangle, customHeight: 200),
        ),
      );
    }

    if (questions.isEmpty) {
      return Center(
        child: AppEmptyState.noData(
          dataType: 'Practice Questions',
          customMessage: _isOffline
              ? 'No cached questions available. Connect to load questions.'
              : 'Practice questions will be added soon.',
          onRefresh: () => questionProvider.loadPracticeQuestions(
            widget.chapterId,
            forceRefresh: true,
          ),
        ),
      );
    }

    final answeredCount = _questionAnswered.values.where((v) => v).length;
    final totalCount = questions.length;
    final progress = answeredCount / totalCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.getBackground(context).withValues(alpha: 0.95),
            AppColors.getBackground(context),
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: ResponsiveValues.screenPadding(context),
              child: AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Practice Progress',
                            style: AppTextStyles.titleMedium(context).copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValues.spacingM(context),
                              vertical: ResponsiveValues.spacingXXS(context),
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.blueGradient,
                              ),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.telegramBlue
                                      .withValues(alpha: 0.3),
                                  blurRadius:
                                      ResponsiveValues.spacingS(context),
                                  offset: Offset(
                                      0, ResponsiveValues.spacingXXS(context)),
                                ),
                              ],
                            ),
                            child: Text(
                              '$answeredCount/$totalCount',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const ResponsiveSizedBox(height: AppSpacing.l),
                      Stack(
                        children: [
                          Container(
                            height: ResponsiveValues.progressBarHeight(context),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusSmall(context)),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height:
                                  ResponsiveValues.progressBarHeight(context),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.blueGradient,
                                ),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusSmall(context)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.5),
                                    blurRadius:
                                        ResponsiveValues.spacingXS(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.primary(
                      label: 'Check All',
                      icon: Icons.checklist_rounded,
                      onPressed: _selectedAnswers.values
                              .any((v) => v != null && v.isNotEmpty)
                          ? () => _checkAllAnswers(questions)
                          : null,
                      expanded: true,
                    ),
                  ),
                  const ResponsiveSizedBox(width: AppSpacing.m),
                  Expanded(
                    child: AppButton.glass(
                      label: answeredCount > 0 ? 'Reset All' : 'Reset',
                      icon: Icons.refresh_rounded,
                      onPressed: answeredCount > 0 ? _resetAllQuestions : null,
                      expanded: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (answeredCount == totalCount && totalCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: ResponsiveValues.screenPadding(context),
                child: AppButton.glass(
                  label: _showAllExplanations
                      ? 'Hide All Explanations'
                      : 'Show All Explanations',
                  icon: _showAllExplanations
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  onPressed: _toggleAllExplanations,
                ),
              ),
            ),
          const SliverToBoxAdapter(
              child: ResponsiveSizedBox(height: AppSpacing.s)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final question = questions[index];
                return Padding(
                  padding: ResponsiveValues.screenPadding(context),
                  child: PracticeQuestionCard(
                    question: question,
                    index: index,
                    selectedAnswers: _selectedAnswers,
                    showExplanation: _showExplanation,
                    isQuestionCorrect: _isQuestionCorrect,
                    questionAnswered: _questionAnswered,
                    onSelectAnswer: _selectAnswer,
                    onCheckAnswer: _checkAnswer,
                  ),
                );
              },
              childCount: questions.length,
            ),
          ),
          const SliverToBoxAdapter(
              child: ResponsiveSizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseVideo();
    }
    if (state == AppLifecycleState.resumed) _resumeVideoIfNeeded();
  }

  Widget _buildMobileLayout() {
    if (_isLoading && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: const AppShimmer(type: ShimmerType.textLine, customWidth: 200),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
        ),
        body: ListView.builder(
          padding: ResponsiveValues.screenPadding(context),
          itemCount: 5,
          itemBuilder: (context, index) => Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: AppShimmer(type: ShimmerType.videoCard, index: index),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Error',
            style: AppTextStyles.titleMedium(context),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: AppEmptyState.error(
            title: 'Something went wrong',
            message: _errorMessage!,
            onRetry: _initialize,
          ),
        ),
      );
    }

    if (_chapter == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Not Found',
            style: AppTextStyles.titleMedium(context),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: AppEmptyState.error(
            title: 'Chapter not found',
            message: _isOffline
                ? 'No cached data available. Please check your connection.'
                : 'The chapter you\'re looking for doesn\'t exist.',
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    if (!_hasAccess && !_isCheckingAccess) return _buildAccessDeniedScreen();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _chapter!.name,
          style: AppTextStyles.titleMedium(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onSelected: (value) {
              if (value == 'clear_downloads') _clearAllDownloads();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_downloads',
                child: Text('Clear Downloads'),
              ),
            ],
          ),
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
              child: SizedBox(
                width: ResponsiveValues.iconSizeS(context),
                height: ResponsiveValues.iconSizeS(context),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(ResponsiveValues.appBarHeight(context)),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.getDivider(context),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.videocam_rounded), text: 'Videos'),
                Tab(icon: Icon(Icons.note_alt_rounded), text: 'Notes'),
                Tab(icon: Icon(Icons.quiz_rounded), text: 'Practice'),
              ],
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideosTab(),
                _buildNotesTab(),
                _buildPracticeTab(),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}

class NoteDetailScreen extends StatelessWidget {
  final Note note;
  final String? cachedPath;

  const NoteDetailScreen({super.key, required this.note, this.cachedPath});

  Future<void> _openFile(BuildContext context, String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        SnackbarService().showError(context, 'Cannot open file');
      }
    } catch (e) {
      SnackbarService().showError(context, 'Error opening file: $e');
    }
  }

  Widget _buildPdfViewer(String filePath) {
    return SfPdfViewer.file(File(filePath));
  }

  Widget _buildTextContent(BuildContext context, String content) {
    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: HtmlWidget(
        content,
        textStyle: AppTextStyles.bodyLarge(context).copyWith(
          height: 1.6,
        ),
        onTapUrl: (url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return true;
          }
          return false;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = note.filePath?.toLowerCase().endsWith('.pdf') ?? false;
    final hasFile = note.filePath != null && note.filePath!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          note.title,
          style: AppTextStyles.titleMedium(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasFile && cachedPath != null)
            AppButton.icon(
              icon: Icons.open_in_new_rounded,
              onPressed: () => _openFile(context, cachedPath!),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasFile)
            Container(
              padding: ResponsiveValues.screenPadding(context),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.getDivider(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeXL(context) * 1.5,
                    height: ResponsiveValues.iconSizeXL(context) * 1.5,
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.note_alt_rounded,
                      size: ResponsiveValues.iconSizeL(context),
                      color: AppColors.telegramBlue,
                    ),
                  ),
                  const ResponsiveSizedBox(width: AppSpacing.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPdf ? 'PDF Document' : 'Text Document',
                          style: AppTextStyles.titleSmall(context),
                        ),
                        if (cachedPath != null)
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppColors.telegramGreen),
                              const ResponsiveSizedBox(width: AppSpacing.xs),
                              Text(
                                'Available Offline',
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.telegramGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: hasFile && cachedPath != null && isPdf
                ? _buildPdfViewer(cachedPath!)
                : _buildTextContent(context, note.content),
          ),
        ],
      ),
    );
  }
}
