import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
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
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/common/error_widget.dart' as custom;
import '../../widgets/common/responsive_widgets.dart';

enum VideoQuality {
  low(360, '360p'),
  medium(480, '480p'),
  high(720, '720p'),
  highest(1080, '1080p');

  final int height;
  final String label;
  const VideoQuality(this.height, this.label);
}

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
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupStreamListeners();
    _getCurrentUserId();
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradient,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled ? LinearGradient(colors: gradient) : null,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingS(context),
                  offset: Offset(0, ResponsiveValues.spacingXS(context)),
                ),
              ]
            : null,
      ),
      child: Material(
        color: isEnabled
            ? Colors.transparent
            : AppColors.getSurface(context).withValues(alpha: 0.1),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: ResponsiveValues.iconSizeM(context),
                    height: ResponsiveValues.iconSizeM(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : ResponsiveText(
                    label,
                    style: AppTextStyles.buttonMedium(context).copyWith(
                      color: isEnabled
                          ? Colors.white
                          : AppColors.getTextSecondary(context)
                              .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id.toString();
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

    try {
      if (_mediaKitPlayer != null) {
        _mediaKitPlayer?.pause();
        _mediaKitPlayer?.dispose();
        _mediaKitPlayer = null;
      }
    } catch (e) {
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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection && mounted) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
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
            _downloadQuality[videoId] = VideoQuality.values.firstWhere(
              (q) => q.label == value,
              orElse: () => VideoQuality.medium,
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
    } catch (e) {
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await _checkAccessAndLoadData(forceRefresh: true);
      if (mounted) showTopSnackBar(context, 'Content updated');
    } catch (e) {
      setState(() => _isOffline = true);
      if (mounted)
        showTopSnackBar(context, 'Refresh failed, using cached data',
            isError: true);
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

    if (categoryProvider.categories.isEmpty)
      await categoryProvider.loadCategories(
          forceRefresh: forceRefresh && !_isOffline);

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
      if (mounted && _hasAccess && !_isRefreshing && !_isOffline)
        await _refreshInBackground();
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
        if (_mediaKitPlayer != null && !_mediaKitPlayer!.state.playing)
          _mediaKitPlayer?.play();
      } else {
        if (_chewieController != null && !_chewieController!.isPlaying)
          _chewieController?.play();
      }
    } catch (e) {}
    try {
      WakelockPlus.enable();
    } catch (e) {}
  }

  Future<VideoQuality?> _showQualitySelector(Video video,
      {bool forPlayback = false}) async {
    if (_cachedVideoPaths.containsKey(video.id)) return null;
    if (!video.hasQualities) return VideoQuality.medium;

    final availableQualities = VideoQuality.values
        .where((q) => video.getQualityUrl(q.name) != null)
        .toList()
      ..sort((a, b) => b.height.compareTo(a.height));

    if (availableQualities.isEmpty) return VideoQuality.medium;

    final currentQuality = _downloadQuality[video.id] ??
        (forPlayback ? VideoQuality.medium : VideoQuality.medium);

    final Completer<VideoQuality?> completer = Completer();

    bool didSelectQuality = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          if (!didSelectQuality) {
            completer.complete(null);
          }
          return true;
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ResponsiveValues.radiusXLarge(context)),
            ),
          ),
          child: ResponsiveColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin:
                    EdgeInsets.only(top: ResponsiveValues.spacingM(context)),
                width: ResponsiveValues.spacingXXL(context),
                height: ResponsiveValues.spacingXS(context),
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context),
                  ),
                ),
              ),
              Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: ResponsiveRow(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ResponsiveText(
                      forPlayback ? 'Select Quality' : 'Download Quality',
                      style: AppTextStyles.titleMedium(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                        completer.complete(null);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                      'Let us choose the best quality for your connection',
                  isSelected: false,
                  onTap: () {
                    didSelectQuality = true;
                    Navigator.pop(context);
                    completer.complete(null);
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
                  isSelected: currentQuality == quality,
                  onTap: () {
                    didSelectQuality = true;
                    Navigator.pop(context);
                    completer.complete(quality);
                  },
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              Padding(
                padding: ResponsiveValues.screenPadding(context),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    completer.complete(null);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      ResponsiveValues.buttonHeightMedium(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                  ),
                  child: ResponsiveText(
                    'Cancel',
                    style: AppTextStyles.labelLarge(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.s),
            ],
          ),
        ),
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
          child: ResponsiveRow(
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
                  child: ResponsiveText(
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
              ResponsiveSizedBox(width: AppSpacing.m),
              Expanded(
                child: ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveText(
                      label,
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? AppColors.telegramBlue
                            : AppColors.getTextPrimary(context),
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xxs),
                    ResponsiveText(
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

    if (_cachedVideoPaths.containsKey(video.id)) {
      _playWithUrl(video, _cachedVideoPaths[video.id]!);
      return;
    }

    VideoQuality? selectedQuality;

    if (video.hasQualities) {
      selectedQuality = await _showQualitySelector(video, forPlayback: true);
    }

    if (selectedQuality == null) {
      debugLog('VideoCard', 'Playback cancelled by user');
      return;
    }

    String videoUrl;
    if (selectedQuality != null && video.hasQualities) {
      videoUrl =
          video.getQualityUrl(selectedQuality.name) ?? video.fullVideoUrl;
    } else {
      videoUrl = video.fullVideoUrl;
    }

    _playWithUrl(video, videoUrl);
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
        if (mounted)
          showTopSnackBar(context, 'Failed to play video: $e', isError: true);
      }
    }
  }

  Future<void> _playWithMediaKit(Video video, String videoUrl) async {
    _mediaKitPlayer = media_kit.Player();
    _mediaKitVideoController =
        media_kit_video.VideoController(_mediaKitPlayer!);

    await _mediaKitPlayer!.open(media_kit.Media(videoUrl), play: true);
    await _mediaKitPlayer!.setVolume(1.0);
    await _mediaKitPlayer!.setRate(1.0);

    setState(() => _isPlayerInitialized = true);
    try {
      await WakelockPlus.enable();
    } catch (e) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(
          ScreenSize.responsiveDouble(
            context: context,
            mobile: 16,
            tablet: 32,
            desktop: 64,
          ),
        ),
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: media_kit_video.Video(
                  controller: _mediaKitVideoController!,
                  controls: media_kit_video.MaterialVideoControls,
                  fill: Colors.black,
                ),
              ),
              Positioned(
                top: ResponsiveValues.spacingL(context),
                right: ResponsiveValues.spacingL(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () async {
                      if (_mediaKitPlayer != null)
                        try {
                          await _mediaKitPlayer!.pause();
                        } catch (e) {}
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

  Future<void> _playWithVideoPlayer(Video video, String videoUrl) async {
    try {
      String fixedUrl = videoUrl;

      if (fixedUrl.startsWith('http')) {
        try {
          final uri = Uri.parse(fixedUrl);
          _videoController = VideoPlayerController.networkUrl(uri);
        } catch (e) {
          debugLog('VideoCard', 'URL parsing error: $e');
          _videoController = VideoPlayerController.networkUrl(
              Uri.parse(Uri.encodeFull(fixedUrl)));
        }
      } else {
        _videoController = VideoPlayerController.file(File(fixedUrl));
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
            child: ResponsiveColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
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
          child: ResponsiveColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.telegramRed, size: 48),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                'Error loading video: $errorMessage',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      );

      setState(() => _isPlayerInitialized = true);
      try {
        await WakelockPlus.enable();
      } catch (e) {}

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.all(
            ScreenSize.responsiveDouble(
              context: context,
              mobile: 16,
              tablet: 32,
              desktop: 64,
            ),
          ),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Chewie(controller: _chewieController!),
                ),
                Positioned(
                  top: ResponsiveValues.spacingL(context),
                  right: ResponsiveValues.spacingL(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        if (_chewieController != null)
                          try {
                            _chewieController?.pause();
                          } catch (e) {}
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
    } catch (e) {
      debugLog('VideoCard', 'Error in _playWithVideoPlayer: $e');
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
    } catch (e) {
    } finally {
      _disposeAllPlayers();
    }
  }

  Future<void> _showDownloadQualityDialog(Video video) async {
    if (_cachedVideoPaths.containsKey(video.id)) {
      _showDeleteDownloadDialog(video);
      return;
    }

    final selectedQuality =
        await _showQualitySelector(video, forPlayback: false);

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
      showTopSnackBar(context, 'Please login to download', isError: true);
      return;
    }

    final quality = _downloadQuality[video.id] ?? VideoQuality.medium;

    setState(() {
      _isDownloading[video.id] = true;
      _downloadProgress[video.id] = 0.0;
    });

    try {
      final cacheDir = await _getAppCacheDirectory();
      final fileName =
          'vid_${video.id}_${quality.height}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${cacheDir.path}/$fileName';

      final downloadUrl = video.fullVideoUrl;

      debugLog('VideoCard', 'Downloading from: $downloadUrl');

      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          headers: {'Accept-Encoding': 'identity'},
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress[video.id] = received / total);
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) throw Exception('Download failed');

      setState(() {
        _cachedVideoPaths[video.id] = filePath;
        _isDownloading[video.id] = false;
        _downloadProgress.remove(video.id);
      });

      await _saveCacheMetadata();

      if (mounted) {
        showTopSnackBar(context, '${quality.label} video downloaded');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[video.id] = false;
          _downloadProgress.remove(video.id);
        });
        showTopSnackBar(context, 'Download failed: $e', isError: true);
      }
    }
  }

  Future<void> _downloadNote(Note note) async {
    if (_isDownloading[note.id] == true) return;
    if (_currentUserId == null) {
      showTopSnackBar(context, 'Please login to download', isError: true);
      return;
    }

    setState(() {
      _isDownloading[note.id] = true;
      _downloadProgress[note.id] = 0.0;
    });

    try {
      if (note.filePath == null || note.filePath!.isEmpty) {
        showTopSnackBar(context, 'Note has no downloadable file',
            isError: true);
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
      if (fullFilePath == null || fullFilePath.isEmpty)
        throw Exception('Invalid file path');

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
          if (total != -1 && mounted)
            setState(() => _downloadProgress[note.id] = received / total);
        },
      );

      setState(() {
        _cachedNotePaths[note.id] = filePath;
        _isDownloading[note.id] = false;
        _downloadProgress.remove(note.id);
      });

      await _saveCacheMetadata();

      if (mounted) {
        showTopSnackBar(context, 'Note downloaded for offline viewing');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[note.id] = false;
          _downloadProgress.remove(note.id);
        });
        showTopSnackBar(context, 'Download failed: $e', isError: true);
      }
    }
  }

  Future<void> _saveCacheMetadata() async {
    if (_currentUserId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceService = authProvider.deviceService;

      final videoPaths = <String, String>{};
      for (final entry in _cachedVideoPaths.entries)
        videoPaths[entry.key.toString()] = entry.value;

      final notePaths = <String, String>{};
      for (final entry in _cachedNotePaths.entries)
        notePaths[entry.key.toString()] = entry.value;

      final downloadQualities = <String, String>{};
      for (final entry in _downloadQuality.entries)
        downloadQualities[entry.key.toString()] = entry.value.label;

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

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

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showTopSnackBar(context, 'All downloads cleared');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showTopSnackBar(context, 'Error clearing downloads', isError: true);
      }
    }
  }

  Future<void> _checkAllAnswers(List<Question> questions) async {
    final questionProvider = context.read<QuestionProvider>();
    bool hasError = false;
    int correctCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

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

    if (mounted) Navigator.pop(context);

    await _saveQuestionProgress();

    if (mounted) {
      showTopSnackBar(
        context,
        hasError
            ? 'Checked ${questions.length} questions, $correctCount correct'
            : 'All questions checked! $correctCount/${questions.length} correct',
        isError: hasError,
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
      if (mounted)
        showTopSnackBar(context, 'Failed to check answer', isError: true);
    }
  }

  void _selectAnswer(int questionId, String option) {
    setState(() {
      _selectedAnswers[questionId] = option;
      _showExplanation[questionId] = false;
    });
    _saveQuestionProgress();
  }

  Widget _buildAccessDeniedScreen() {
    final isFree = _chapter?.isFree ?? false;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          _chapter?.name ?? 'Chapter',
          style: AppTextStyles.titleMedium(context),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: ResponsiveIcon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveValues.sectionPadding(context),
          ),
          child: ResponsiveColumn(
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
                child: ResponsiveIcon(
                  isFree ? Icons.schedule_rounded : Icons.lock_rounded,
                  size: ResponsiveValues.iconSizeXXL(context),
                  color:
                      isFree ? AppColors.telegramYellow : AppColors.telegramRed,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.xxl),
              ResponsiveText(
                isFree ? 'Coming Soon' : 'Chapter Locked',
                style: AppTextStyles.headlineMedium(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.sectionPadding(context) * 2,
                ),
                child: ResponsiveText(
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
                ResponsiveSizedBox(height: AppSpacing.xxxl),
                ElevatedButton(
                  onPressed: () => context.push('/payment', extra: {
                    'category': _category,
                    'paymentType': 'first_time'
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      ScreenSize.responsiveDouble(
                        context: context,
                        mobile: 200,
                        tablet: 240,
                        desktop: 280,
                      ),
                      ResponsiveValues.buttonHeightLarge(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveValues.spacingM(context),
                      horizontal: ResponsiveValues.spacingXL(context),
                    ),
                    child: ResponsiveText(
                      'Purchase Access',
                      style: AppTextStyles.titleMedium(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              ResponsiveSizedBox(height: AppSpacing.xl),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.getTextPrimary(context),
                  side: BorderSide(
                    color: AppColors.getDivider(context),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context),
                    ),
                  ),
                  minimumSize: Size(
                    ScreenSize.responsiveDouble(
                      context: context,
                      mobile: 200,
                      tablet: 240,
                      desktop: 280,
                    ),
                    ResponsiveValues.buttonHeightMedium(context),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveValues.spacingM(context),
                    horizontal: ResponsiveValues.spacingXL(context),
                  ),
                  child: ResponsiveText(
                    'Go Back',
                    style: AppTextStyles.titleMedium(context).copyWith(
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

  Widget _buildVideosTab() {
    final videoProvider = context.watch<VideoProvider>();
    final videos = videoProvider.getVideosByChapter(widget.chapterId);

    if (videoProvider.isLoadingForChapter(widget.chapterId) && videos.isEmpty) {
      return _buildSkeletonList(itemCount: 3);
    }

    if (videos.isEmpty) {
      return _buildEmptyVideos();
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
              child: _buildVideoCard(video, index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyVideos() {
    return Center(
      child: ResponsiveColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: ResponsiveValues.dialogPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusXXLarge(context)),
                  border: Border.all(
                    color: AppColors.telegramBlue.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: ResponsiveColumn(
                  children: [
                    ResponsiveIcon(
                      Icons.videocam_off_rounded,
                      size: ResponsiveValues.iconSizeXXL(context),
                      color: AppColors.telegramBlue.withValues(alpha: 0.5),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    ResponsiveText(
                      'No Videos Available',
                      style: AppTextStyles.headlineSmall(context).copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.m),
                    ResponsiveText(
                      _isOffline
                          ? 'No cached videos available. Connect to load videos.'
                          : 'There are no videos for this chapter yet.',
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    if (!_isOffline)
                      _buildGlassButton(
                        context,
                        label: 'Refresh',
                        icon: Icons.refresh_rounded,
                        onPressed: () => context
                            .read<VideoProvider>()
                            .loadVideosByChapter(widget.chapterId,
                                forceRefresh: true),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: AppColors.getCard(context).withValues(alpha: 0.2),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingM(context),
                horizontal: ResponsiveValues.spacingXL(context),
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.telegramBlue.withValues(alpha: 0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
              ),
              child: ResponsiveRow(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResponsiveIcon(
                    icon,
                    size: ResponsiveValues.iconSizeS(context),
                    color: AppColors.telegramBlue,
                  ),
                  ResponsiveSizedBox(width: AppSpacing.s),
                  ResponsiveText(
                    label,
                    style: AppTextStyles.labelMedium(context).copyWith(
                      color: AppColors.telegramBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(Video video, int index) {
    final isDownloaded = _cachedVideoPaths.containsKey(video.id);
    final isDownloading = _isDownloading[video.id] == true;
    final progress = _downloadProgress[video.id] ?? 0.0;
    final quality = _downloadQuality[video.id] ?? VideoQuality.medium;
    final hasMultipleQualities = video.hasQualities;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: isDownloaded
                    ? AppColors.telegramGreen.withValues(alpha: 0.3)
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: ResponsiveColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: video.hasThumbnail
                            ? CachedNetworkImage(
                                imageUrl: video.fullThumbnailUrl!,
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
                                    child: ResponsiveIcon(
                                      Icons.movie,
                                      size:
                                          ResponsiveValues.iconSizeXL(context),
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
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
                                    child: ResponsiveIcon(
                                      Icons.broken_image,
                                      size:
                                          ResponsiveValues.iconSizeXL(context),
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
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
                                  child: ResponsiveIcon(
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
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: ResponsiveValues.spacingM(context),
                      right: ResponsiveValues.spacingM(context),
                      child: _buildVideoBadge(
                        context,
                        icon: Icons.access_time,
                        label: video.formattedDuration,
                        color: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    if (hasMultipleQualities)
                      Positioned(
                        bottom: ResponsiveValues.spacingM(context),
                        left: ResponsiveValues.spacingM(context),
                        child: _buildVideoBadge(
                          context,
                          icon: Icons.hd,
                          label: 'HD',
                          color: Colors.white,
                          backgroundColor: AppColors.telegramBlue,
                          gradient: AppColors.blueGradient,
                        ),
                      ),
                    if (isDownloaded && !isDownloading)
                      Positioned(
                        bottom: ResponsiveValues.spacingM(context),
                        right: ResponsiveValues.spacingM(context),
                        child: _buildVideoBadge(
                          context,
                          icon: Icons.check_circle,
                          label: quality.label,
                          color: Colors.white,
                          backgroundColor: AppColors.telegramGreen,
                          gradient: AppColors.greenGradient,
                        ),
                      ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _playVideo(video),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          child: Center(
                            child: Container(
                              width:
                                  ResponsiveValues.iconSizeXXL(context) * 1.5,
                              height:
                                  ResponsiveValues.iconSizeXXL(context) * 1.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.blueGradient,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.5),
                                    blurRadius:
                                        ResponsiveValues.spacingXL(context),
                                    spreadRadius:
                                        ResponsiveValues.spacingXS(context),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: ResponsiveColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        video.title,
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ResponsiveSizedBox(height: AppSpacing.m),
                      ResponsiveRow(
                        children: [
                          _buildMetadataChip(
                            context,
                            icon: Icons.visibility_rounded,
                            label: '${video.viewCount} views',
                          ),
                          ResponsiveSizedBox(width: AppSpacing.s),
                          _buildMetadataChip(
                            context,
                            icon: Icons.calendar_today_rounded,
                            label: video.createdAt
                                .toLocal()
                                .toString()
                                .split(' ')[0],
                          ),
                        ],
                      ),
                      if (isDownloading) ...[
                        ResponsiveSizedBox(height: AppSpacing.l),
                        _buildDownloadProgress(context, progress),
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
                  child: ResponsiveRow(
                    children: [
                      Expanded(
                        child: _buildVideoActionButton(
                          context,
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.telegramBlue,
                          gradient: AppColors.blueGradient,
                          onPressed: () => _playVideo(video),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: ResponsiveValues.spacingXL(context),
                        color: AppColors.getDivider(context)
                            .withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: _buildVideoActionButton(
                          context,
                          label: isDownloaded
                              ? 'Downloaded'
                              : isDownloading
                                  ? 'Downloading'
                                  : 'Download',
                          icon: isDownloaded
                              ? Icons.check_circle_rounded
                              : isDownloading
                                  ? Icons.hourglass_empty_rounded
                                  : Icons.cloud_download_rounded,
                          color: isDownloaded
                              ? AppColors.telegramGreen
                              : isDownloading
                                  ? AppColors.telegramBlue
                                  : AppColors.telegramBlue,
                          gradient: isDownloaded
                              ? AppColors.greenGradient
                              : AppColors.blueGradient,
                          onPressed: () => _showDownloadQualityDialog(video),
                          isEnabled: !isDownloading,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildVideoBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    List<Color>? gradient,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingS(context),
        vertical: ResponsiveValues.spacingXS(context),
      ),
      decoration: BoxDecoration(
        gradient: gradient != null ? LinearGradient(colors: gradient) : null,
        color: gradient == null ? backgroundColor : null,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: ResponsiveValues.spacingS(context),
            offset: Offset(0, ResponsiveValues.spacingXXS(context)),
          ),
        ],
      ),
      child: ResponsiveRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: ResponsiveValues.iconSizeXXS(context),
            color: color,
          ),
          ResponsiveSizedBox(width: AppSpacing.xs),
          ResponsiveText(
            label,
            style: AppTextStyles.caption(context).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
            ),
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? LinearGradient(colors: gradient)
                  : LinearGradient(
                      colors: [
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                      ],
                    ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.3),
                        blurRadius: ResponsiveValues.spacingS(context),
                        offset: Offset(0, ResponsiveValues.spacingXXS(context)),
                      ),
                    ]
                  : null,
            ),
            child: ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResponsiveIcon(
                  icon,
                  size: ResponsiveValues.iconSizeS(context),
                  color: isEnabled
                      ? Colors.white
                      : AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.5),
                ),
                ResponsiveSizedBox(width: AppSpacing.xs),
                ResponsiveText(
                  label,
                  style: AppTextStyles.labelMedium(context).copyWith(
                    color: isEnabled
                        ? Colors.white
                        : AppColors.getTextSecondary(context)
                            .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChip(
    BuildContext context, {
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
          width: 1,
        ),
      ),
      child: ResponsiveRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: ResponsiveValues.iconSizeXXS(context),
            color: effectiveColor,
          ),
          ResponsiveSizedBox(width: AppSpacing.xs),
          ResponsiveText(
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

  void _showDeleteDownloadDialog(Video video) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withValues(alpha: 0.4),
                    AppColors.getCard(context).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                border: Border.all(
                  color: AppColors.telegramRed.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: ResponsiveValues.dialogPadding(context),
              child: ResponsiveColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                      color: AppColors.telegramRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ResponsiveIcon(
                      Icons.delete_outline_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramRed,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'Remove Download',
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.s),
                  ResponsiveText(
                    'Remove downloaded video "${video.title}"?',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ResponsiveRow(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                          ),
                          child: ResponsiveText(
                            'Cancel',
                            style: AppTextStyles.labelLarge(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _cachedVideoPaths.remove(video.id);
                              _downloadQuality.remove(video.id);
                            });
                            _saveCacheMetadata();
                            Navigator.pop(context);
                            showTopSnackBar(context, 'Download removed');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.telegramRed,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Remove'),
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
    );
  }

  Widget _buildNotesTab() {
    final noteProvider = context.watch<NoteProvider>();
    final notes = noteProvider.getNotesByChapter(widget.chapterId);

    if (noteProvider.isLoadingForChapter(widget.chapterId) && notes.isEmpty) {
      return _buildSkeletonList(itemCount: 3, type: 'note');
    }

    if (notes.isEmpty) {
      return _buildEmptyNotes();
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveValues.spacingL(context),
              ),
              child: _buildNoteCard(note, index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyNotes() {
    return Center(
      child: ResponsiveColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: ResponsiveValues.dialogPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusXXLarge(context)),
                  border: Border.all(
                    color: AppColors.telegramBlue.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: ResponsiveColumn(
                  children: [
                    ResponsiveIcon(
                      Icons.note_alt_outlined,
                      size: ResponsiveValues.iconSizeXXL(context),
                      color: AppColors.telegramBlue.withValues(alpha: 0.5),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    ResponsiveText(
                      'No Notes Available',
                      style: AppTextStyles.headlineSmall(context).copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.m),
                    ResponsiveText(
                      _isOffline
                          ? 'No cached notes available. Connect to load notes.'
                          : 'There are no notes for this chapter yet.',
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    if (!_isOffline)
                      _buildGlassButton(
                        context,
                        label: 'Refresh',
                        icon: Icons.refresh_rounded,
                        onPressed: () => context
                            .read<NoteProvider>()
                            .loadNotesByChapter(widget.chapterId,
                                forceRefresh: true),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note, int index) {
    final isDownloaded = _cachedNotePaths.containsKey(note.id);
    final isDownloading = _isDownloading[note.id] == true;
    final progress = _downloadProgress[note.id] ?? 0.0;
    final isPdf = note.filePath?.toLowerCase().endsWith('.pdf') ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: isDownloaded
                    ? AppColors.telegramGreen.withValues(alpha: 0.3)
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Material(
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
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: ResponsiveRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: ResponsiveValues.iconSizeXXL(context),
                        height: ResponsiveValues.iconSizeXXL(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPdf
                                ? [
                                    AppColors.telegramRed,
                                    AppColors.telegramOrange
                                  ]
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
                              offset: Offset(
                                  0, ResponsiveValues.spacingXS(context)),
                            ),
                          ],
                        ),
                        child: ResponsiveIcon(
                          isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.note_alt_rounded,
                          size: ResponsiveValues.iconSizeXL(context),
                          color: Colors.white,
                        ),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.xl),
                      Expanded(
                        child: ResponsiveColumn(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveText(
                              note.title,
                              style:
                                  AppTextStyles.titleMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ResponsiveSizedBox(height: AppSpacing.m),
                            ResponsiveRow(
                              children: [
                                _buildMetadataChip(
                                  context,
                                  icon: Icons.calendar_today_rounded,
                                  label: note.formattedDate,
                                ),
                                ResponsiveSizedBox(width: AppSpacing.s),
                                _buildMetadataChip(
                                  context,
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
                            if (isDownloading) ...[
                              ResponsiveSizedBox(height: AppSpacing.l),
                              _buildDownloadProgress(context, progress),
                            ],
                            if (isDownloaded && !isDownloading) ...[
                              ResponsiveSizedBox(height: AppSpacing.l),
                              _buildDownloadedBadge(context),
                            ],
                          ],
                        ),
                      ),
                      if (note.filePath != null && note.filePath!.isNotEmpty)
                        _buildNoteActionButton(
                          context,
                          note: note,
                          isDownloaded: isDownloaded,
                          isDownloading: isDownloading,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildDownloadProgress(BuildContext context, double progress) {
    return ResponsiveColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveRow(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ResponsiveText(
              'Downloading...',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.telegramBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveText(
              '${(progress * 100).toInt()}%',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        ResponsiveSizedBox(height: AppSpacing.xs),
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
                widthFactor: progress,
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

  Widget _buildDownloadedBadge(BuildContext context) {
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
          width: 1,
        ),
      ),
      child: ResponsiveRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.telegramGreen,
          ),
          ResponsiveSizedBox(width: AppSpacing.xs),
          ResponsiveText(
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

  Widget _buildNoteActionButton(
    BuildContext context, {
    required Note note,
    required bool isDownloaded,
    required bool isDownloading,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isDownloaded) {
            _showDeleteNoteDownloadDialog(note);
          } else if (!isDownloading) {
            _downloadNote(note);
          }
        },
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        child: Container(
          padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
          decoration: BoxDecoration(
            color: isDownloaded
                ? AppColors.telegramGreen.withValues(alpha: 0.1)
                : isDownloading
                    ? AppColors.telegramBlue.withValues(alpha: 0.1)
                    : AppColors.getSurface(context).withValues(alpha: 0.1),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            border: Border.all(
              color: isDownloaded
                  ? AppColors.telegramGreen.withValues(alpha: 0.3)
                  : isDownloading
                      ? AppColors.telegramBlue.withValues(alpha: 0.3)
                      : AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ResponsiveIcon(
            isDownloaded
                ? Icons.check_circle_rounded
                : isDownloading
                    ? Icons.hourglass_empty_rounded
                    : Icons.cloud_download_rounded,
            size: ResponsiveValues.iconSizeL(context),
            color: isDownloaded
                ? AppColors.telegramGreen
                : isDownloading
                    ? AppColors.telegramBlue
                    : AppColors.getTextSecondary(context),
          ),
        ),
      ),
    );
  }

  void _showDeleteNoteDownloadDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getCard(context).withValues(alpha: 0.4),
                    AppColors.getCard(context).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                border: Border.all(
                  color: AppColors.telegramRed.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              padding: ResponsiveValues.dialogPadding(context),
              child: ResponsiveColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                      color: AppColors.telegramRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ResponsiveIcon(
                      Icons.delete_outline_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramRed,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'Remove Download',
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.s),
                  ResponsiveText(
                    'Remove downloaded note "${note.title}"?',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ResponsiveRow(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                          ),
                          child: ResponsiveText(
                            'Cancel',
                            style: AppTextStyles.labelLarge(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _cachedNotePaths.remove(note.id);
                            });
                            _saveCacheMetadata();
                            Navigator.pop(context);
                            showTopSnackBar(context, 'Download removed');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.telegramRed,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Remove'),
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
          message: _isOffline
              ? 'No cached questions available. Connect to load questions.'
              : 'Practice questions will be added soon.',
          type: EmptyStateType.noData,
          actionText: 'Refresh',
          onAction: _isOffline
              ? null
              : () => questionProvider.loadPracticeQuestions(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusXLarge(context)),
                      border: Border.all(
                        color: AppColors.telegramBlue.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: ResponsiveValues.cardPadding(context),
                      child: ResponsiveColumn(
                        children: [
                          ResponsiveRow(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ResponsiveText(
                                'Practice Progress',
                                style:
                                    AppTextStyles.titleMedium(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveValues.spacingM(context),
                                  vertical:
                                      ResponsiveValues.spacingXXS(context),
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
                                      offset: Offset(0,
                                          ResponsiveValues.spacingXXS(context)),
                                    ),
                                  ],
                                ),
                                child: ResponsiveText(
                                  '$answeredCount/$totalCount',
                                  style: AppTextStyles.labelSmall(context)
                                      .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ResponsiveSizedBox(height: AppSpacing.l),
                          Stack(
                            children: [
                              Container(
                                height:
                                    ResponsiveValues.progressBarHeight(context),
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
                                  height: ResponsiveValues.progressBarHeight(
                                      context),
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
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: ResponsiveRow(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context,
                      label: 'Check All',
                      icon: Icons.checklist_rounded,
                      isEnabled: _selectedAnswers.values
                          .any((v) => v != null && v.isNotEmpty),
                      gradient: AppColors.blueGradient,
                      onPressed: () => _checkAllAnswers(questions),
                    ),
                  ),
                  ResponsiveSizedBox(width: AppSpacing.m),
                  Expanded(
                    child: _buildActionButton(
                      context,
                      label: answeredCount > 0 ? 'Reset All' : 'Reset',
                      icon: Icons.refresh_rounded,
                      isEnabled: answeredCount > 0,
                      gradient: AppColors.orangeGradient,
                      onPressed: _resetAllQuestions,
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
                child: _buildGlassButton(
                  context,
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
          SliverToBoxAdapter(child: ResponsiveSizedBox(height: AppSpacing.s)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final question = questions[index];
                return Padding(
                  padding: ResponsiveValues.screenPadding(context),
                  child: _buildPracticeQuestionCard(question, index),
                );
              },
              childCount: questions.length,
            ),
          ),
          SliverToBoxAdapter(child: ResponsiveSizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isEnabled,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
            ),
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? LinearGradient(colors: gradient)
                  : LinearGradient(
                      colors: [
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                      ],
                    ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
              border: Border.all(
                color: isEnabled
                    ? Colors.transparent
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.3),
                        blurRadius: ResponsiveValues.spacingM(context),
                        offset: Offset(0, ResponsiveValues.spacingXS(context)),
                      ),
                    ]
                  : null,
            ),
            child: ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResponsiveIcon(
                  icon,
                  size: ResponsiveValues.iconSizeS(context),
                  color: isEnabled
                      ? Colors.white
                      : AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.5),
                ),
                ResponsiveSizedBox(width: AppSpacing.s),
                ResponsiveText(
                  label,
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: isEnabled
                        ? Colors.white
                        : AppColors.getTextSecondary(context)
                            .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeQuestionCard(Question question, int index) {
    final questionId = question.id;
    _showExplanation[questionId] ??= false;
    _isQuestionCorrect[questionId] ??= false;
    _questionAnswered[questionId] ??= false;

    final difficultyColor = _getDifficultyColor(question.difficulty);
    final isAnswered = _questionAnswered[questionId] == true;
    final isCorrect = _isQuestionCorrect[questionId] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: isAnswered
                    ? (isCorrect
                        ? AppColors.telegramGreen.withValues(alpha: 0.3)
                        : AppColors.telegramRed.withValues(alpha: 0.3))
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDifficultyBadge(question.difficulty),
                      _buildQuestionNumberBadge(
                          index + 1, isAnswered, isCorrect),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.getTextPrimary(context),
                        AppColors.getTextPrimary(context)
                            .withValues(alpha: 0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: ResponsiveText(
                      question.questionText,
                      style: AppTextStyles.titleMedium(context).copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ..._buildPracticeQuestionOptions(question, questionId),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  _buildCheckAnswerButton(question, questionId),
                  if (_showExplanation[questionId]!)
                    _buildExplanationSection(question, questionId),
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
          delay: (index * 100).ms,
          curve: Curves.easeOutQuad,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 400.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    final color = _getDifficultyColor(difficulty);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ResponsiveRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ResponsiveValues.spacingXS(context),
            height: ResponsiveValues.spacingXS(context),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: ResponsiveValues.spacingXS(context),
                ),
              ],
            ),
          ),
          ResponsiveSizedBox(width: AppSpacing.s),
          ResponsiveText(
            difficulty.toUpperCase(),
            style: AppTextStyles.labelSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNumberBadge(
      int number, bool isAnswered, bool isCorrect) {
    Color backgroundColor;
    Color borderColor;
    IconData? icon;

    if (isAnswered) {
      if (isCorrect) {
        backgroundColor = AppColors.telegramGreen.withValues(alpha: 0.15);
        borderColor = AppColors.telegramGreen.withValues(alpha: 0.3);
        icon = Icons.check_circle_rounded;
      } else {
        backgroundColor = AppColors.telegramRed.withValues(alpha: 0.15);
        borderColor = AppColors.telegramRed.withValues(alpha: 0.3);
        icon = Icons.cancel_rounded;
      }
    } else {
      backgroundColor = Colors.transparent;
      borderColor = AppColors.getTextSecondary(context).withValues(alpha: 0.2);
      icon = null;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ResponsiveRow(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: ResponsiveValues.iconSizeXXS(context),
              color:
                  isCorrect ? AppColors.telegramGreen : AppColors.telegramRed,
            ),
            ResponsiveSizedBox(width: AppSpacing.xs),
          ],
          ResponsiveText(
            'Q$number',
            style: AppTextStyles.labelSmall(context).copyWith(
              color: isAnswered
                  ? (isCorrect
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed)
                  : AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
      final isUserSelection = optionLetter == _selectedAnswers[questionId];

      Color optionColor;
      Color borderColor;
      IconData? icon;

      if (showExplanation) {
        if (isCorrectAnswer) {
          optionColor = AppColors.telegramGreen.withValues(alpha: 0.1);
          borderColor = AppColors.telegramGreen.withValues(alpha: 0.5);
          icon = Icons.check_circle_rounded;
        } else if (isUserSelection) {
          optionColor = AppColors.telegramRed.withValues(alpha: 0.1);
          borderColor = AppColors.telegramRed.withValues(alpha: 0.5);
          icon = Icons.cancel_rounded;
        } else {
          optionColor = Colors.transparent;
          borderColor =
              AppColors.getTextSecondary(context).withValues(alpha: 0.1);
          icon = null;
        }
      } else {
        if (isSelected) {
          optionColor = AppColors.telegramBlue.withValues(alpha: 0.1);
          borderColor = AppColors.telegramBlue;
          icon = null;
        } else {
          optionColor = Colors.transparent;
          borderColor =
              AppColors.getTextSecondary(context).withValues(alpha: 0.1);
          icon = null;
        }
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showExplanation
                ? null
                : () => _selectAnswer(questionId, optionLetter),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            child: Container(
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                color: optionColor,
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ResponsiveRow(
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected && !showExplanation
                          ? const LinearGradient(
                              colors: AppColors.blueGradient,
                            )
                          : null,
                      color: isSelected && !showExplanation
                          ? null
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected && !showExplanation
                            ? Colors.transparent
                            : showExplanation && isCorrectAnswer
                                ? AppColors.telegramGreen
                                : showExplanation && isUserSelection
                                    ? AppColors.telegramRed
                                    : AppColors.getTextSecondary(context)
                                        .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon,
                              size: ResponsiveValues.iconSizeXS(context),
                              color: isCorrectAnswer
                                  ? AppColors.telegramGreen
                                  : AppColors.telegramRed,
                            )
                          : ResponsiveText(
                              optionLetter,
                              style:
                                  AppTextStyles.labelMedium(context).copyWith(
                                color: isSelected && !showExplanation
                                    ? Colors.white
                                    : showExplanation && isCorrectAnswer
                                        ? AppColors.telegramGreen
                                        : showExplanation && isUserSelection
                                            ? AppColors.telegramRed
                                            : AppColors.getTextSecondary(
                                                context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  ResponsiveSizedBox(width: AppSpacing.l),
                  Expanded(
                    child: ResponsiveText(
                      option,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: showExplanation && isCorrectAnswer
                            ? AppColors.telegramGreen
                            : showExplanation &&
                                    isUserSelection &&
                                    !isCorrectAnswer
                                ? AppColors.telegramRed
                                : AppColors.getTextPrimary(context),
                        fontWeight:
                            isSelected || (showExplanation && isCorrectAnswer)
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
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

    if (showExplanation) {
      return Container(
        padding: ResponsiveValues.cardPadding(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCorrect
                ? [
                    AppColors.telegramGreen.withValues(alpha: 0.1),
                    AppColors.telegramGreen.withValues(alpha: 0.05),
                  ]
                : [
                    AppColors.telegramRed.withValues(alpha: 0.1),
                    AppColors.telegramRed.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          border: Border.all(
            color: isCorrect
                ? AppColors.telegramGreen.withValues(alpha: 0.3)
                : AppColors.telegramRed.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ResponsiveRow(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.telegramGreen.withValues(alpha: 0.2)
                    : AppColors.telegramRed.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check_rounded : Icons.close_rounded,
                color:
                    isCorrect ? AppColors.telegramGreen : AppColors.telegramRed,
                size: ResponsiveValues.iconSizeS(context),
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    isCorrect ? 'Correct Answer!' : 'Incorrect',
                    style: AppTextStyles.titleSmall(context).copyWith(
                      color: isCorrect
                          ? AppColors.telegramGreen
                          : AppColors.telegramRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!isCorrect)
                    ResponsiveText(
                      'The correct answer is option ${question.correctOption.toUpperCase()}',
                      style: AppTextStyles.caption(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSelected
              ? () => _checkAnswer(questionId, _selectedAnswers[questionId]!)
              : null,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingL(context),
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: AppColors.blueGradient,
                    )
                  : LinearGradient(
                      colors: [
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                        AppColors.getSurface(context).withValues(alpha: 0.3),
                      ],
                    ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.telegramBlue.withValues(alpha: 0.3),
                        blurRadius: ResponsiveValues.spacingM(context),
                        offset: Offset(0, ResponsiveValues.spacingXS(context)),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: ResponsiveText(
                'Check Answer',
                style: AppTextStyles.labelLarge(context).copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationSection(Question question, int questionId) {
    final isCorrect = _isQuestionCorrect[questionId] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(top: 20),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.3),
                  AppColors.getCard(context).withValues(alpha: 0.1),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
              border: Border.all(
                color: isCorrect
                    ? AppColors.telegramGreen.withValues(alpha: 0.3)
                    : AppColors.telegramBlue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            padding: ResponsiveValues.cardPadding(context),
            child: ResponsiveColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveRow(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingXS(context)),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.telegramGreen.withValues(alpha: 0.2)
                            : AppColors.telegramBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCorrect
                            ? Icons.lightbulb_rounded
                            : Icons.info_rounded,
                        color: isCorrect
                            ? AppColors.telegramGreen
                            : AppColors.telegramBlue,
                        size: ResponsiveValues.iconSizeXS(context),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.s),
                    ResponsiveText(
                      'Explanation',
                      style: AppTextStyles.titleSmall(context).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  question.explanation ?? 'No explanation provided.',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
                if (!isCorrect) ...[
                  ResponsiveSizedBox(height: AppSpacing.l),
                  Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      color: AppColors.telegramGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context)),
                      border: Border.all(
                        color: AppColors.telegramGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: ResponsiveRow(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.telegramGreen,
                          size: 20,
                        ),
                        ResponsiveSizedBox(width: AppSpacing.m),
                        Expanded(
                          child: ResponsiveText(
                            'Correct answer: Option ${question.correctOption.toUpperCase()}',
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.telegramGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList({required int itemCount, String type = 'video'}) {
    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
            highlightColor: Colors.grey[100]!.withValues(alpha: 0.5),
            period: const Duration(milliseconds: 1500),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: ResponsiveValues.spacingS(context),
                    offset: Offset(0, ResponsiveValues.spacingXS(context)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                    child: ResponsiveRow(
                      children: [
                        Container(
                          width: type == 'video'
                              ? ResponsiveValues.spacingXXXL(context) * 3
                              : ResponsiveValues.iconSizeXXL(context),
                          height: type == 'video'
                              ? ResponsiveValues.spacingXXL(context) * 2
                              : ResponsiveValues.iconSizeXXL(context),
                          decoration: BoxDecoration(
                            color: Colors.grey[300]!.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(
                              type == 'video'
                                  ? ResponsiveValues.radiusMedium(context)
                                  : ResponsiveValues.radiusLarge(context),
                            ),
                          ),
                        ),
                        ResponsiveSizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: ResponsiveColumn(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: ResponsiveValues.spacingXL(context),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.grey[300]!.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusSmall(context),
                                  ),
                                ),
                              ),
                              ResponsiveSizedBox(height: AppSpacing.m),
                              ResponsiveRow(
                                children: [
                                  Container(
                                    width:
                                        ResponsiveValues.spacingXXL(context) *
                                            2,
                                    height: ResponsiveValues.spacingL(context),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300]!
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveValues.radiusMedium(context),
                                      ),
                                    ),
                                  ),
                                  ResponsiveSizedBox(width: AppSpacing.s),
                                  Container(
                                    width:
                                        ResponsiveValues.spacingXXL(context) *
                                            1.5,
                                    height: ResponsiveValues.spacingL(context),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300]!
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveValues.radiusMedium(context),
                                      ),
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
                ),
              ),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) _pauseVideo();
    if (state == AppLifecycleState.resumed) _resumeVideoIfNeeded();
  }

  Widget _buildMobileLayout() {
    if (_isLoading && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Shimmer.fromColors(
            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
            highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
            child: Container(
              width: ResponsiveValues.spacingXXXL(context) * 4,
              height: ResponsiveValues.spacingXL(context),
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
          title: ResponsiveText(
            'Error',
            style: AppTextStyles.titleMedium(context),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: custom.ErrorWidget(
            title: 'Something went wrong',
            message: _errorMessage!,
            onRetry: _initialize,
            type: custom.ErrorType.general,
            fullScreen: false,
          ),
        ),
      );
    }

    if (_chapter == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: ResponsiveText(
            'Not Found',
            style: AppTextStyles.titleMedium(context),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
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

    if (!_hasAccess && !_isCheckingAccess) return _buildAccessDeniedScreen();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          _chapter!.name,
          style: AppTextStyles.titleMedium(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: ResponsiveIcon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: ResponsiveIcon(
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
      body: ResponsiveColumn(
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
        showTopSnackBar(context, 'Cannot open file', isError: true);
      }
    } catch (e) {
      showTopSnackBar(context, 'Error opening file: $e', isError: true);
    }
  }

  Widget _buildPdfViewer(String filePath) {
    return SfPdfViewer.file(File(filePath),
        canShowPaginationDialog: true, canShowScrollHead: true);
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
        title: ResponsiveText(
          note.title,
          style: AppTextStyles.titleMedium(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: ResponsiveIcon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasFile && cachedPath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded,
                  color: AppColors.telegramBlue),
              onPressed: () => _openFile(context, cachedPath!),
              tooltip: 'Open File',
            ),
        ],
      ),
      body: ResponsiveColumn(
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
              child: ResponsiveRow(
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
                    child: ResponsiveIcon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.note_alt_rounded,
                      size: ResponsiveValues.iconSizeL(context),
                      color: AppColors.telegramBlue,
                    ),
                  ),
                  ResponsiveSizedBox(width: AppSpacing.l),
                  Expanded(
                    child: ResponsiveColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveText(
                          isPdf ? 'PDF Document' : 'Text Document',
                          style: AppTextStyles.titleSmall(context),
                        ),
                        if (cachedPath != null)
                          ResponsiveRow(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppColors.telegramGreen),
                              ResponsiveSizedBox(width: AppSpacing.xs),
                              ResponsiveText(
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
