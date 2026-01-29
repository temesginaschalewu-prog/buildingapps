// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../models/chapter_model.dart';
import '../../models/video_model.dart';
import '../../models/note_model.dart';
import '../../models/question_model.dart';
import '../../providers/video_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/video_protection.dart';
import '../../themes/app_colors.dart';
import '../../widgets/common/loading_indicator.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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

class _ChapterContentScreenState extends State<ChapterContentScreen> {
  Chapter? _chapter;
  Course? _course;
  Category? _category;
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isCheckingAccess = true;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int? _currentPlayingVideoId;

  Map<int, String?> _selectedAnswers = {};
  Map<int, bool> _showExplanation = {};
  Map<int, bool> _isQuestionCorrect = {};

  bool _hasInitialized = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeFromCache();
    _loadData();

    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _refreshDataInBackground();
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initializeFromCache() {
    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );
    final courseProvider = Provider.of<CourseProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    if (widget.chapter != null) {
      _chapter = widget.chapter;
      _course = widget.course;
      _category = widget.category;

      if (widget.hasAccess != null) {
        _hasAccess = widget.hasAccess!;
      } else if (_category != null) {
        _hasAccess = subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);
      }

      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
      return;
    }

    Chapter? foundChapter;

    for (final category in categoryProvider.categories) {
      final courses = courseProvider.getCoursesByCategory(category.id);

      for (final course in courses) {
        final chapters = chapterProvider.getChaptersByCourse(course.id);

        for (final chapter in chapters) {
          if (chapter.id == widget.chapterId) {
            foundChapter = chapter;
            _course = course;
            _category = category;
            break;
          }
        }

        if (foundChapter != null) break;
      }

      if (foundChapter != null) break;
    }

    if (foundChapter != null) {
      _chapter = foundChapter;

      if (_category != null) {
        _hasAccess = subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);
      }

      if (_hasAccess) {
        _loadCachedContent();
      }

      setState(() {
        _isLoading = false;
        _isCheckingAccess = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      if (_chapter != null && _hasAccess && _hasInitialized) {
        return;
      }

      final chapterProvider = Provider.of<ChapterProvider>(
        context,
        listen: false,
      );
      final courseProvider = Provider.of<CourseProvider>(
        context,
        listen: false,
      );
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final subscriptionProvider = Provider.of<SubscriptionProvider>(
        context,
        listen: false,
      );

      Chapter? foundChapter;

      for (final category in categoryProvider.categories) {
        if (courseProvider.getCoursesByCategory(category.id).isEmpty) {
          await courseProvider.loadCoursesByCategory(category.id,
              forceRefresh: false);
        }

        final courses = courseProvider.getCoursesByCategory(category.id);

        for (final course in courses) {
          if (!chapterProvider.hasLoadedForCourse(course.id)) {
            await chapterProvider.loadChaptersByCourse(course.id,
                forceRefresh: false);
          }

          final chapters = chapterProvider.getChaptersByCourse(course.id);

          for (final chapter in chapters) {
            if (chapter.id == widget.chapterId) {
              foundChapter = chapter;
              _course = course;
              _category = category;
              break;
            }
          }

          if (foundChapter != null) break;
        }

        if (foundChapter != null) break;
      }

      if (foundChapter == null) {
        debugLog(
          'ChapterContentScreen',
          'Chapter ${widget.chapterId} not found',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isCheckingAccess = false;
          });
        }
        return;
      }

      _chapter = foundChapter;

      if (_category != null && authProvider.user != null) {
        final hasSubscription = subscriptionProvider
            .hasActiveSubscriptionForCategory(_category!.id);

        _hasAccess = _chapter!.isFree || hasSubscription;

        debugLog(
          'ChapterContentScreen',
          'Access check: Chapter free=${_chapter!.isFree}, Has subscription=$hasSubscription, Has access=$_hasAccess',
        );
      } else {
        _hasAccess = _chapter!.isFree;
      }

      if (_hasAccess) {
        await _loadContent();
      }

      _hasInitialized = true;
    } catch (e) {
      debugLog('ChapterContentScreen', 'Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingAccess = false;
        });
      }
    }
  }

  void _loadCachedContent() {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final questionProvider = Provider.of<QuestionProvider>(
      context,
      listen: false,
    );

    final hasCachedVideos = videoProvider.hasLoadedForChapter(widget.chapterId);
    final hasCachedNotes = noteProvider.hasLoadedForChapter(widget.chapterId);
    final hasCachedQuestions =
        questionProvider.hasLoadedForChapter(widget.chapterId);

    debugLog('ChapterContentScreen',
        'Cache check - Videos: $hasCachedVideos, Notes: $hasCachedNotes, Questions: $hasCachedQuestions');

    _hasInitialized = hasCachedVideos || hasCachedNotes || hasCachedQuestions;
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    try {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final questionProvider = Provider.of<QuestionProvider>(
        context,
        listen: false,
      );

      unawaited(videoProvider.loadVideosByChapter(widget.chapterId,
          forceRefresh: forceRefresh));
      unawaited(noteProvider.loadNotesByChapter(widget.chapterId,
          forceRefresh: forceRefresh));
      unawaited(questionProvider.loadPracticeQuestions(widget.chapterId,
          forceRefresh: forceRefresh));

      _hasInitialized = true;
    } catch (e) {
      debugLog('ChapterContentScreen', 'Error loading content: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (!_hasAccess || _chapter == null) return;

    try {
      await _loadContent(forceRefresh: true);
      debugLog('ChapterContentScreen', '✅ Background refresh completed');
    } catch (e) {
      debugLog('ChapterContentScreen', 'Background refresh error: $e');
    }
  }

  void _showPaymentDialog() {
    if (_category == null) {
      showSnackBar(
        context,
        'Unable to determine category for payment',
        isError: true,
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final router = GoRouter.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Text(
          'You need to purchase "${_category!.name}" to access this chapter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              router.push(
                '/payment',
                extra: {
                  'category': _category,
                  'paymentType': authProvider.user?.accountStatus == 'active'
                      ? 'repayment'
                      : 'first_time',
                },
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(Video video) async {
    try {
      _videoController?.dispose();
      _chewieController?.dispose();

      setState(() {
        _currentPlayingVideoId = video.id;
      });

      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      await videoProvider.incrementViewCount(video.id);

      final videoUrl = video.fullVideoUrl;
      debugLog('ChapterContentScreen', 'Playing video from: $videoUrl');

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await _videoController!.initialize();

      _chewieController = VideoProtection.createProtectedController(
        videoPlayerController: _videoController!,
        context: context,
        videoUrl: videoUrl,
        autoPlay: true,
        looping: false,
      );

      await showDialog(
        context: context,
        builder: (context) => VideoProtection.createProtectedVideoPlayer(
          controller: _chewieController!,
          context: context,
          videoTitle: video.title,
          onDispose: () {
            // Dispose controllers when video player is closed
            _chewieController?.dispose();
            _videoController?.dispose();
            setState(() {
              _currentPlayingVideoId = null;
            });
          },
        ),
      );
    } catch (e) {
      debugLog('ChapterContentScreen', 'Video play error: $e');
      showSnackBar(context, 'Failed to play video: ${e.toString()}',
          isError: true);
      setState(() {
        _currentPlayingVideoId = null;
      });
    }
  }

  void _selectAnswer(int questionId, String option) {
    setState(() {
      _selectedAnswers[questionId] = option;
      _showExplanation[questionId] = false;
    });
  }

  Future<void> _checkAnswer(int questionId, String selectedOption) async {
    if (selectedOption.isEmpty) {
      showSnackBar(context, 'Please select an answer first', isError: true);
      return;
    }

    final questionProvider = Provider.of<QuestionProvider>(
      context,
      listen: false,
    );

    try {
      final result = await questionProvider.checkAnswer(
        questionId,
        selectedOption,
      );

      setState(() {
        _showExplanation[questionId] = true;
        _isQuestionCorrect[questionId] = result['is_correct'] == true;
      });
    } catch (e) {
      showSnackBar(context, 'Failed to check answer: $e', isError: true);
    }
  }

  Color _getOptionColor(int questionId, String option, String correctOption) {
    if (!_showExplanation[questionId]!) return Colors.transparent;

    if (option == correctOption) {
      return AppColors.success.withOpacity(0.1);
    } else if (option == _selectedAnswers[questionId]) {
      return AppColors.error.withOpacity(0.1);
    }
    return Colors.transparent;
  }

  Color _getOptionBorderColor(
    int questionId,
    String option,
    String correctOption,
  ) {
    if (!_showExplanation[questionId]!) return AppColors.border;

    if (option == correctOption) {
      return AppColors.success;
    } else if (option == _selectedAnswers[questionId]) {
      return AppColors.error;
    }
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_hasInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingIndicator(),
      );
    }

    if (_chapter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chapter Not Found')),
        body: const Center(
          child: Text('Chapter not found or no longer available.'),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_chapter!.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _chapter!.isFree ? Icons.error_outline : Icons.lock,
                  size: 64,
                  color: _chapter!.isFree ? Colors.orange : AppColors.locked,
                ),
                const SizedBox(height: 16),
                Text(
                  _chapter!.isFree ? 'Coming Soon' : 'Chapter Locked',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _chapter!.isFree
                      ? 'This chapter will be available soon.'
                      : '"${_chapter!.name}" is locked. You need to purchase the category to access it.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_chapter!.isFree)
                  ElevatedButton(
                    onPressed: _showPaymentDialog,
                    child: const Text('Purchase Access'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_chapter!.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.video_library), text: 'Videos'),
              Tab(icon: Icon(Icons.note), text: 'Notes'),
              Tab(icon: Icon(Icons.quiz), text: 'Practice'),
            ],
            onTap: (index) => setState(() => _selectedTab = index),
          ),
        ),
        body: TabBarView(
          children: [
            _buildVideosTab(),
            _buildNotesTab(),
            _buildPracticeTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosTab() {
    final videoProvider = Provider.of<VideoProvider>(context);
    final videos = videoProvider.getVideosByChapter(widget.chapterId);

    if (videoProvider.isLoadingForChapter(widget.chapterId) && videos.isEmpty) {
      return const LoadingIndicator();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await videoProvider.loadVideosByChapter(widget.chapterId,
            forceRefresh: true);
      },
      child: videos.isEmpty
          ? const Center(child: Text('No videos available for this chapter.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: video.hasThumbnail
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                video.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.play_circle_fill),
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_fill,
                              color: AppColors.primary,
                            ),
                    ),
                    title: Text(
                      video.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (video.duration != null)
                          Text(
                            'Duration: ${_formatDuration(video.duration!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        Text(
                          '${video.viewCount} views',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: _currentPlayingVideoId == video.id
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    onTap: () => _playVideo(video),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotesTab() {
    final noteProvider = Provider.of<NoteProvider>(context);
    final notes = noteProvider.getNotesByChapter(widget.chapterId);

    if (noteProvider.isLoadingForChapter(widget.chapterId) && notes.isEmpty) {
      return const LoadingIndicator();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await noteProvider.loadNotesByChapter(widget.chapterId,
            forceRefresh: true);
      },
      child: notes.isEmpty
          ? const Center(child: Text('No notes available for this chapter.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.note, color: AppColors.primary),
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Created: ${note.formattedDate}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteDetailScreen(note: note),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPracticeTab() {
    final questionProvider = Provider.of<QuestionProvider>(context);
    final questions = questionProvider.getQuestionsByChapter(widget.chapterId);

    if (questionProvider.isLoadingForChapter(widget.chapterId) &&
        questions.isEmpty) {
      return const LoadingIndicator();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await questionProvider.loadPracticeQuestions(widget.chapterId,
            forceRefresh: true);
      },
      child: questions.isEmpty
          ? const Center(
              child: Text('No practice questions available for this chapter.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                final questionId = question.id;

                _selectedAnswers[questionId] ??= null;
                _showExplanation[questionId] ??= false;
                _isQuestionCorrect[questionId] ??= false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(question.difficulty),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                question.difficulty.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Question ${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          question.questionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: _getQuestionOptions(question)
                              .asMap()
                              .entries
                              .map((entry) {
                            final optionIndex = entry.key;
                            final option = entry.value;
                            final optionLetter = String.fromCharCode(
                              65 + optionIndex,
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton(
                                onPressed: () =>
                                    _selectAnswer(questionId, optionLetter),
                                style: OutlinedButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.all(12),
                                  backgroundColor: _getOptionColor(
                                    questionId,
                                    optionLetter,
                                    question.correctOption,
                                  ),
                                  side: BorderSide(
                                    color: _getOptionBorderColor(
                                      questionId,
                                      optionLetter,
                                      question.correctOption,
                                    ),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _selectedAnswers[questionId] ==
                                                optionLetter
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _selectedAnswers[questionId] ==
                                                  optionLetter
                                              ? AppColors.primary
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          optionLetter,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _selectedAnswers[questionId] ==
                                                        optionLetter
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedAnswers[questionId] == null
                                ? null
                                : () => _checkAnswer(
                                      questionId,
                                      _selectedAnswers[questionId]!,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _showExplanation[questionId]!
                                  ? (_isQuestionCorrect[questionId]!
                                      ? AppColors.success
                                      : AppColors.error)
                                  : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              _showExplanation[questionId]!
                                  ? (_isQuestionCorrect[questionId]!
                                      ? '✓ Correct!'
                                      : '✗ Incorrect')
                                  : 'Check Answer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_showExplanation[questionId]!)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(
                                    color: AppColors.border, height: 1),
                                const SizedBox(height: 12),
                                const Text(
                                  'Explanation:',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  question.explanation ??
                                      'No explanation provided.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Correct Answer: ${question.correctOption.toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
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
            ),
    );
  }

  List<String> _getQuestionOptions(Question question) {
    final options = <String>[];
    if (question.optionA != null && question.optionA!.isNotEmpty)
      options.add(question.optionA!);
    if (question.optionB != null && question.optionB!.isNotEmpty)
      options.add(question.optionB!);
    if (question.optionC != null && question.optionC!.isNotEmpty)
      options.add(question.optionC!);
    if (question.optionD != null && question.optionD!.isNotEmpty)
      options.add(question.optionD!);
    if (question.optionE != null && question.optionE!.isNotEmpty)
      options.add(question.optionE!);
    if (question.optionF != null && question.optionF!.isNotEmpty)
      options.add(question.optionF!);
    return options;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      default:
        return AppColors.info;
    }
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
}

class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  note.formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (note.hasFile)
                  Chip(
                    label: const Text('Attachment'),
                    backgroundColor: AppColors.info.withOpacity(0.1),
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      color: AppColors.info,
                    ),
                    side: BorderSide(color: AppColors.info.withOpacity(0.3)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            HtmlWidget(
              note.content,
              textStyle: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textPrimary,
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
            if (note.hasFile)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(note.fullFilePath!))) {
                      await launchUrl(Uri.parse(note.fullFilePath!));
                    } else {
                      showSnackBar(context, 'Cannot open file', isError: true);
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Download Attachment'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
