// lib/screens/chapter/chapter_content_screen.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - FIXED ALL VIDEO ISSUES

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
import '../../widgets/common/app_bar.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/platform_helper.dart';
import '../../utils/constants.dart';
import '../../utils/app_enums.dart';

/// PRODUCTION-READY CHAPTER CONTENT SCREEN
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
  Category? _category;
  Course? _course;

  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isCheckingAccess = true;
  String? _errorMessage;

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  int _pendingCount = 0;

  // Video players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  media_kit.Player? _mediaKitPlayer;
  media_kit_video.VideoController? _mediaKitVideoController;
  bool _isPlayingVideo = false;
  bool _isVideoDialogOpen = false;
  bool _isPlayerInitialized = false;
  Video? _currentPlayingVideo;
  String? _currentPlaybackQualityLabel;
  double _currentPlaybackSpeed = 1.0;

  // Practice questions state
  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _showExplanation = {};
  final Map<int, bool> _isQuestionCorrect = {};
  final Map<int, bool> _questionAnswered = {};
  bool _showAllExplanations = false;

  // Downloads
  final Map<int, String> _cachedVideoPaths = {};
  final Map<int, String> _cachedNotePaths = {};
  final Map<int, bool> _isDownloading = {};
  final Map<int, double> _downloadProgress = {};
  final Map<int, VideoQuality> _downloadQuality = {};
  final Dio _dio = Dio();

  // Subscriptions
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

    if (PlatformHelper.shouldUseMediaKit) {
      try {
        media_kit.MediaKit.ensureInitialized();
        debugLog('ChapterContent',
            'MediaKit initialized for ${PlatformHelper.deviceType}');
      } catch (e) {
        debugLog('ChapterContent', 'MediaKit init error: $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _disposeAllPlayers();
    _cleanupResources();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeAllPlayers() {
    _isVideoDialogOpen = false;
    _isPlayingVideo = false;
    _isPlayerInitialized = false;
    _currentPlayingVideo = null;
    _currentPlaybackQualityLabel = null;
    _currentPlaybackSpeed = 1.0;

    try {
      if (_mediaKitPlayer != null) {
        _mediaKitPlayer!.stop();
        _mediaKitPlayer!.dispose();
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
        _videoController?.dispose();
        _videoController = null;
      }
    } catch (e) {}

    try {
      WakelockPlus.disable();
    } catch (e) {}
  }

  void _cleanupResources() {
    _refreshTimer?.cancel();
    _videoUpdateSubscription?.cancel();
    _noteUpdateSubscription?.cancel();
    _questionUpdateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _dio.close();
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
        if (isOnline && !_isRefreshing && _chapter != null) {
          unawaited(_refreshInBackground());
        }
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = !connectivityService.isOnline;
        _pendingCount = connectivityService.pendingActionsCount;
      });
    }
  }

  Future<Directory> _getAppCacheDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/.familyacademy_cache/videos');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  // TIER 2: Load cached downloads
  Future<void> _loadCachedContent() async {
    if (_currentUserId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final videoPaths = await deviceService.getCacheItem<Map<String, dynamic>>(
        'cached_videos_chapter_${widget.chapterId}_$_currentUserId',
        isUserSpecific: true,
      );
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
        isUserSpecific: true,
      );
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
        isUserSpecific: true,
      );
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

  // TIER 2: Load from cache
  Future<void> _initializeFromCache() async {
    final chapterProvider = context.read<ChapterProvider>();
    final courseProvider = context.read<CourseProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (widget.chapter != null) {
      _chapter = widget.chapter;
      _category = widget.category;
      _course = widget.course;
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
            _category = category;
            _course = course;
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

  // TIER 3: Background refresh
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // Manual refresh with connectivity check
  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context);
      setState(() => _isOffline = true);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, AppStrings.chapterUpdated);
    } catch (e) {
      if (!mounted) return;
      if (_looksLikeNetworkError(e)) {
        setState(() => _isOffline = true);
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        setState(() => _isOffline = false);
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  bool _looksLikeNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('network error') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('offline');
  }

  // TIER 3: Load fresh data
  Future<void> _checkAccessAndLoadData({bool forceRefresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!authProvider.isAuthenticated) {
      _errorMessage = AppStrings.authenticationRequired;
      setState(() => _isCheckingAccess = false);
      return;
    }

    if (_chapter == null) await _loadChapterData(forceRefresh);
    if (_chapter == null) {
      _errorMessage = AppStrings.chapterNotFound;
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
            _category = category;
            _course = course;
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
      if (!mounted) return;
      if (_looksLikeNetworkError(e)) {
        setState(() => _isOffline = true);
      }
    }
  }

  void _setupBackgroundRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (mounted && _hasAccess && !_isRefreshing && !_isOffline) {
        await _refreshInBackground();
      }
    });
  }

  void _pauseVideo() {
    if (!_isPlayingVideo || _isVideoDialogOpen) return;
    try {
      if (PlatformHelper.shouldUseMediaKit) {
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
      if (PlatformHelper.shouldUseMediaKit) {
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

  // ===== SWITCH QUALITY METHOD =====
  Future<void> _switchQuality(Video video, VideoQuality quality) async {
    if (_isVideoDialogOpen) {
      // Show loading in the dialog
      setState(() {
        _isPlayerInitialized = false;
        _currentPlaybackQualityLabel = quality.label;
      });

      try {
        if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
          // For MediaKit, change source without disposing
          await _mediaKitPlayer!.open(media_kit.Media(quality.url));
          // Restore speed
          await _mediaKitPlayer!.setRate(_currentPlaybackSpeed);
          setState(() => _isPlayerInitialized = true);
        } else if (_videoController != null && _chewieController != null) {
          // For Chewie, recreate controller
          _chewieController!.dispose();
          _chewieController = null;
          _videoController!.dispose();
          _videoController = null;

          _videoController =
              VideoPlayerController.networkUrl(Uri.parse(quality.url));
          await _videoController!.initialize();
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            showControls: true,
            showOptions: false,
            allowFullScreen: false,
            allowMuting: true,
            playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5],
            // Set initial speed
          );
          await _videoController!.setPlaybackSpeed(_currentPlaybackSpeed);
          setState(() => _isPlayerInitialized = true);
        }
      } catch (e) {
        debugLog('VideoCard', 'Error switching quality: $e');
        setState(() => _isPlayerInitialized = true); // Hide loading on error
        if (mounted) {
          SnackbarService().showError(context, 'Failed to switch quality');
        }
      }
    }
  }

  // ===== STREAMING QUALITY SELECTOR =====
  Future<void> _showStreamingQualitySelector(Video video) async {
    final quality = await _showQualitySelector(video, forPlayback: true);
    if (quality != null && mounted) {
      // Update quality label immediately
      setState(() {
        _currentPlaybackQualityLabel = quality.label;
      });

      // Show loading dialog while switching quality
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
          ),
        ),
      );

      try {
        // Switch quality without closing video dialog
        await _switchQuality(video, quality);

        if (mounted) Navigator.pop(context); // Close loading dialog only
      } catch (e) {
        if (mounted) Navigator.pop(context); // Close loading dialog on error
        SnackbarService().showError(context, 'Failed to change quality');
      }
    }
  }

  // ===== SPEED SELECTOR =====
  Future<void> _showSpeedSelector(Video video) async {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
    final selectedSpeed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              leading: _currentPlaybackSpeed == speed
                  ? const Icon(Icons.check, color: AppColors.telegramBlue)
                  : null,
              onTap: () => Navigator.pop(context, speed),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedSpeed != null &&
        selectedSpeed != _currentPlaybackSpeed &&
        mounted) {
      setState(() {
        _currentPlaybackSpeed = selectedSpeed;
      });

      try {
        if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
          await _mediaKitPlayer!.setRate(selectedSpeed);
        } else if (_videoController != null) {
          await _videoController!.setPlaybackSpeed(selectedSpeed);
        }
      } catch (e) {
        debugLog('VideoCard', 'Error setting speed: $e');
        SnackbarService().showError(context, 'Failed to change speed');
      }
    }
  }

  // ===== VIDEO PLAYBACK =====
  Future<void> _playVideo(Video video) async {
    if (_isVideoDialogOpen) return;

    // Show loading dialog immediately
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
        ),
      ),
    );

    try {
      if (_cachedVideoPaths.containsKey(video.id)) {
        final localPath = _cachedVideoPaths[video.id]!;
        if (mounted) Navigator.pop(context); // Close loading dialog
        await _playLocalVideo(video, localPath);
        return;
      }

      final connectivity = context.read<ConnectivityService>();
      if (!connectivity.isOnline) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        SnackbarService().showOffline(context, action: AppStrings.playVideo);
        return;
      }

      VideoQuality? selectedQuality;

      if (video.hasQualities) {
        if (mounted)
          Navigator.pop(
              context); // Close loading dialog before quality selector
        selectedQuality = await _showQualitySelector(video, forPlayback: true);
        if (selectedQuality == null) return;

        // Update quality label
        setState(() {
          _currentPlaybackQualityLabel = selectedQuality?.label;
        });

        // Show loading dialog again while preparing player
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
            ),
          ),
        );
      } else {
        selectedQuality = video.getRecommendedQuality();
        setState(() {
          _currentPlaybackQualityLabel = selectedQuality?.label;
        });
      }

      if (mounted) Navigator.pop(context); // Close loading dialog
      await _playNetworkVideo(video, selectedQuality.url);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog on error
        SnackbarService().showError(context, 'Failed to play video');
      }
    }
  }

  Future<void> _playLocalVideo(Video video, String localPath) async {
    _disposeAllPlayers();
    _currentPlayingVideo = video;

    try {
      setState(() {
        _isPlayingVideo = true;
        _isVideoDialogOpen = true;
        _isPlayerInitialized = false;
      });

      // Check if file exists
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

      // Use MediaKit for Linux, VideoPlayer for others
      if (PlatformHelper.isLinux) {
        await _playLocalWithMediaKit(video, localPath);
      } else {
        await _playWithVideoPlayer(video, localPath);
      }
    } catch (e) {
      debugLog('VideoCard', 'Error playing local video: $e');
      setState(() {
        _isVideoDialogOpen = false;
        _isPlayingVideo = false;
      });
      if (mounted) {
        SnackbarService().showError(context, 'Failed to play downloaded video');
      }
    }
  }

  Future<void> _playLocalWithMediaKit(Video video, String localPath) async {
    try {
      _mediaKitPlayer = media_kit.Player();
      _mediaKitVideoController =
          media_kit_video.VideoController(_mediaKitPlayer!);

      _mediaKitPlayer!.stream.error.listen((error) {
        debugLog('VideoCard', 'MediaKit error: $error');
      });

      await _mediaKitPlayer!.setVolume(100);
      await _mediaKitPlayer!.open(media_kit.Media(localPath));

      if (!mounted) return;

      setState(() => _isPlayerInitialized = true);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _buildVideoDialog(video),
      );
    } catch (e) {
      debugLog('VideoCard', 'MediaKit error: $e');
      rethrow;
    }
  }

  Future<void> _playNetworkVideo(Video video, String videoUrl) async {
    _disposeAllPlayers();
    _currentPlayingVideo = video;

    try {
      setState(() {
        _isPlayingVideo = true;
        _isVideoDialogOpen = true;
        _isPlayerInitialized = false;
      });

      if (PlatformHelper.isLinux) {
        try {
          await _playWithMediaKit(video, videoUrl);
        } catch (e) {
          debugLog('VideoCard', 'MediaKit failed on Linux: $e');
          SnackbarService().showError(
            context,
            AppStrings.videoPlaybackFailed,
          );
        }
      } else {
        await _playWithVideoPlayer(video, videoUrl);
      }
    } catch (e) {
      setState(() {
        _isVideoDialogOpen = false;
        _isPlayingVideo = false;
        _isPlayerInitialized = false;
        _currentPlayingVideo = null;
      });

      if (mounted) {
        SnackbarService().showError(
          context,
          AppStrings.failedToPlayVideo,
        );
      }
    }
  }

  Future<void> _playWithMediaKit(Video video, String videoUrl) async {
    try {
      _mediaKitPlayer = media_kit.Player();
      _mediaKitVideoController =
          media_kit_video.VideoController(_mediaKitPlayer!);

      _mediaKitPlayer!.stream.error.listen((error) {
        debugLog('VideoCard', 'MediaKit error: $error');
      });

      await _mediaKitPlayer!.setVolume(100);
      await _mediaKitPlayer!.open(media_kit.Media(videoUrl));
      await _mediaKitPlayer!.setRate(_currentPlaybackSpeed);

      if (!mounted) return;

      setState(() => _isPlayerInitialized = true);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _buildVideoDialog(video),
      );
    } catch (e) {
      debugLog('VideoCard', 'MediaKit error: $e');
      rethrow;
    }
  }

  Future<void> _playWithVideoPlayer(Video video, String videoUrl) async {
    try {
      if (_videoController != null) {
        _videoController!.dispose();
        _videoController = null;
      }
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }

      VideoPlayerController controller;

      if (videoUrl.startsWith('file://') || videoUrl.startsWith('/')) {
        final filePath = videoUrl.replaceFirst('file://', '');
        controller = VideoPlayerController.file(File(filePath));
        debugLog('VideoCard', 'Playing local file: $filePath');
      } else {
        final uri = Uri.parse(videoUrl);
        controller = VideoPlayerController.networkUrl(uri);
        debugLog('VideoCard', 'Playing network video: ${uri.host}');
      }

      _videoController = controller;

      await controller.initialize();
      await controller.setPlaybackSpeed(_currentPlaybackSpeed);
      debugLog('VideoCard', 'Video initialized: ${controller.value.duration}');

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5], // Removed 2.0
      );

      setState(() => _isPlayerInitialized = true);

      try {
        await WakelockPlus.enable();
      } catch (e) {}

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _buildVideoDialog(video),
      );
    } catch (e) {
      debugLog('VideoCard', 'VideoPlayer error: $e');
      rethrow;
    }
  }

  Widget _buildVideoDialog(Video video) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PlatformHelper.isLinux && _mediaKitVideoController != null
                  ? media_kit_video.Video(
                      controller: _mediaKitVideoController!,
                    )
                  : (_chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const Center(child: CircularProgressIndicator())),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    if (mounted) _onVideoClosed(video);
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0088CC), Color(0xFF0055AA)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentPlaybackQualityLabel ??
                          video.getRecommendedQuality().label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFF7931E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPlaybackSpeed}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // QUALITY SELECTOR BUTTON FOR STREAMING
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings,
                          color: Colors.white, size: 20),
                      onPressed: () => _showStreamingQualitySelector(video),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SPEED SELECTOR BUTTON
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.speed,
                          color: Colors.white, size: 20),
                      onPressed: () => _showSpeedSelector(video),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onVideoClosed(Video video) async {
    setState(() => _isVideoDialogOpen = false);

    try {
      if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
        _mediaKitPlayer?.stop();
        _mediaKitPlayer?.dispose();
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
      } else if (_chewieController != null) {
        _chewieController?.pause();
        _chewieController?.dispose();
        _chewieController = null;

        if (_videoController != null) {
          _videoController?.dispose();
          _videoController = null;
        }
      }

      await WakelockPlus.disable();
    } catch (e) {
      debugLog('VideoCard', 'Error disposing player: $e');
    }

    try {
      final videoProvider = context.read<VideoProvider>();
      final progressProvider = context.read<ProgressProvider>();

      int progress = 0;
      if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
        try {
          final position = _mediaKitPlayer!.state.position;
          final duration = _mediaKitPlayer!.state.duration;
          progress = duration.inSeconds > 0
              ? (position.inSeconds / duration.inSeconds * 100).toInt()
              : 0;
        } catch (e) {}
      }

      await progressProvider.saveChapterProgress(
          chapterId: widget.chapterId, videoProgress: progress);
      if (progress >= 30) {
        await videoProvider.incrementViewCount(video.id);
      }
    } finally {
      _disposeAllPlayers();
    }
  }

  // ===== QUALITY SELECTOR =====
  Future<VideoQuality?> _showQualitySelector(Video video,
      {bool forPlayback = false}) async {
    if (_cachedVideoPaths.containsKey(video.id)) {
      SnackbarService().showInfo(context, AppStrings.videoAlreadyDownloaded);
      return null;
    }

    final availableQualities = video.availableQualities;

    if (availableQualities.isEmpty) {
      return VideoQuality(label: '480p', url: video.fullVideoUrl, height: 480);
    }

    final videoProvider = context.read<VideoProvider>();
    final savedPreference = await videoProvider.getQualityPreference(video.id);

    final recommendedQuality = video.getRecommendedQuality(
      await _getConnectionType(),
    );

    VideoQuality? preSelected;
    if (savedPreference != null) {
      preSelected = availableQualities.firstWhere(
        (q) => q.label == savedPreference,
        orElse: () => recommendedQuality,
      );
    }

    final Completer<VideoQuality?> completer = Completer();

    final double? bottomSheetHeight =
        PlatformHelper.isTv ? MediaQuery.of(context).size.height * 0.6 : null;

    // For streaming, get actual file sizes from server
    if (forPlayback) {
      await _fetchActualFileSizes(availableQualities);
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: bottomSheetHeight != null
          ? BoxConstraints(maxHeight: bottomSheetHeight)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    forPlayback
                        ? AppStrings.selectQuality
                        : AppStrings.downloadQuality,
                    style: TextStyle(
                      fontSize: PlatformHelper.isTv ? 24 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: PlatformHelper.isTv ? 32 : 24,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      completer.complete(null);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...availableQualities.map((quality) {
              final isRecommended = quality.label == recommendedQuality.label;
              final isSelected = quality.label ==
                  (preSelected?.label ?? recommendedQuality.label);

              return ListTile(
                leading: Container(
                  width: PlatformHelper.isTv ? 64 : 48,
                  height: PlatformHelper.isTv ? 64 : 48,
                  decoration: BoxDecoration(
                    gradient: isRecommended
                        ? const LinearGradient(
                            colors: [Color(0xFF0088CC), Color(0xFF0055AA)])
                        : null,
                    color: isRecommended ? null : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      quality.label.replaceAll('p', ''),
                      style: TextStyle(
                        color: isRecommended ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: PlatformHelper.isTv ? 20 : 16,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      quality.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF0088CC) : null,
                        fontSize: PlatformHelper.isTv ? 18 : 16,
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0088CC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppStrings.best,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: PlatformHelper.isTv ? 12 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _getQualityDescription(quality),
                      style: TextStyle(
                        fontSize: PlatformHelper.isTv ? 14 : 12,
                      ),
                    ),
                    if (quality.estimatedSize > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            size: PlatformHelper.isTv ? 16 : 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Size: ${quality.formattedSize}',
                            style: TextStyle(
                              fontSize: PlatformHelper.isTv ? 13 : 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: const Color(0xFF0088CC),
                        size: PlatformHelper.isTv ? 32 : 24,
                      )
                    : null,
                onTap: () {
                  videoProvider.saveQualityPreference(video.id, quality.label);
                  Navigator.pop(context);
                  completer.complete(quality);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    return completer.future;
  }

  // ===== FETCH ACTUAL FILE SIZES FROM SERVER =====
  Future<void> _fetchActualFileSizes(List<VideoQuality> qualities) async {
    for (final quality in qualities) {
      try {
        final response = await _dio.head(
          quality.url,
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
            headers: {
              'Accept-Encoding': 'identity',
            },
          ),
        );

        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final size = int.tryParse(contentLength) ?? 0;
          if (size > 0) {
            // Create a new VideoQuality with actual size
            // We can't modify the original because it's final
            // Instead, we'll update the list by creating a new quality
            final index = qualities.indexOf(quality);
            if (index != -1) {
              qualities[index] = VideoQuality(
                label: quality.label,
                url: quality.url,
                height: quality.height,
                estimatedSize: size,
              );
            }
          }
        }
      } catch (e) {
        debugLog('VideoCard', 'Failed to fetch size for ${quality.label}: $e');
      }
    }
  }

  String _getQualityDescription(VideoQuality quality) {
    switch (quality.height) {
      case 360:
        return AppStrings.quality360;
      case 480:
        return AppStrings.quality480;
      case 720:
        return AppStrings.quality720;
      case 1080:
        return AppStrings.quality1080;
      default:
        return '${quality.height}p ${AppStrings.quality}';
    }
  }

  Future<String> _getConnectionType() async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) return 'offline';

    if (PlatformHelper.isTv) return 'wifi';
    if (PlatformHelper.isDesktop) return 'wifi';
    return 'mobile';
  }

  // ===== DOWNLOAD METHODS =====
  Future<void> _downloadVideo(Video video) async {
    if (_isDownloading[video.id] == true) return;
    if (_currentUserId == null) {
      SnackbarService().showError(context, AppStrings.pleaseLoginToDownload);
      return;
    }

    if (PlatformHelper.isTv) {
      try {
        final cacheDir = await _getAppCacheDirectory();
        final dir = Directory(cacheDir.path);
        if (await dir.exists()) {
          final stat = await dir.stat();
          if (stat.size > PlatformHelper.maxCacheSize) {
            SnackbarService().showError(
              context,
              AppStrings.storageAlmostFull,
            );
            return;
          }
        }
      } catch (e) {}
    }

    final quality = _downloadQuality[video.id] ??
        VideoQuality(label: '480p', url: video.fullVideoUrl, height: 480);

    setState(() {
      _isDownloading[video.id] = true;
      _downloadProgress[video.id] = 0.0;
    });

    final videoProvider = context.read<VideoProvider>();
    videoProvider.setDownloadState(video.id, true, 0.0);

    try {
      final cacheDir = await _getAppCacheDirectory();
      final fileName =
          'vid_${video.id}_${quality.height}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${cacheDir.path}/$fileName';

      String downloadUrl = quality.url;

      if (downloadUrl.startsWith('https:/') &&
          !downloadUrl.startsWith('https://')) {
        downloadUrl = downloadUrl.replaceFirst('https:/', 'https://');
      }
      if (downloadUrl.startsWith('http:/') &&
          !downloadUrl.startsWith('http://')) {
        downloadUrl = downloadUrl.replaceFirst('http:/', 'http://');
      }

      debugLog('VideoCard', 'Downloading from: $downloadUrl');

      final cancelToken = CancelToken();

      await _dio.download(
        downloadUrl,
        filePath,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: Duration(minutes: PlatformHelper.isTv ? 15 : 10),
          sendTimeout: Duration(minutes: PlatformHelper.isTv ? 15 : 10),
          headers: {
            'Accept-Encoding': 'identity',
            'User-Agent':
                'FamilyAcademy/${PlatformHelper.isTv ? 'TV' : 'Mobile'}/1.0'
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            final progress = received / total;
            setState(() => _downloadProgress[video.id] = progress);
            videoProvider.updateDownloadProgress(
                video.id, progress, received, total);
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception(AppStrings.downloadFailedFileNotCreated);
      }

      final fileSize = await file.length();
      if (fileSize < 1024) {
        await file.delete();
        throw Exception(AppStrings.downloadedFileTooSmall);
      }

      setState(() {
        _cachedVideoPaths[video.id] = filePath;
        _isDownloading[video.id] = false;
        _downloadProgress.remove(video.id);
      });

      // FIXED: Use fromHeight instead of casting
      final qualityLevel = VideoQualityLevel.fromHeight(quality.height);

      videoProvider.setDownloadState(video.id, false, 1.0);
      videoProvider.setDownloadedVideoPath(video.id, filePath, qualityLevel);

      await _saveCacheMetadata();

      if (mounted) {
        SnackbarService().showSuccess(
          context,
          '${quality.label} ${AppStrings.videoDownloaded} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)',
        );
      }
    } on DioException catch (e) {
      String errorMessage = AppStrings.downloadFailed;
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = AppStrings.connectionTimeout;
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = AppStrings.receiveTimeout;
      } else if (e.type == DioExceptionType.cancel) {
        errorMessage = AppStrings.downloadCancelled;
      } else if (e.response?.statusCode == 404) {
        errorMessage = AppStrings.videoNotFound;
      } else if (e.response?.statusCode == 403) {
        errorMessage = AppStrings.accessDenied;
      } else {
        errorMessage = '${AppStrings.networkError}: ${e.message}';
      }

      if (mounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        videoProvider.setDownloadState(video.id, false, 0.0);
        SnackbarService().showError(context, errorMessage);
      }
      debugLog('VideoCard', 'Download error: $e');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        videoProvider.setDownloadState(video.id, false, 0.0);
        SnackbarService().showError(
            context, '${AppStrings.downloadFailed}: ${e.toString()}');
      }
      debugLog('VideoCard', 'Download error: $e');
    }
  }

  Future<void> _downloadNote(Note note) async {
    if (_isDownloading[note.id] == true) return;
    if (_currentUserId == null) {
      SnackbarService().showError(context, AppStrings.pleaseLoginToDownload);
      return;
    }

    setState(() {
      _isDownloading[note.id] = true;
      _downloadProgress[note.id] = 0.0;
    });

    try {
      if (note.filePath == null || note.filePath!.isEmpty) {
        SnackbarService().showError(context, AppStrings.noteNoDownloadableFile);
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
        throw Exception(AppStrings.invalidFilePath);
      }

      final extension = path.extension(note.filePath!);
      final fileName =
          'note_${note.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '${cacheDir.path}/$fileName';

      await _dio.download(
        fullFilePath,
        filePath,
        options: Options(
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(minutes: 5)),
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
        SnackbarService().showSuccess(context, AppStrings.noteDownloaded);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[note.id] = false;
          _downloadProgress.remove(note.id);
        });
        SnackbarService()
            .showError(context, '${AppStrings.downloadFailed}: $e');
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

      deviceService.saveCacheItem(
        'cached_videos_chapter_${widget.chapterId}_$_currentUserId',
        videoPaths,
        isUserSpecific: true,
        ttl: const Duration(days: 30),
      );
      deviceService.saveCacheItem(
        'cached_notes_chapter_${widget.chapterId}_$_currentUserId',
        notePaths,
        isUserSpecific: true,
        ttl: const Duration(days: 30),
      );
      deviceService.saveCacheItem(
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

      deviceService.saveCacheItem(
        'question_progress_chapter_${widget.chapterId}_$_currentUserId',
        progressData,
        isUserSpecific: true,
        ttl: const Duration(days: 365),
      );
    } catch (e) {}
  }

  // ===== PRACTICE QUESTIONS =====
  Future<void> _checkAllQuestions(List<Question> questions) async {
    final questionProvider = context.read<QuestionProvider>();
    bool hasError = false;
    int correctCount = 0;

    AppDialog.showLoading(context, message: AppStrings.checkingAnswers);

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
        final isCorrect = result.data?['is_correct'] == true;

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
            ? '${AppStrings.checked} ${questions.length} ${AppStrings.questions}, $correctCount ${AppStrings.correct}'
            : '${AppStrings.allQuestionsChecked}! $correctCount/${questions.length} ${AppStrings.correct}',
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
      final isCorrect = result.data?['is_correct'] == true;

      setState(() {
        _showExplanation[questionId] = true;
        _isQuestionCorrect[questionId] = isCorrect;
        _questionAnswered[questionId] = true;
      });

      await _saveQuestionProgress();
    } catch (e) {
      if (mounted) {
        SnackbarService().showError(context, AppStrings.failedToCheckAnswer);
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirmed = await AppDialog.delete(
      context: context,
      title: AppStrings.clearDownloads,
      message: AppStrings.clearDownloadsConfirm,
    );

    if (confirmed != true) return;

    AppDialog.showLoading(context, message: AppStrings.clearingDownloads);

    try {
      // Delete files
      for (final path in _cachedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {}
      }
      for (final path in _cachedNotePaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {}
      }

      // Clear from VideoProvider
      final videoProvider = context.read<VideoProvider>();
      for (final videoId in _cachedVideoPaths.keys.toList()) {
        await videoProvider.removeDownloadedVideo(videoId);
      }

      // Clear local state
      setState(() {
        _cachedVideoPaths.clear();
        _cachedNotePaths.clear();
        _downloadQuality.clear();
      });

      await _saveCacheMetadata();

      AppDialog.hideLoading(context);

      // Show success message
      if (mounted) {
        SnackbarService().showSuccess(context, AppStrings.downloadsCleared);
      }
    } catch (e) {
      AppDialog.hideLoading(context);
      if (mounted) {
        SnackbarService().showError(context, AppStrings.errorClearingDownloads);
      }
    }
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    await _loadCachedContent(); // TIER 2: Load downloads
    await _initializeFromCache(); // TIER 2: Load from cache

    if (_chapter != null && _hasCachedData) {
      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
      if (!_isOffline) {
        await _refreshInBackground(); // TIER 3: Background refresh
      }
    } else {
      await _checkAccessAndLoadData(); // TIER 3: Fresh load
    }

    if (!_isOffline) {
      _setupBackgroundRefresh();
    }
  }

  // ===== UI BUILDERS =====
  Widget _buildAccessDeniedScreen() {
    final isFree = _chapter?.isFree ?? false;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: _chapter?.name ?? AppStrings.chapter,
        subtitle: isFree ? AppStrings.comingSoon : AppStrings.locked,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        showOfflineIndicator: _isOffline,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
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
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
              Text(
                isFree ? AppStrings.comingSoon : AppStrings.chapterLocked,
                style: AppTextStyles.headlineMedium(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.sectionPadding(context) * 2),
                child: Text(
                  isFree
                      ? AppStrings.chapterComingSoonMessage
                      : '${AppStrings.accessRequiresSubscription} "${_category?.name ?? AppStrings.theCategory}".',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
              ),
              if (!isFree) ...[
                SizedBox(height: ResponsiveValues.spacingXXXL(context)),
                AppButton.primary(
                  label: AppStrings.purchaseAccess,
                  onPressed: () => context.push('/payment', extra: {
                    'category': _category,
                    'paymentType': 'first_time'
                  }),
                ),
              ],
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              AppButton.outline(
                  label: AppStrings.goBack, onPressed: () => context.pop()),
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
          dataType: AppStrings.videos,
          customMessage: _isOffline
              ? AppStrings.noCachedVideos
              : AppStrings.noVideosForChapter,
          onRefresh: () => videoProvider.loadVideosByChapter(widget.chapterId,
              forceRefresh: true),
          isOffline: _isOffline,
          pendingCount: _pendingCount,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => videoProvider.loadVideosByChapter(widget.chapterId,
          forceRefresh: true),
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getBackground(context),
      child: ListView.builder(
        controller: _scrollController,
        padding: ResponsiveValues.screenPadding(context),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: VideoCard(
              video: video,
              chapterId: widget.chapterId,
              index: index,
              onPlay: () => _playVideo(video),
              onDownload: (quality) async {
                setState(() => _downloadQuality[video.id] = quality);
                await _downloadVideo(video);
              },
              onShowQualitySelector: _showQualitySelector,
            ),
          );
        },
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
          dataType: AppStrings.notes,
          customMessage: _isOffline
              ? AppStrings.noCachedNotes
              : AppStrings.noNotesForChapter,
          onRefresh: () => noteProvider.loadNotesByChapter(widget.chapterId,
              forceRefresh: true),
          isOffline: _isOffline,
          pendingCount: _pendingCount,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          noteProvider.loadNotesByChapter(widget.chapterId, forceRefresh: true),
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
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
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
                    chapterId: note.chapterId, notesViewed: true);
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
          dataType: AppStrings.practiceQuestions,
          customMessage: _isOffline
              ? AppStrings.noCachedQuestions
              : AppStrings.practiceQuestionsComingSoon,
          onRefresh: () => questionProvider
              .loadPracticeQuestions(widget.chapterId, forceRefresh: true),
          isOffline: _isOffline,
          pendingCount: _pendingCount,
        ),
      );
    }

    final answeredCount = _questionAnswered.values.where((v) => v).length;
    final totalCount = questions.length;
    final progress = totalCount > 0 ? answeredCount / totalCount : 0.0;

    return CustomScrollView(
      slivers: [
        if (_isOffline && _pendingCount > 0)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(ResponsiveValues.spacingM(context)),
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.info.withValues(alpha: 0.2),
                    AppColors.info.withValues(alpha: 0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: AppColors.info,
                      size: ResponsiveValues.iconSizeS(context)),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
                      '$_pendingCount offline answer${_pendingCount > 1 ? 's' : ''}',
                      style: AppTextStyles.bodySmall(context)
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                          AppStrings.practiceProgress,
                          style: AppTextStyles.titleMedium(context).copyWith(
                              fontWeight: FontWeight.w600, letterSpacing: -0.5),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingM(context),
                            vertical: ResponsiveValues.spacingXXS(context),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.blueGradient),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context)),
                          ),
                          child: Text(
                            '$answeredCount/$totalCount',
                            style: AppTextStyles.labelSmall(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
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
                            height: ResponsiveValues.progressBarHeight(context),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppColors.blueGradient),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusSmall(context)),
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
                    label: AppStrings.checkAll,
                    icon: Icons.checklist_rounded,
                    onPressed: _selectedAnswers.values
                            .any((v) => v != null && v.isNotEmpty)
                        ? () => _checkAllQuestions(questions)
                        : null,
                    expanded: true,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Expanded(
                  child: AppButton.glass(
                    label: answeredCount > 0
                        ? AppStrings.resetAll
                        : AppStrings.reset,
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
                    ? AppStrings.hideAllExplanations
                    : AppStrings.showAllExplanations,
                icon: _showAllExplanations
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                onPressed: _toggleAllExplanations,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
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

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: AppStrings.chapter,
        subtitle: AppStrings.loading,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppColors.getDivider(context), width: 0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                    icon: Icon(Icons.videocam_rounded),
                    text: AppStrings.videos),
                const Tab(
                    icon: Icon(Icons.note_alt_rounded), text: AppStrings.notes),
                const Tab(
                    icon: Icon(Icons.quiz_rounded), text: AppStrings.practice),
              ],
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: ResponsiveValues.screenPadding(context),
              itemCount: 3,
              itemBuilder: (context, index) => Padding(
                padding:
                    EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
                child: AppShimmer(type: ShimmerType.videoCard, index: index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasCachedData) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.error,
          subtitle: AppStrings.somethingWentWrong,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: AppEmptyState.error(
            title: AppStrings.somethingWentWrong,
            message: _errorMessage!,
            onRetry: _initialize,
          ),
        ),
      );
    }

    if (_chapter == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.notFound,
          subtitle: AppStrings.chapterNotFound,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: AppEmptyState.error(
            title: AppStrings.chapterNotFound,
            message: _isOffline
                ? AppStrings.noCachedDataAvailable
                : AppStrings.chapterDoesNotExist,
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    // 3. CHECK IF WE HAVE CACHED DATA BUT STILL LOADING
    if (_hasCachedData && _isLoading) {
      // We have cached data but still loading fresh data - show cached content
      // This prevents shimmering when we have cached data available
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!_hasAccess && !_isCheckingAccess) return _buildAccessDeniedScreen();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: _chapter!.name,
        subtitle:
            _isOffline ? AppStrings.offlineMode : AppStrings.chapterContent,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppColors.getTextPrimary(context)),
            onSelected: (value) {
              if (value == 'clear_downloads') _clearAllDownloads();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'clear_downloads',
                  child: Text(AppStrings.clearDownloads)),
            ],
          ),
        ],
        showOfflineIndicator: _isOffline,
      ),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: Column(
          children: [
            if (_isOffline && _pendingCount > 0)
              Container(
                margin: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                padding: ResponsiveValues.cardPadding(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info.withValues(alpha: 0.2),
                      AppColors.info.withValues(alpha: 0.1)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context)),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: AppColors.info,
                        size: ResponsiveValues.iconSizeS(context)),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Text(
                        '$_pendingCount offline change${_pendingCount > 1 ? 's' : ''}',
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.getDivider(context), width: 0.5)),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(
                      icon: Icon(Icons.videocam_rounded),
                      text: AppStrings.videos),
                  const Tab(
                      icon: Icon(Icons.note_alt_rounded),
                      text: AppStrings.notes),
                  const Tab(
                      icon: Icon(Icons.quiz_rounded),
                      text: AppStrings.practice),
                ],
                labelStyle: AppTextStyles.labelMedium(context),
                unselectedLabelStyle: AppTextStyles.labelMedium(context),
                indicatorColor: AppColors.telegramBlue,
                indicatorWeight: 3,
                labelColor: AppColors.telegramBlue,
                unselectedLabelColor: AppColors.getTextSecondary(context),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVideosTab(),
                  _buildNotesTab(),
                  _buildPracticeTab()
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: AppThemes.animationMedium),
    );
  }
}

// ===== NOTE DETAIL SCREEN =====
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
        SnackbarService().showError(context, AppStrings.cannotOpenFile);
      }
    } catch (e) {
      SnackbarService()
          .showError(context, '${AppStrings.errorOpeningFile}: $e');
    }
  }

  Widget _buildPdfViewer(String filePath) => SfPdfViewer.file(File(filePath));

  Widget _buildTextContent(BuildContext context, String content) {
    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: HtmlWidget(
        content,
        textStyle: AppTextStyles.bodyLarge(context).copyWith(height: 1.6),
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
      appBar: CustomAppBar(
        title: note.title,
        subtitle: isPdf ? AppStrings.pdfDocument : AppStrings.textDocument,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (hasFile && cachedPath != null)
            AppButton.icon(
                icon: Icons.open_in_new_rounded,
                onPressed: () => _openFile(context, cachedPath!)),
        ],
      ),
      body: Column(
        children: [
          if (hasFile && cachedPath != null && isPdf)
            Expanded(child: _buildPdfViewer(cachedPath!))
          else
            Expanded(child: _buildTextContent(context, note.content)),
        ],
      ),
    );
  }
}
