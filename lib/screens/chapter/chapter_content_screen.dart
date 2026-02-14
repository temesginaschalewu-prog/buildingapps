import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/video_model.dart';
import 'package:familyacademyclient/models/note_model.dart';
import 'package:familyacademyclient/models/question_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/providers/video_provider.dart';
import 'package:familyacademyclient/providers/note_provider.dart';
import 'package:familyacademyclient/providers/question_provider.dart';
import 'package:familyacademyclient/providers/chapter_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/common/error_widget.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';

// Platform-specific imports
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;

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

  // Video players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  media_kit.Player? _mediaKitPlayer;
  media_kit_video.VideoController? _mediaKitVideoController;
  int? _currentPlayingVideoId;
  bool _isPlayingVideo = false;
  bool _useMediaKit =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  final Map<int, String?> _selectedAnswers = {};
  final Map<int, bool> _showExplanation = {};
  final Map<int, bool> _isQuestionCorrect = {};

  // Secure storage - using app-specific directories only, not accessible to users
  final Map<int, String> _cachedVideoPaths = {};
  final Map<int, String> _cachedNotePaths = {};
  final Map<int, bool> _isCaching = {};
  final Map<int, double> _cacheProgress = {};
  final Dio _dio = Dio();

  StreamSubscription? _videoUpdateSubscription;
  StreamSubscription? _noteUpdateSubscription;
  StreamSubscription? _questionUpdateSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    // Initialize MediaKit for desktop platforms
    if (_useMediaKit) {
      try {
        debugLog('ChapterContent', '✅ MediaKit initialized for desktop');
      } catch (e) {
        debugLog('ChapterContent', '⚠️ MediaKit initialization error: $e');
        _useMediaKit = false;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupStreamListeners();
  }

  @override
  void dispose() {
    _disposeVideoPlayer();
    _disposeMediaKitPlayer();
    _cleanupResources();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disposeMediaKitPlayer() {
    try {
      _mediaKitVideoController = null;
      _mediaKitPlayer?.dispose();
      _mediaKitPlayer = null;
    } catch (e) {
      debugLog('ChapterContent', 'Error disposing MediaKit player: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pauseVideo();
        break;
      case AppLifecycleState.resumed:
        _resumeVideoIfNeeded();
        break;
      default:
        break;
    }
  }

  void _cleanupResources() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _videoUpdateSubscription?.cancel();
    _videoUpdateSubscription = null;

    _noteUpdateSubscription?.cancel();
    _noteUpdateSubscription = null;

    _questionUpdateSubscription?.cancel();
    _questionUpdateSubscription = null;

    _tabController.dispose();
    _scrollController.dispose();
    _dio.close();
  }

  Future<void> _initialize() async {
    try {
      await _loadCachedContent();
      await _initializeFromCache();

      if (_chapter != null && _hasCachedData) {
        debugLog('ChapterContent', '📦 Showing cached chapter data');
        setState(() {
          _isLoading = false;
          _isCheckingAccess = false;
        });

        _refreshInBackground();
      } else {
        await _checkAccessAndLoadData();
      }

      _setupBackgroundRefresh();
      debugLog('ChapterContent', '✅ Initialization complete');
    } catch (e) {
      _errorMessage = 'Failed to initialize: ${e.toString()}';
      debugLog('ChapterContent', '❌ Initialization error: $e');
      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
    }
  }

  // Get app-specific cache directory (not accessible to users via file explorer)
  Future<Directory> _getAppCacheDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/.familyacademy_cache/videos');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  Future<void> _loadCachedContent() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final videoPaths = await deviceService.getCacheItem<Map<String, dynamic>>(
          'cached_videos_chapter_${widget.chapterId}',
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
          'cached_notes_chapter_${widget.chapterId}',
          isUserSpecific: true);

      if (notePaths != null) {
        for (final entry in notePaths.entries) {
          final noteId = int.tryParse(entry.key);
          final notePath = entry.value as String?;
          if (noteId != null && notePath != null) {
            final file = File(notePath);
            if (await file.exists()) {
              _cachedNotePaths[noteId] = notePath;
            }
          }
        }
      }

      debugLog('ChapterContent',
          'Loaded ${_cachedVideoPaths.length} cached videos and ${_cachedNotePaths.length} cached notes');
    } catch (e) {
      debugLog('ChapterContent', 'Error loading cached content: $e');
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
    debugLog('ChapterContent', '🔄 Background refresh started');

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
      debugLog('ChapterContent', '✅ Background refresh complete');
    } catch (e) {
      debugLog('ChapterContent', 'Background refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _checkAccessAndLoadData(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content updated'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugLog('ChapterContent', 'Manual refresh error: $e');
      setState(() {
        _isOffline = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed, using cached data'),
            backgroundColor: AppColors.telegramRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _checkAccessAndLoadData({bool forceRefresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!authProvider.isAuthenticated) {
      _errorMessage = 'Authentication required';
      setState(() {
        _isCheckingAccess = false;
      });
      return;
    }

    if (_chapter == null) {
      await _loadChapterData(forceRefresh);
    }

    if (_chapter == null) {
      _errorMessage = 'Chapter not found';
      setState(() {
        _isCheckingAccess = false;
      });
      return;
    }

    if (_category != null) {
      if (forceRefresh) {
        _hasAccess = await subscriptionProvider
            .checkHasActiveSubscriptionForCategory(_category!.id);
      } else {
        _hasAccess = subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);
      }
    } else {
      _hasAccess = _chapter!.isFree;
    }

    debugLog('ChapterContent',
        'Access: Free=${_chapter!.isFree}, HasAccess=$_hasAccess');

    setState(() {
      _isCheckingAccess = false;
    });

    if (_hasAccess) {
      await _loadContent(forceRefresh: forceRefresh);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadChapterData(bool forceRefresh) async {
    final chapterProvider = context.read<ChapterProvider>();
    final courseProvider = context.read<CourseProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    if (categoryProvider.categories.isEmpty) {
      await categoryProvider.loadCategories(forceRefresh: forceRefresh);
    }

    for (final category in categoryProvider.categories) {
      if (!courseProvider.hasLoadedCategory(category.id)) {
        await courseProvider.loadCoursesByCategory(category.id,
            forceRefresh: forceRefresh);
      }

      final courses = courseProvider.getCoursesByCategory(category.id);

      for (final course in courses) {
        if (!chapterProvider.hasLoadedForCourse(course.id)) {
          await chapterProvider.loadChaptersByCourse(course.id,
              forceRefresh: forceRefresh);
        }

        final chapters = chapterProvider.getChaptersByCourse(course.id);

        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            _chapter = chapter;
            _course = course;
            _category = category;
            debugLog('ChapterContent',
                'Found chapter: ${chapter.name} in course: ${course.name}');
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

      debugLog('ChapterContent', '✅ Content loaded successfully');
    } catch (e) {
      debugLog('ChapterContent', '❌ Error loading content: $e');
      setState(() {
        _isOffline = true;
      });
    }
  }

  void _setupBackgroundRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (mounted && _hasAccess && !_isRefreshing) {
        await _refreshInBackground();
      }
    });
  }

  void _setupStreamListeners() {
    final videoProvider = context.read<VideoProvider>();
    final noteProvider = context.read<NoteProvider>();
    final questionProvider = context.read<QuestionProvider>();

    _videoUpdateSubscription = videoProvider.videoUpdates.listen((_) {
      if (mounted) setState(() {});
    });

    _noteUpdateSubscription = noteProvider.noteUpdates.listen((_) {
      if (mounted) setState(() {});
    });

    _questionUpdateSubscription = questionProvider.questionUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _pauseVideo() {
    if (_useMediaKit) {
      if (_mediaKitPlayer?.state.playing == true) {
        _mediaKitPlayer?.pause();
      }
    } else {
      if (_chewieController?.isPlaying == true) {
        _chewieController?.pause();
      }
    }
    WakelockPlus.disable();
  }

  void _resumeVideoIfNeeded() {
    if (_useMediaKit) {
      if (_mediaKitPlayer != null && !_mediaKitPlayer!.state.playing) {
        _mediaKitPlayer?.play();
      }
    } else {
      if (_chewieController != null && !_chewieController!.isPlaying) {
        _chewieController?.play();
      }
    }
    WakelockPlus.enable();
  }

  void _disposeVideoPlayer() {
    try {
      if (_useMediaKit) {
        _disposeMediaKitPlayer();
      } else {
        _chewieController?.pause();
        _chewieController?.dispose();
        _videoController?.dispose();
      }
    } catch (e) {
      debugLog('ChapterContent', 'Error disposing video player: $e');
    } finally {
      _chewieController = null;
      _videoController = null;
      _mediaKitVideoController = null;
      _mediaKitPlayer = null;
      _currentPlayingVideoId = null;
      _isPlayingVideo = false;
      WakelockPlus.disable();
    }
  }

  Future<void> _playVideo(Video video) async {
    if (_isPlayingVideo) {
      _disposeVideoPlayer();
    }

    try {
      setState(() {
        _currentPlayingVideoId = video.id;
        _isPlayingVideo = true;
      });

      final videoUrl = _cachedVideoPaths.containsKey(video.id)
          ? _cachedVideoPaths[video.id]!
          : video.fullVideoUrl;

      debugLog('ChapterContent',
          'Playing video from: ${_cachedVideoPaths.containsKey(video.id) ? 'app cache' : 'online'}');

      if (_useMediaKit) {
        await _playWithMediaKit(video, videoUrl);
      } else {
        await _playWithVideoPlayer(video, videoUrl);
      }
    } catch (e) {
      debugLog('ChapterContent', 'Video play error: $e');

      if (_useMediaKit) {
        debugLog('ChapterContent', 'Falling back to video_player');
        _useMediaKit = false;
        await _playWithVideoPlayer(video, video.fullVideoUrl);
      } else {
        if (mounted) {
          showSnackBar(
            context,
            'Failed to initialize video player',
            isError: true,
          );
        }
        _disposeVideoPlayer();
      }
    }
  }

  Future<void> _playWithVideoPlayer(Video video, String videoUrl) async {
    if (_cachedVideoPaths.containsKey(video.id)) {
      final file = File(_cachedVideoPaths[video.id]!);
      if (await file.exists()) {
        _videoController = VideoPlayerController.file(file);
      } else {
        _cachedVideoPaths.remove(video.id);
        await _saveCacheMetadata();
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(video.fullVideoUrl),
        );
      }
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(video.fullVideoUrl),
      );
    }

    await _videoController!.initialize();

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
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        bufferedColor: Theme.of(context).colorScheme.surfaceVariant,
      ),
      placeholder: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.telegramRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        );
      },
    );

    await WakelockPlus.enable();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: 16,
          tablet: 32,
          desktop: 64,
        )),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Chewie(controller: _chewieController!),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      _onVideoClosed(video);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _playWithMediaKit(Video video, String videoUrl) async {
    debugLog('ChapterContent', 'Playing with MediaKit');

    _mediaKitPlayer ??= media_kit.Player();

    _mediaKitVideoController = media_kit_video.VideoController(
      _mediaKitPlayer!,
    );

    if (_cachedVideoPaths.containsKey(video.id)) {
      final file = File(_cachedVideoPaths[video.id]!);
      if (await file.exists()) {
        await _mediaKitPlayer!.open(
          media_kit.Media(file.path),
          play: true,
        );
      } else {
        _cachedVideoPaths.remove(video.id);
        await _saveCacheMetadata();
        await _mediaKitPlayer!.open(
          media_kit.Media(video.fullVideoUrl),
          play: true,
        );
      }
    } else {
      await _mediaKitPlayer!.open(
        media_kit.Media(video.fullVideoUrl),
        play: true,
      );
    }

    await WakelockPlus.enable();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: 16,
          tablet: 32,
          desktop: 64,
        )),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: media_kit_video.Video(
                  controller: _mediaKitVideoController!,
                  controls: media_kit_video.MaterialVideoControls,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      _onVideoClosed(video);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onVideoClosed(Video video) async {
    try {
      final videoProvider = context.read<VideoProvider>();
      final progressProvider = context.read<ProgressProvider>();

      int progress = 0;

      if (_useMediaKit && _mediaKitPlayer != null) {
        final position = _mediaKitPlayer!.state.position;
        final duration = _mediaKitPlayer!.state.duration;
        progress = duration.inSeconds > 0
            ? (position.inSeconds / duration.inSeconds * 100).toInt()
            : 0;
      } else if (_videoController != null &&
          _videoController!.value.isInitialized) {
        final position = _videoController!.value.position;
        final duration = _videoController!.value.duration;
        progress = duration.inSeconds > 0
            ? (position.inSeconds / duration.inSeconds * 100).toInt()
            : 0;
      }

      await progressProvider.saveChapterProgress(
        chapterId: widget.chapterId,
        videoProgress: progress,
      );

      if (progress >= 30) {
        await videoProvider.incrementViewCount(video.id);
      }
    } catch (e) {
      debugLog('ChapterContent', 'Error tracking video progress: $e');
    } finally {
      _disposeVideoPlayer();

      if (mounted) {
        setState(() {
          _isPlayingVideo = false;
          _currentPlayingVideoId = null;
        });
      }
    }
  }

  Future<void> _cacheVideo(Video video) async {
    if (_isCaching[video.id] == true) return;

    setState(() {
      _isCaching[video.id] = true;
      _cacheProgress[video.id] = 0.0;
    });

    try {
      final cacheDir = await _getAppCacheDirectory();

      final fileName =
          'vid_${video.id}_${DateTime.now().millisecondsSinceEpoch}.tmp';
      final filePath = '${cacheDir.path}/$fileName';

      await _dio.download(
        video.fullVideoUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          headers: {
            'Cache-Control': 'no-cache',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            final progress = (received / total);
            setState(() {
              _cacheProgress[video.id] = progress;
            });
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Cached file not found');
      }

      _cachedVideoPaths[video.id] = filePath;
      await _saveCacheMetadata();

      if (mounted) {
        setState(() {
          _isCaching[video.id] = false;
          _cacheProgress.remove(video.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video cached for offline viewing'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCaching[video.id] = false;
          _cacheProgress.remove(video.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cache video: ${e.toString()}'),
            backgroundColor: AppColors.telegramRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugLog('ChapterContent', 'Cache error: $e');
    }
  }

  Future<void> _saveCacheMetadata() async {
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

      await deviceService.saveCacheItem(
          'cached_videos_chapter_${widget.chapterId}', videoPaths,
          isUserSpecific: true, ttl: const Duration(days: 30));
      await deviceService.saveCacheItem(
          'cached_notes_chapter_${widget.chapterId}', notePaths,
          isUserSpecific: true, ttl: const Duration(days: 30));
    } catch (e) {
      debugLog('ChapterContent', 'Error saving cache metadata: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      for (final path in _cachedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugLog('ChapterContent', 'Error deleting cache file: $e');
        }
      }

      _cachedVideoPaths.clear();
      await _saveCacheMetadata();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugLog('ChapterContent', 'Error clearing cache: $e');
    }
  }

  Future<void> _cacheNote(Note note) async {
    if (_isCaching[note.id] == true) return;

    setState(() {
      _isCaching[note.id] = true;
      _cacheProgress[note.id] = 0.0;
    });

    try {
      if (note.filePath == null || note.filePath!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Note has no downloadable file'),
              backgroundColor: AppColors.telegramRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() {
          _isCaching[note.id] = false;
          _cacheProgress.remove(note.id);
        });
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final cacheDir =
          Directory('${appDocDir.path}/.familyacademy_cache/notes');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

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
            final progress = (received / total);
            setState(() {
              _cacheProgress[note.id] = progress;
            });
          }
        },
      );

      _cachedNotePaths[note.id] = filePath;
      await _saveCacheMetadata();

      if (mounted) {
        setState(() {
          _isCaching[note.id] = false;
          _cacheProgress.remove(note.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note cached for offline viewing'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCaching[note.id] = false;
          _cacheProgress.remove(note.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cache note: ${e.toString()}'),
            backgroundColor: AppColors.telegramRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugLog('ChapterContent', 'Cache error: $e');
    }
  }

  Future<void> _checkAnswer(int questionId, String selectedOption) async {
    final questionProvider = context.read<QuestionProvider>();

    try {
      final result = await questionProvider.checkAnswer(
        questionId,
        selectedOption,
      );

      final isCorrect = result['is_correct'] == true;

      setState(() {
        _showExplanation[questionId] = true;
        _isQuestionCorrect[questionId] = isCorrect;
      });
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          'Failed to check answer. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _selectAnswer(int questionId, String option) {
    setState(() {
      _selectedAnswers[questionId] = option;
      _showExplanation[questionId] = false;
    });
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline && !_hasCachedData) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        ),
        vertical: AppThemes.spacingS,
      ),
      padding: EdgeInsets.all(AppThemes.spacingM),
      decoration: BoxDecoration(
        color: _isOffline
            ? AppColors.telegramYellow.withOpacity(0.1)
            : AppColors.telegramBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: _isOffline
              ? AppColors.telegramYellow.withOpacity(0.3)
              : AppColors.telegramBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOffline
                ? Icons.signal_wifi_off_rounded
                : Icons.cloud_done_rounded,
            color:
                _isOffline ? AppColors.telegramYellow : AppColors.telegramBlue,
            size: 20,
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              _isOffline
                  ? 'Offline mode - showing cached content'
                  : 'Using cached data - refreshing in background',
              style: AppTextStyles.bodySmall.copyWith(
                color: _isOffline
                    ? AppColors.telegramYellow
                    : AppColors.telegramBlue,
              ),
            ),
          ),
          if (_isOffline)
            TextButton(
              onPressed: _manualRefresh,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.telegramBlue,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    final isFree = _chapter?.isFree ?? false;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _chapter?.name ?? 'Chapter',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: 24,
            tablet: 32,
            desktop: 48,
          )),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingXL),
                decoration: BoxDecoration(
                  color: isFree
                      ? AppColors.telegramYellow.withOpacity(0.1)
                      : AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFree ? Icons.schedule_rounded : Icons.lock_rounded,
                  size: 64,
                  color:
                      isFree ? AppColors.telegramYellow : AppColors.telegramRed,
                ),
              ),
              SizedBox(height: AppThemes.spacingXXL),
              Text(
                isFree ? 'Coming Soon' : 'Chapter Locked',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 32,
                    tablet: 64,
                    desktop: 96,
                  ),
                ),
                child: Text(
                  isFree
                      ? 'This chapter will be available soon. Stay tuned for updates!'
                      : 'Access to "${_chapter?.name ?? "this chapter"}" requires a subscription to "${_category?.name ?? "the category"}".',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingXXXL),
              if (!isFree)
                ElevatedButton(
                  onPressed: _showPaymentDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      ScreenSize.responsiveValue(
                        context: context,
                        mobile: 200,
                        tablet: 240,
                        desktop: 280,
                      ),
                      AppThemes.buttonHeightLarge,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusLarge),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppThemes.spacingM,
                      horizontal: AppThemes.spacingXL,
                    ),
                    child: Text(
                      'Purchase Access',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: AppThemes.spacingXL),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.getTextPrimary(context),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusLarge),
                  ),
                  minimumSize: Size(
                    ScreenSize.responsiveValue(
                      context: context,
                      mobile: 200,
                      tablet: 240,
                      desktop: 280,
                    ),
                    AppThemes.buttonHeightMedium,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppThemes.spacingM,
                    horizontal: AppThemes.spacingXL,
                  ),
                  child: Text(
                    'Go Back',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog() {
    if (_category == null) {
      showSnackBar(context, 'Category not found', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppThemes.borderRadiusLarge),
            topRight: Radius.circular(AppThemes.borderRadiusLarge),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: AppColors.telegramBlue,
                      size: AppThemes.iconSizeL,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock Content',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: AppThemes.spacingXS),
                        Text(
                          'Purchase "${_category!.name}" to access this chapter',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppThemes.spacingXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/payment',
                      extra: {
                        'category': _category,
                        'paymentType': 'first_time',
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                  ),
                  child: Text('Purchase Access',
                      style: AppTextStyles.buttonMedium),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.getTextSecondary(context),
                  ),
                  child: Text('Not Now', style: AppTextStyles.buttonMedium),
                ),
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
      return _buildSkeletonList(itemCount: 3);
    }

    if (videos.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.videocam_off_rounded,
          title: 'No Videos Available',
          message: 'There are no videos for this chapter yet.',
          type: EmptyStateType.noData,
          actionText: 'Refresh',
          onAction: () => videoProvider.loadVideosByChapter(widget.chapterId,
              forceRefresh: true),
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
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        )),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            child: _buildVideoCard(video, index),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(Video video, int index) {
    final isCached = _cachedVideoPaths.containsKey(video.id);
    final isCaching = _isCaching[video.id] == true;
    final progress = _cacheProgress[video.id] ?? 0.0;
    final statusColor =
        isCached ? AppColors.telegramGreen : AppColors.telegramBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playVideo(video),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          )),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 80,
                  tablet: 100,
                  desktop: 120,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 60,
                  tablet: 70,
                  desktop: 80,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  image: video.thumbnailUrl != null &&
                          video.thumbnailUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(video.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: video.thumbnailUrl == null || video.thumbnailUrl!.isEmpty
                    ? Icon(
                        Icons.play_circle_rounded,
                        color: AppColors.telegramBlue,
                        size: 32,
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium),
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.telegramBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              SizedBox(width: AppThemes.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontSize: ScreenSize.responsiveFontSize(
                          context: context,
                          mobile: 15,
                          tablet: 16,
                          desktop: 17,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppThemes.spacingS),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatDuration(video.duration ?? 0),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppThemes.spacingM),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '${video.viewCount}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isCaching)
                      Padding(
                        padding: EdgeInsets.only(top: AppThemes.spacingS),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isCached
                      ? Icons.check_circle_rounded
                      : isCaching
                          ? Icons.hourglass_empty_rounded
                          : Icons.cloud_download_rounded,
                  color: isCached
                      ? AppColors.telegramGreen
                      : isCaching
                          ? AppColors.getTextSecondary(context)
                          : AppColors.telegramBlue,
                ),
                onPressed: isCaching
                    ? null
                    : () => isCached ? null : _cacheVideo(video),
                tooltip: isCached ? 'Cached for offline' : 'Cache for offline',
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  Widget _buildNotesTab() {
    final noteProvider = context.watch<NoteProvider>();
    final notes = noteProvider.getNotesByChapter(widget.chapterId);

    if (noteProvider.isLoadingForChapter(widget.chapterId) && notes.isEmpty) {
      return _buildSkeletonList(itemCount: 3, type: 'note');
    }

    if (notes.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.note_alt_outlined,
          title: 'No Notes Available',
          message: 'There are no notes for this chapter yet.',
          type: EmptyStateType.noData,
          actionText: 'Refresh',
          onAction: () => noteProvider.loadNotesByChapter(widget.chapterId,
              forceRefresh: true),
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
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        )),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            child: _buildNoteCard(note, index),
          );
        },
      ),
    );
  }

  Widget _buildNoteCard(Note note, int index) {
    final isCached = _cachedNotePaths.containsKey(note.id);
    final isCaching = _isCaching[note.id] == true;
    final progress = _cacheProgress[note.id] ?? 0.0;
    final isPdf = note.filePath?.toLowerCase().endsWith('.pdf') ?? false;
    final statusColor =
        isCached ? AppColors.telegramGreen : AppColors.telegramBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final progressProvider = context.read<ProgressProvider>();
          progressProvider.saveChapterProgress(
            chapterId: note.chapterId,
            notesViewed: true,
          );

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
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          )),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.note_alt_rounded,
                  color: AppColors.telegramBlue,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                ),
              ),
              SizedBox(width: AppThemes.spacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontSize: ScreenSize.responsiveFontSize(
                          context: context,
                          mobile: 15,
                          tablet: 16,
                          desktop: 17,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppThemes.spacingS),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                note.formattedDate,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppThemes.spacingM),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.description_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context),
                              ),
                              SizedBox(width: 4),
                              Text(
                                isPdf ? 'PDF' : 'Document',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isCaching)
                      Padding(
                        padding: EdgeInsets.only(top: AppThemes.spacingS),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              ),
              if (note.filePath != null && note.filePath!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isCached
                        ? Icons.check_circle_rounded
                        : isCaching
                            ? Icons.hourglass_empty_rounded
                            : Icons.cloud_download_rounded,
                    color: isCached
                        ? AppColors.telegramGreen
                        : isCaching
                            ? AppColors.getTextSecondary(context)
                            : AppColors.telegramBlue,
                  ),
                  onPressed: isCaching
                      ? null
                      : () => isCached ? null : _cacheNote(note),
                  tooltip:
                      isCached ? 'Cached for offline' : 'Cache for offline',
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  Widget _buildPracticeTab() {
    final questionProvider = context.watch<QuestionProvider>();
    final questions = questionProvider.getQuestionsByChapter(widget.chapterId);

    if (questionProvider.isLoadingForChapter(widget.chapterId) &&
        questions.isEmpty) {
      return _buildSkeletonList(itemCount: 3, type: 'question');
    }

    if (questions.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'No Practice Questions',
          message: 'Practice questions will be added soon.',
          type: EmptyStateType.noData,
          actionText: 'Refresh',
          onAction: () => questionProvider
              .loadPracticeQuestions(widget.chapterId, forceRefresh: true),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => questionProvider.loadPracticeQuestions(widget.chapterId,
          forceRefresh: true),
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getBackground(context),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        )),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            child: _buildPracticeQuestionCard(question, index),
          );
        },
      ),
    );
  }

  Widget _buildPracticeQuestionCard(Question question, int index) {
    final questionId = question.id;
    _showExplanation[questionId] ??= false;
    _isQuestionCorrect[questionId] ??= false;
    final difficultyColor = _getDifficultyColor(question.difficulty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          )),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingM,
                      vertical: AppThemes.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                      border: Border.all(
                        color: difficultyColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      question.difficulty.toUpperCase(),
                      style: AppTextStyles.statusBadge.copyWith(
                        color: difficultyColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingM,
                      vertical: AppThemes.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                    ),
                    child: Text(
                      'Q${index + 1}',
                      style: AppTextStyles.statusBadge.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                question.questionText,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              ..._buildPracticeQuestionOptions(question, questionId),
              SizedBox(height: AppThemes.spacingL),
              _buildCheckAnswerButton(question, questionId),
              if (_showExplanation[questionId]!)
                _buildExplanationSection(question, questionId),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  List<Widget> _buildPracticeQuestionOptions(
      Question question, int questionId) {
    final options = _getQuestionOptions(question);

    return options.asMap().entries.map((entry) {
      final optionIndex = entry.key;
      final option = entry.value;
      final optionLetter = String.fromCharCode(65 + optionIndex);

      final isSelected = _selectedAnswers[questionId] == optionLetter;
      final showExplanation = _showExplanation[questionId] == true;
      final isCorrectAnswer = question.correctOption == optionLetter;

      return Padding(
        padding: EdgeInsets.only(bottom: AppThemes.spacingM),
        child: InkWell(
          onTap: () => _selectAnswer(questionId, optionLetter),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          child: Container(
            padding: EdgeInsets.all(AppThemes.spacingM),
            decoration: BoxDecoration(
              color: _getOptionColor(
                context,
                isSelected,
                showExplanation,
                isCorrectAnswer,
                optionLetter == _selectedAnswers[questionId],
              ),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: _getOptionBorderColor(
                  context,
                  isSelected,
                  showExplanation,
                  isCorrectAnswer,
                  optionLetter == _selectedAnswers[questionId],
                ),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.telegramBlue
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      optionLetter,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppThemes.spacingM),
                Expanded(
                  child: Text(
                    option,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _getOptionTextColor(
                        context,
                        isSelected,
                        showExplanation,
                        isCorrectAnswer,
                        optionLetter == _selectedAnswers[questionId],
                      ),
                    ),
                  ),
                ),
                if (showExplanation && isCorrectAnswer)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.telegramGreen,
                    size: 20,
                  ),
                if (showExplanation &&
                    !isCorrectAnswer &&
                    optionLetter == _selectedAnswers[questionId])
                  Icon(
                    Icons.cancel_rounded,
                    color: AppColors.telegramRed,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCheckAnswerButton(Question question, int questionId) {
    final isSelected = _selectedAnswers[questionId] != null;
    final showExplanation = _showExplanation[questionId] == true;
    final isCorrect = _isQuestionCorrect[questionId] == true;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSelected && !showExplanation
            ? () => _checkAnswer(questionId, _selectedAnswers[questionId]!)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: showExplanation
              ? (isCorrect ? AppColors.telegramGreen : AppColors.telegramRed)
              : AppColors.telegramBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
        ),
        child: Text(
          showExplanation
              ? (isCorrect ? 'Correct Answer!' : 'Incorrect')
              : 'Check Answer',
          style: AppTextStyles.buttonMedium,
        ),
      ),
    );
  }

  Widget _buildExplanationSection(Question question, int questionId) {
    return Padding(
      padding: EdgeInsets.only(top: AppThemes.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Theme.of(context).dividerColor),
          SizedBox(height: AppThemes.spacingL),
          Text(
            'Explanation:',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppThemes.spacingM),
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
            ),
            child: Text(
              question.explanation ?? 'No explanation provided.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: AppThemes.spacingL),
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.telegramGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: AppColors.telegramGreen,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.telegramGreen,
                ),
                SizedBox(width: AppThemes.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Correct Answer',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.telegramGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Option ${question.correctOption.toUpperCase()}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList({required int itemCount, String type = 'video'}) {
    return ListView.builder(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: AppThemes.spacingL),
          child: Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    width: type == 'video' ? 80 : 48,
                    height: type == 'video' ? 60 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                  ),
                ),
                SizedBox(width: AppThemes.spacingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: 20,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: AppThemes.spacingS),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 150,
                          height: 16,
                          color: Colors.white,
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

  List<String> _getQuestionOptions(Question question) {
    final options = <String>[];
    if (question.optionA?.isNotEmpty ?? false) options.add(question.optionA!);
    if (question.optionB?.isNotEmpty ?? false) options.add(question.optionB!);
    if (question.optionC?.isNotEmpty ?? false) options.add(question.optionC!);
    if (question.optionD?.isNotEmpty ?? false) options.add(question.optionD!);
    if (question.optionE?.isNotEmpty ?? false) options.add(question.optionE!);
    if (question.optionF?.isNotEmpty ?? false) options.add(question.optionF!);
    return options;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.telegramGreen;
      case 'medium':
        return AppColors.telegramYellow;
      case 'hard':
        return AppColors.telegramRed;
      default:
        return AppColors.telegramBlue;
    }
  }

  Color _getOptionColor(BuildContext context, bool isSelected,
      bool showExplanation, bool isCorrectAnswer, bool isUserSelection) {
    if (showExplanation) {
      if (isCorrectAnswer) return AppColors.telegramGreen.withOpacity(0.1);
      if (isUserSelection) return AppColors.telegramRed.withOpacity(0.1);
      return Colors.transparent;
    }
    return isSelected
        ? AppColors.telegramBlue.withOpacity(0.1)
        : Colors.transparent;
  }

  Color _getOptionBorderColor(BuildContext context, bool isSelected,
      bool showExplanation, bool isCorrectAnswer, bool isUserSelection) {
    if (showExplanation) {
      if (isCorrectAnswer) return AppColors.telegramGreen;
      if (isUserSelection) return AppColors.telegramRed;
      return Theme.of(context).dividerColor;
    }
    return isSelected ? AppColors.telegramBlue : Theme.of(context).dividerColor;
  }

  Color _getOptionTextColor(BuildContext context, bool isSelected,
      bool showExplanation, bool isCorrectAnswer, bool isUserSelection) {
    if (showExplanation) {
      if (isCorrectAnswer) return AppColors.telegramGreen;
      if (isUserSelection) return AppColors.telegramRed;
      return AppColors.getTextSecondary(context);
    }
    return isSelected
        ? AppColors.getTextPrimary(context)
        : AppColors.getTextSecondary(context);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 200,
              height: 24,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
        ),
        body: _buildSkeletonList(itemCount: 5),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Error',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: ErrorState(
          title: 'Something went wrong',
          message: _errorMessage!,
          actionText: 'Try Again',
          onAction: _initialize,
        ),
      );
    }

    if (_chapter == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Not Found',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Chapter not found',
            message: _isOffline
                ? 'No cached data available. Please check your connection.'
                : 'The chapter you\'re looking for doesn\'t exist.',
            type: EmptyStateType.error,
            actionText: 'Retry',
            onAction: _manualRefresh,
          ),
        ),
      );
    }

    if (!_hasAccess && !_isCheckingAccess) {
      return _buildAccessDeniedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _chapter!.name,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
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
              labelStyle: AppTextStyles.labelMedium,
              unselectedLabelStyle: AppTextStyles.labelMedium,
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
          _buildOfflineBanner(),
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
}

class NoteDetailScreen extends StatelessWidget {
  final Note note;
  final String? cachedPath;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.cachedPath,
  });

  Future<void> _openFile(BuildContext context, String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        showSnackBar(context, 'Cannot open file', isError: true);
      }
    } catch (e) {
      showSnackBar(context, 'Error opening file: $e', isError: true);
    }
  }

  Widget _buildPdfViewer(String filePath) {
    return SfPdfViewer.file(
      File(filePath),
      canShowPaginationDialog: true,
      canShowScrollHead: true,
    );
  }

  Widget _buildTextContent(BuildContext context, String content) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      child: HtmlWidget(
        content,
        textStyle: AppTextStyles.bodyLarge.copyWith(
          height: 1.6,
          color: AppColors.getTextPrimary(context),
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
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasFile && cachedPath != null)
            IconButton(
              icon: Icon(
                Icons.open_in_new_rounded,
                color: AppColors.telegramBlue,
              ),
              onPressed: () => _openFile(context, cachedPath!),
              tooltip: 'Open File',
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasFile)
            Container(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              )),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.note_alt_rounded,
                      color: AppColors.telegramBlue,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPdf ? 'PDF Document' : 'Text Document',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        if (cachedPath != null)
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.telegramGreen,
                              ),
                              SizedBox(width: AppThemes.spacingXS),
                              Text(
                                'Available Offline',
                                style: AppTextStyles.caption.copyWith(
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
