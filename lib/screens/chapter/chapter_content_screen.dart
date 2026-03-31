// lib/screens/chapter/chapter_content_screen.dart
// PROFESSIONAL DESIGN - FULL SCREEN PULL-TO-REFRESH - WITH SHIMMER TYPES

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chewie/chewie.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
import '../../providers/settings_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/chapter/video_card.dart';
import '../../widgets/chapter/note_card.dart';
import '../../widgets/chapter/practice_question_card.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/platform_helper.dart';
import '../../utils/constants.dart';

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
    with
        BaseScreenMixin<ChapterContentScreen>,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  static const double _tabShellHeight = kTextTabBarHeight + 1;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final RefreshController _videosRefreshController = RefreshController();
  final RefreshController _notesRefreshController = RefreshController();
  final RefreshController _practiceRefreshController = RefreshController();

  Chapter? _chapter;
  Category? _category;

  bool _hasAccess = false;
  bool _isCheckingAccess = true;
  String? _errorMessage;

  bool _hasCachedData = false;
  bool _isLoading = true;
  bool _initialContentLoadSettled = false;
  bool _showVideosRefreshShimmer = false;
  bool _showNotesRefreshShimmer = false;
  bool _showPracticeRefreshShimmer = false;

  // Video players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  media_kit.Player? _mediaKitPlayer;
  media_kit_video.VideoController? _mediaKitVideoController;
  bool _isPlayingVideo = false;
  bool _isVideoDialogOpen = false;
  bool _isPlayerInitialized = false;
  String? _currentPlaybackQualityLabel;
  double _currentPlaybackSpeed = 1.0;
  StateSetter? _videoDialogStateSetter;

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

  String? _currentUserId;

  late VideoProvider _videoProvider;
  late NoteProvider _noteProvider;
  late QuestionProvider _questionProvider;
  late ChapterProvider _chapterProvider;
  late CourseProvider _courseProvider;
  late CategoryProvider _categoryProvider;
  late SubscriptionProvider _subscriptionProvider;
  late AuthProvider _authProvider;
  late ProgressProvider _progressProvider;
  late SettingsProvider _settingsProvider;
  bool _providersBound = false;
  bool _didSeedImmediateState = false;

  @override
  String get screenTitle => _chapter?.name ?? AppStrings.chapter;

  @override
  String? get screenSubtitle => isOffline
      ? AppStrings.offlineMode
      : context.read<SettingsProvider>().getChapterContentSubtitle();

  @override
  bool get isLoading => _isLoading && !_hasCachedData;

  @override
  bool get hasCachedData => _hasCachedData;

  @override
  dynamic get errorMessage => _errorMessage;

  @override
  bool get useFullScreenLoadingState => false;

  @override
  bool get blockContentWhenOffline => false;

  // ✅ Shimmer type based on current tab
  @override
  ShimmerType get shimmerType {
    switch (_tabController.index) {
      case 0:
        return ShimmerType.videoCard;
      case 1:
        return ShimmerType.noteCard;
      case 2:
        return ShimmerType.rectangle;
      default:
        return ShimmerType.textLine;
    }
  }

  @override
  int get shimmerItemCount => 5;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context)),
        onPressed: () => context.pop(),
      );

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
    if (_providersBound) return;

    _videoProvider = context.read<VideoProvider>();
    _noteProvider = context.read<NoteProvider>();
    _questionProvider = context.read<QuestionProvider>();
    _chapterProvider = context.read<ChapterProvider>();
    _courseProvider = context.read<CourseProvider>();
    _categoryProvider = context.read<CategoryProvider>();
    _subscriptionProvider = context.read<SubscriptionProvider>();
    _authProvider = context.read<AuthProvider>();
    _progressProvider = context.read<ProgressProvider>();
    _settingsProvider = context.read<SettingsProvider>();
    _providersBound = true;

    _seedImmediateState();

    unawaited(_getCurrentUserId());
  }

  void _seedImmediateState() {
    if (_didSeedImmediateState) return;

    _chapter = widget.chapter;
    _category = widget.category;

    if (_chapter == null) return;

    _hasAccess = widget.hasAccess == true ||
        _chapter!.isFree ||
        (_category != null &&
            _subscriptionProvider.hasActiveSubscriptionForCategory(
              _category!.id,
            ));
    _hasCachedData = true;
    _isLoading = false;
    _isCheckingAccess = false;
    _errorMessage = null;
    _didSeedImmediateState = true;
  }

  @override
  void dispose() {
    _disposeAllPlayers();
    _cleanupResources();
    _videosRefreshController.dispose();
    _notesRefreshController.dispose();
    _practiceRefreshController.dispose();
    _dio.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeAllPlayers() {
    _isVideoDialogOpen = false;
    _isPlayingVideo = false;
    _isPlayerInitialized = false;
    _currentPlaybackQualityLabel = null;
    _currentPlaybackSpeed = 1.0;
    _videoDialogStateSetter = null;

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
    _tabController.dispose();
    _scrollController.dispose();
  }

  void _refreshVideoUi([VoidCallback? update]) {
    if (isMounted) {
      setState(() {
        update?.call();
      });
    } else {
      update?.call();
    }

    _videoDialogStateSetter?.call(() {});
  }

  Duration _clampSeekPosition(Duration position, Duration duration) {
    if (duration <= Duration.zero) return position;
    if (position <= Duration.zero) return Duration.zero;
    if (position >= duration) {
      return duration > const Duration(seconds: 1)
          ? duration - const Duration(seconds: 1)
          : Duration.zero;
    }
    return position;
  }

  String _formatPlaybackSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed.toString()}x';
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = _authProvider.currentUser?.id.toString();
  }

  Future<Directory> _getAppCacheDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/.familyacademy_cache/videos');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  Future<void> _loadCachedContent() async {
    if (_currentUserId == null) {
      await _getCurrentUserId();
    }
    if (_currentUserId == null) return;

    try {
      final deviceService = _authProvider.deviceService;

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
      if (_cachedVideoPaths.isNotEmpty || _cachedNotePaths.isNotEmpty) {
        _hasCachedData = true;
      }
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
    if (widget.chapter != null) {
      _chapter = widget.chapter;
      _category = widget.category;
      _hasAccess = widget.hasAccess == true ||
          _cachedVideoPaths.isNotEmpty ||
          _cachedNotePaths.isNotEmpty;
      _hasCachedData = true;
      return;
    }

    for (final category in _categoryProvider.categories) {
      final courses = _courseProvider.getCoursesByCategory(category.id);
      for (final course in courses) {
        final chapters = _chapterProvider.getChaptersByCourse(course.id);
        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            _chapter = chapter;
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
      _hasAccess = _subscriptionProvider
              .hasActiveSubscriptionForCategory(_category!.id) ||
          _cachedVideoPaths.isNotEmpty ||
          _cachedNotePaths.isNotEmpty;
    }
  }

  Future<void> _refreshInBackground() async {
    if (isRefreshing) return;
    try {
      await _checkAccessAndLoadData(forceRefresh: true);
    } catch (e) {
      debugLog('ChapterContent', 'Background refresh error: $e');
    }
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      SnackbarService().showOffline(context);
      return;
    }

    final hasVideos =
        _videoProvider.getVideosByChapter(widget.chapterId).isNotEmpty;
    final hasNotes =
        _noteProvider.getNotesByChapter(widget.chapterId).isNotEmpty;
    final hasQuestions =
        _questionProvider.getQuestionsByChapter(widget.chapterId).isNotEmpty;

    if (mounted) {
      setState(() {
        _showVideosRefreshShimmer = !hasVideos;
        _showNotesRefreshShimmer = !hasNotes;
        _showPracticeRefreshShimmer = !hasQuestions;
      });
    }

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
    } catch (e) {
      if (!isMounted) return;
      if (_looksLikeNetworkError(e)) {
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        SnackbarService().showInfo(
          context,
          _chapter != null
              ? 'We could not refresh this chapter just now. Your saved content is still available.'
              : AppStrings.refreshFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _showVideosRefreshShimmer = false;
          _showNotesRefreshShimmer = false;
          _showPracticeRefreshShimmer = false;
        });
      }
    }
  }

  bool _looksLikeNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('network error') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('offline');
  }

  Future<void> _checkAccessAndLoadData({bool forceRefresh = false}) async {
    if (!_authProvider.isAuthenticated) {
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
    } else if (isOffline &&
        (_cachedVideoPaths.isNotEmpty || _cachedNotePaths.isNotEmpty)) {
      _hasAccess = true;
    } else if (_category != null) {
      if (!isOffline && forceRefresh) {
        _hasAccess = await _subscriptionProvider
            .checkHasActiveSubscriptionForCategory(_category!.id);
      } else {
        _hasAccess = _subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);
      }
    } else {
      _hasAccess = false;
    }

    setState(() => _isCheckingAccess = false);

    if (_hasAccess) {
      await _loadContent(forceRefresh: forceRefresh && !isOffline);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadChapterData(bool forceRefresh) async {
    if (_categoryProvider.categories.isEmpty) {
      await _categoryProvider.loadCategories(
          forceRefresh: forceRefresh && !isOffline);
    }

    for (final category in _categoryProvider.categories) {
      if (!_courseProvider.hasLoadedCategory(category.id)) {
        await _courseProvider.loadCoursesByCategory(
          category.id,
          forceRefresh: forceRefresh && !isOffline,
        );
      }

      final courses = _courseProvider.getCoursesByCategory(category.id);
      for (final course in courses) {
        if (!_chapterProvider.hasLoadedForCourse(course.id)) {
          await _chapterProvider.loadChaptersByCourse(
            course.id,
            forceRefresh: forceRefresh && !isOffline,
          );
        }

        final chapters = _chapterProvider.getChaptersByCourse(course.id);
        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            _chapter = chapter;
            _category = category;
            return;
          }
        }
      }
    }
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    try {
      await Future.wait([
        _videoProvider.loadVideosByChapter(widget.chapterId,
            forceRefresh: forceRefresh),
        _noteProvider.loadNotesByChapter(widget.chapterId,
            forceRefresh: forceRefresh),
        _questionProvider.loadPracticeQuestions(widget.chapterId,
            forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      if (!isMounted) return;
      if (_looksLikeNetworkError(e)) {
        // Already offline state handled by base mixin
      }
    }
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

  Future<void> _switchQuality(Video video, VideoQuality quality) async {
    if (!_isVideoDialogOpen) return;

    _refreshVideoUi(() {
      _isPlayerInitialized = false;
      _currentPlaybackQualityLabel = quality.label;
    });

    try {
      if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
        final player = _mediaKitPlayer!;
        final currentPosition = player.state.position;
        final wasPlaying = player.state.playing;

        await player.open(media_kit.Media(quality.url), play: false);
        await player.seek(currentPosition);
        await player.setRate(_currentPlaybackSpeed);
        if (wasPlaying) {
          await player.play();
        }
        _refreshVideoUi(() => _isPlayerInitialized = true);
      } else if (_videoController != null && _chewieController != null) {
        final oldVideoController = _videoController!;
        final oldChewieController = _chewieController!;
        final wasPlaying = oldVideoController.value.isPlaying;
        final currentPosition = oldVideoController.value.position;

        final newVideoController =
            VideoPlayerController.networkUrl(Uri.parse(quality.url));
        await newVideoController.initialize();

        final targetPosition = _clampSeekPosition(
          currentPosition,
          newVideoController.value.duration,
        );
        if (targetPosition > Duration.zero) {
          await newVideoController.seekTo(targetPosition);
        }
        await newVideoController.setPlaybackSpeed(_currentPlaybackSpeed);

        final newChewieController = ChewieController(
          videoPlayerController: newVideoController,
          showOptions: false,
          playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5],
        );

        _videoController = newVideoController;
        _chewieController = newChewieController;

        if (wasPlaying) {
          await newVideoController.play();
        }

        await oldChewieController.pause();
        oldChewieController.dispose();
        unawaited(oldVideoController.dispose());

        _refreshVideoUi(() => _isPlayerInitialized = true);
      }
    } catch (e) {
      debugLog('VideoCard', 'Error switching quality: $e');
      _refreshVideoUi(() => _isPlayerInitialized = true);
      if (isMounted) {
        SnackbarService().showError(context, AppStrings.failedToSwitchQuality);
      }
    }
  }

  Future<void> _showStreamingQualitySelector(Video video) async {
    final quality = await _showQualitySelector(video, forPlayback: true);
    if (quality != null && isMounted) {
      _refreshVideoUi(() {
        _currentPlaybackQualityLabel = quality.label;
      });

      try {
        await _switchQuality(video, quality);
      } catch (e) {
        SnackbarService().showError(context, AppStrings.failedToChangeQuality);
      }
    }
  }

  Future<void> _showSpeedSelector(Video video) async {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
    final selectedSpeed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.selectPlaybackSpeed),
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
        isMounted) {
      final previousSpeed = _currentPlaybackSpeed;
      _refreshVideoUi(() {
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
        _refreshVideoUi(() {
          _currentPlaybackSpeed = previousSpeed;
        });
        SnackbarService().showError(context, AppStrings.failedToChangeSpeed);
      }
    }
  }

  Future<void> _playVideo(Video video) async {
    if (_isVideoDialogOpen) return;
    if (!isMounted) return;

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
        ),
      ),
    ));

    try {
      if (_cachedVideoPaths.containsKey(video.id)) {
        final localPath = _cachedVideoPaths[video.id]!;
        if (isMounted) Navigator.pop(context);
        await _playLocalVideo(video, localPath);
        return;
      }

      if (isOffline) {
        if (isMounted) Navigator.pop(context);
        SnackbarService().showOffline(context, action: AppStrings.playVideo);
        return;
      }

      VideoQuality? selectedQuality;

      if (video.hasQualities) {
        if (isMounted) Navigator.pop(context);
        selectedQuality = await _showQualitySelector(video, forPlayback: true);
        if (selectedQuality == null) return;

        setState(() {
          _currentPlaybackQualityLabel = selectedQuality?.label;
        });

        if (!isMounted) return;
        unawaited(showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
            ),
          ),
        ));
      } else {
        selectedQuality = video.getRecommendedQuality();
        setState(() {
          _currentPlaybackQualityLabel = selectedQuality?.label;
        });
      }

      if (isMounted) Navigator.pop(context);
      await _playNetworkVideo(video, selectedQuality.url);
    } catch (e) {
      if (isMounted) {
        Navigator.pop(context);
        SnackbarService()
            .showError(context, AppStrings.failedToPlayVideoSimple);
      }
    }
  }

  Future<void> _playLocalVideo(Video video, String localPath) async {
    _disposeAllPlayers();

    try {
      _refreshVideoUi(() {
        _isPlayingVideo = true;
        _isVideoDialogOpen = true;
        _isPlayerInitialized = false;
        _currentPlaybackQualityLabel = AppStrings.offlineQuality;
      });

      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

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
      if (isMounted) {
        SnackbarService()
            .showError(context, AppStrings.failedToPlayDownloadedVideo);
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

      if (!isMounted) return;

      _refreshVideoUi(() => _isPlayerInitialized = true);
      await _videoProvider.incrementViewCount(video.id);

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
          SnackbarService().showError(context, AppStrings.videoPlaybackFailed);
        }
      } else {
        await _playWithVideoPlayer(video, videoUrl);
      }
    } catch (e) {
      setState(() {
        _isVideoDialogOpen = false;
        _isPlayingVideo = false;
        _isPlayerInitialized = false;
      });

      if (isMounted) {
        SnackbarService().showError(context, AppStrings.failedToPlayVideo);
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

      if (!isMounted) return;

      setState(() => _isPlayerInitialized = true);
      await _videoProvider.incrementViewCount(video.id);

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
        unawaited(_videoController!.dispose());
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

      if (!isMounted) return;

      await _videoProvider.incrementViewCount(video.id);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5],
      );

      _refreshVideoUi(() => _isPlayerInitialized = true);

      try {
        await WakelockPlus.enable();
      } catch (e) {}

      if (!isMounted) return;

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
    return StatefulBuilder(
      builder: (context, setDialogState) {
        _videoDialogStateSetter = setDialogState;
        return Dialog(
          insetPadding: ResponsiveValues.modalInsetPaddingSmall(context),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusXLarge(context),
            ),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: PlatformHelper.isLinux &&
                          _mediaKitVideoController != null
                      ? media_kit_video.Video(
                          controller: _mediaKitVideoController!)
                      : (_chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : const Center(child: CircularProgressIndicator())),
                ),
                if (!_isPlayerInitialized)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.telegramBlue),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: ResponsiveValues.spacingS(context),
                  right: ResponsiveValues.spacingS(context),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        if (isMounted) _onVideoClosed(video);
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: ResponsiveValues.spacingS(context),
                  left: ResponsiveValues.spacingS(context),
                  child: Row(
                    children: [
                      Container(
                        padding:
                            ResponsiveValues.mediaOverlayChipPadding(context),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF0088CC), Color(0xFF0055AA)]),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                        ),
                        child: Text(
                          _currentPlaybackQualityLabel ??
                              video.getRecommendedQuality().label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveValues.mediaOverlayChipTextSize(
                                context),
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Container(
                        padding:
                            ResponsiveValues.mediaOverlayChipPadding(context),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFF7931E)]),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                        ),
                        child: Text(
                          _formatPlaybackSpeed(_currentPlaybackSpeed),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveValues.mediaOverlayChipTextSize(
                                context),
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Container(
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.settings,
                              color: Colors.white, size: 20),
                          onPressed: () => _showStreamingQualitySelector(video),
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Container(
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
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
      },
    );
  }

  Future<void> _onVideoClosed(Video video) async {
    _refreshVideoUi(() => _isVideoDialogOpen = false);

    int progress = 0;
    try {
      if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
        try {
          final position = _mediaKitPlayer!.state.position;
          final duration = _mediaKitPlayer!.state.duration;
          progress = duration.inSeconds > 0
              ? (position.inSeconds / duration.inSeconds * 100).toInt()
              : 0;
        } catch (e) {}
      } else if (_videoController != null) {
        try {
          final position = _videoController!.value.position;
          final duration = _videoController!.value.duration;
          progress = duration.inSeconds > 0
              ? (position.inSeconds / duration.inSeconds * 100).toInt()
              : 0;
        } catch (e) {}
      }

      if (PlatformHelper.shouldUseMediaKit && _mediaKitPlayer != null) {
        unawaited(_mediaKitPlayer?.stop());
        unawaited(_mediaKitPlayer?.dispose());
        _mediaKitPlayer = null;
        _mediaKitVideoController = null;
      } else if (_chewieController != null) {
        unawaited(_chewieController?.pause());
        _chewieController?.dispose();
        _chewieController = null;

        if (_videoController != null) {
          unawaited(_videoController?.dispose());
          _videoController = null;
        }
      }

      await WakelockPlus.disable();
    } catch (e) {
      debugLog('VideoCard', 'Error disposing player: $e');
    }

    try {
      await _progressProvider.saveChapterProgress(
        chapterId: widget.chapterId,
        videoProgress: progress,
      );
    } finally {
      _disposeAllPlayers();
    }
  }

  Future<VideoQuality?> _showQualitySelector(Video video,
      {bool forPlayback = false}) async {
    if (_cachedVideoPaths.containsKey(video.id)) {
      final downloadedQuality =
          _videoProvider.getDownloadQuality(video.id)?.label;
      final message = downloadedQuality == null
          ? '${AppStrings.videoAlreadyDownloaded}. Use Remove on the card to delete it.'
          : '${AppStrings.videoAlreadyDownloaded} in $downloadedQuality. Use Remove on the card to delete it.';
      SnackbarService().showInfo(context, message);
      return null;
    }

    final availableQualities = video.availableQualities;

    if (availableQualities.isEmpty) {
      return VideoQuality(label: '480p', url: video.fullVideoUrl, height: 480);
    }

    final savedPreference = await _videoProvider.getQualityPreference(video.id);
    final recommendedQuality =
        video.getRecommendedQuality(await _getConnectionType());

    VideoQuality? preSelected;
    if (savedPreference != null) {
      preSelected = availableQualities.firstWhere(
        (q) => q.label == savedPreference,
        orElse: () => recommendedQuality,
      );
    }

    final Completer<VideoQuality?> completer = Completer();

    if (forPlayback) {
      await _fetchActualFileSizes(availableQualities);
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveValues.radiusXXLarge(context)),
          ),
        ),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
              width: ResponsiveValues.modalHandleWidth(context),
              height: ResponsiveValues.modalHandleHeight(context),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusSmall(context),
                ),
              ),
            ),
            Padding(
              padding: ResponsiveValues.modalHeaderPadding(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    forPlayback
                        ? AppStrings.selectQuality
                        : AppStrings.downloadQuality,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                  width: ResponsiveValues.selectionSheetLeadingSize(context),
                  height: ResponsiveValues.selectionSheetLeadingSize(context),
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
                      ),
                    ),
                    if (isRecommended) ...[
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingXS(context),
                          vertical: ResponsiveValues.spacingXXS(context),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0088CC),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                        child: const Text(
                          AppStrings.best,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: ResponsiveValues.spacingXXS(context)),
                    Text(_getQualityDescription(quality)),
                    if (quality.estimatedSize > 0) ...[
                      SizedBox(
                          height: ResponsiveValues.spacingXXS(context) / 2),
                      Row(
                        children: [
                          Icon(Icons.storage_rounded,
                              size: 12, color: Colors.grey[600]),
                          SizedBox(width: ResponsiveValues.spacingXXS(context)),
                          Text(
                            'Size: ${quality.formattedSize}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF0088CC))
                    : null,
                onTap: () {
                  _videoProvider.saveQualityPreference(video.id, quality.label);
                  Navigator.pop(context);
                  completer.complete(quality);
                },
              );
            }),
            SizedBox(height: ResponsiveValues.spacingL(context)),
          ],
        ),
      ),
    );

    return completer.future;
  }

  Future<void> _fetchActualFileSizes(List<VideoQuality> qualities) async {
    for (final quality in qualities) {
      try {
        final response = await _dio.head(
          quality.url,
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
            sendTimeout: const Duration(seconds: 5),
            headers: {'Accept-Encoding': 'identity'},
          ),
        );

        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          final size = int.tryParse(contentLength) ?? 0;
          if (size > 0) {
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
    if (isOffline) return 'offline';
    if (PlatformHelper.isTv) return 'wifi';
    if (PlatformHelper.isDesktop) return 'wifi';
    return 'mobile';
  }

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
            SnackbarService().showError(context, AppStrings.storageAlmostFull);
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

    _videoProvider.setDownloadState(video.id, true, 0.0);

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
          if (total != -1 && isMounted) {
            final progress = received / total;
            setState(() => _downloadProgress[video.id] = progress);
            _videoProvider.updateDownloadProgress(
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

      final qualityLevel = VideoQualityLevel.fromHeight(quality.height);

      _videoProvider.setDownloadState(video.id, false, 1.0);
      _videoProvider.setDownloadedVideoPath(video.id, filePath, qualityLevel);

      await _saveCacheMetadata();

      if (isMounted) {
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

      if (isMounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        _videoProvider.setDownloadState(video.id, false, 0.0);
        SnackbarService().showError(context, errorMessage);
      }
      debugLog('VideoCard', 'Download error: $e');
    } catch (e) {
      if (isMounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        _videoProvider.setDownloadState(video.id, false, 0.0);
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
          sendTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && isMounted) {
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

      if (isMounted) {
        SnackbarService().showSuccess(context, AppStrings.noteDownloaded);
      }
    } catch (e) {
      if (isMounted) {
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
      final deviceService = _authProvider.deviceService;

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
      final deviceService = _authProvider.deviceService;

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

  Future<void> _checkAllQuestions(List<Question> questions) async {
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
            await _questionProvider.checkAnswer(questionId, selectedAnswer);
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
    final answeredCount = _questionAnswered.values.where((v) => v).length;
    await _progressProvider.saveChapterProgress(
      chapterId: widget.chapterId,
      questionsAttempted: answeredCount,
      questionsCorrect: correctCount,
    );

    if (isMounted) {
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
    try {
      final result =
          await _questionProvider.checkAnswer(questionId, selectedOption);
      final isCorrect = result.data?['is_correct'] == true;

      setState(() {
        _showExplanation[questionId] = true;
        _isQuestionCorrect[questionId] = isCorrect;
        _questionAnswered[questionId] = true;
      });

      await _saveQuestionProgress();
      final answeredCount = _questionAnswered.values.where((v) => v).length;
      final correctCount = _isQuestionCorrect.values.where((v) => v).length;
      await _progressProvider.saveChapterProgress(
        chapterId: widget.chapterId,
        questionsAttempted: answeredCount,
        questionsCorrect: correctCount,
      );
    } catch (e) {
      if (isMounted) {
        SnackbarService().showError(context, AppStrings.failedToCheckAnswer);
      }
    }
  }

  Future<void> _initialize() async {
    await _loadCachedContent();
    await _initializeFromCache();

    if (_chapter != null && _hasCachedData) {
      if (_hasAccess || (_chapter?.isFree ?? false)) {
        await _loadContent();
      }
      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
      if (!isOffline) {
        unawaited(_refreshInBackground());
      }
    } else {
      await _checkAccessAndLoadData();
    }

    _initialContentLoadSettled = true;
  }

  bool _shouldShowInitialTabShimmer({
    required bool hasItems,
    required bool isProviderLoading,
    required bool hasLoadedForChapter,
    required bool showRefreshShimmer,
  }) {
    if (hasItems || isOffline) return false;
    if (showRefreshShimmer) return true;
    if (_isLoading || _isCheckingAccess) return true;
    if (!_initialContentLoadSettled) return true;
    if (isProviderLoading) return true;
    if (!hasLoadedForChapter) return true;
    return false;
  }

  Widget _buildAccessDeniedScreen() {
    final isFree = _chapter?.isFree ?? false;

    return Center(
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
                    ? _settingsProvider.getChapterComingSoonMessage()
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
              Builder(
                builder: (context) {
                  final hasExpiredSubscription = _category != null &&
                      _subscriptionProvider.expiredSubscriptions
                          .any((sub) => sub.categoryId == _category!.id);

                  return AppButton.primary(
                    label: hasExpiredSubscription
                        ? AppStrings.renewNow
                        : AppStrings.purchaseAccess,
                    onPressed: () => context.push('/payment', extra: {
                      'category': _category,
                      'paymentType':
                          hasExpiredSubscription ? 'repayment' : 'first_time',
                    }),
                  );
                },
              ),
            ],
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            AppButton.outline(
                label: AppStrings.goBack, onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildPageLoadingShell() {
    return Column(
      children: [
        _buildTabShell(),
        Expanded(child: buildLoadingShimmer()),
      ],
    );
  }

  Widget _buildVideosTab() {
    final videos = _videoProvider.getVideosByChapter(widget.chapterId);
    final isWaitingForInitialContent = _shouldShowInitialTabShimmer(
      hasItems: videos.isNotEmpty,
      isProviderLoading: _videoProvider.isLoadingForChapter(widget.chapterId),
      hasLoadedForChapter: _videoProvider.hasLoadedForChapter(widget.chapterId),
      showRefreshShimmer: _showVideosRefreshShimmer,
    );

    if (isWaitingForInitialContent) {
      return buildLoadingShimmer();
    }

    if (videos.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        children: [
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          Center(
            child: buildEmptyWidget(
              dataType: AppStrings.videos,
              customMessage: isOffline
                  ? AppStrings.noCachedVideos
                  : AppStrings.noVideosForChapter,
              isOffline: isOffline,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveValues.screenPadding(context),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
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
    );
  }

  Widget _buildNotesTab() {
    final notes = _noteProvider.getNotesByChapter(widget.chapterId);
    final isWaitingForInitialContent = _shouldShowInitialTabShimmer(
      hasItems: notes.isNotEmpty,
      isProviderLoading: _noteProvider.isLoadingForChapter(widget.chapterId),
      hasLoadedForChapter: _noteProvider.hasLoadedForChapter(widget.chapterId),
      showRefreshShimmer: _showNotesRefreshShimmer,
    );

    if (isWaitingForInitialContent) {
      return buildLoadingShimmer();
    }

    if (notes.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        children: [
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          Center(
            child: buildEmptyWidget(
              dataType: AppStrings.notes,
              customMessage: isOffline
                  ? context
                      .read<SettingsProvider>()
                      .getChapterNotesOfflineEmptyMessage()
                  : context
                      .read<SettingsProvider>()
                      .getChapterNotesEmptyMessage(),
              isOffline: isOffline,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveValues.screenPadding(context),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isDownloaded = _cachedNotePaths.containsKey(note.id);
        final isDownloading = _isDownloading[note.id] == true;
        final downloadProgress = _downloadProgress[note.id] ?? 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: NoteCard(
            note: note,
            chapterId: widget.chapterId,
            index: index,
            isDownloaded: isDownloaded,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            onTap: () {
              _progressProvider.saveChapterProgress(
                chapterId: note.chapterId,
                notesViewed: true,
              );
              _noteProvider.markNoteAsViewed(note.id);
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
    );
  }

  Widget _buildPracticeTab() {
    final questions = _questionProvider.getQuestionsByChapter(widget.chapterId);
    final answeredCount = _questionAnswered.values.where((v) => v).length;
    final correctCount = _isQuestionCorrect.values.where((v) => v).length;
    final totalCount = questions.length;
    final progress = totalCount > 0 ? answeredCount / totalCount : 0.0;

    final isWaitingForInitialContent = _shouldShowInitialTabShimmer(
      hasItems: questions.isNotEmpty,
      isProviderLoading:
          _questionProvider.isLoadingForChapter(widget.chapterId),
      hasLoadedForChapter:
          _questionProvider.hasLoadedForChapter(widget.chapterId),
      showRefreshShimmer: _showPracticeRefreshShimmer,
    );

    if (isWaitingForInitialContent) {
      return buildLoadingShimmer();
    }

    if (questions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        children: [
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          Center(
            child: buildEmptyWidget(
              dataType: AppStrings.practiceQuestions,
              customMessage: isOffline
                  ? context
                      .read<SettingsProvider>()
                      .getChapterPracticeOfflineEmptyMessage()
                  : context
                      .read<SettingsProvider>()
                      .getChapterPracticeEmptyMessage(),
              isOffline: isOffline,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
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
                              colors: AppColors.blueGradient),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                        ),
                        child: Text(
                          '$correctCount/$totalCount',
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Answered $answeredCount of $totalCount',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
        Container(
          color: AppColors.getBackground(context),
          padding: EdgeInsets.fromLTRB(
            ResponsiveValues.sectionPadding(context),
            0,
            ResponsiveValues.sectionPadding(context),
            ResponsiveValues.spacingS(context),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
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
          Padding(
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
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            itemCount: questions.length,
            itemBuilder: (context, index) {
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
          ),
        ),
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

  @override
  Widget buildContent(BuildContext context) {
    if (_errorMessage != null) {
      return buildErrorWidget(_errorMessage!, onRetry: _initialize);
    }

    if (_chapter == null && (_isLoading || _isCheckingAccess)) {
      return _buildPageLoadingShell();
    }

    if (_chapter == null) {
      return buildErrorWidget(
        isOffline
            ? AppStrings.noCachedDataAvailable
            : AppStrings.chapterDoesNotExist,
        onRetry: onRefresh,
      );
    }

    if (!_hasAccess && !_isCheckingAccess) {
      if (_chapter?.isFree == true) {
        return _buildPageLoadingShell();
      }
      return _buildAccessDeniedScreen();
    }

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabShellHeaderDelegate(
            minExtentValue: _tabShellHeight,
            maxExtentValue: _tabShellHeight,
            child: Container(
              color: AppColors.getBackground(context),
              child: _buildTabShell(),
            ),
          ),
        ),
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRefreshableTab(
                child: _buildVideosTab(),
                controller: _videosRefreshController,
              ),
              _buildRefreshableTab(
                child: _buildNotesTab(),
                controller: _notesRefreshController,
              ),
              _buildRefreshableTab(
                child: _buildPracticeTab(),
                controller: _practiceRefreshController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabShell() {
    return SizedBox(
      height: _tabShellHeight,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.getDivider(context).withValues(alpha: 0.7),
              width: 0.6,
            ),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.videos),
            Tab(text: AppStrings.notes),
            Tab(text: AppStrings.practice),
          ],
          labelStyle: AppTextStyles.labelMedium(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTextStyles.labelMedium(context),
          indicatorColor: AppColors.telegramBlue,
          indicatorWeight: 2.5,
          labelColor: AppColors.telegramBlue,
          unselectedLabelColor: AppColors.getTextSecondary(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showRefreshIndicator: false,
    );
  }

  Widget _buildRefreshableTab({
    required Widget child,
    required RefreshController controller,
  }) {
    return SmartRefresher(
      controller: controller,
      onRefresh: () async {
        await onRefresh();
        if (mounted) {
          controller.refreshCompleted();
        }
      },
      header: WaterDropHeader(
        waterDropColor: AppColors.telegramBlue,
        refresh: SizedBox(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _TabShellHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  _TabShellHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabShellHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
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
          if (hasFile && cachedPath != null && isPdf)
            Expanded(child: _buildPdfViewer(cachedPath!))
          else
            Expanded(child: _buildTextContent(context, note.content)),
        ],
      ),
    );
  }
}
