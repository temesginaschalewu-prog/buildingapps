// lib/screens/main/progress_screen.dart
// COMPLETE FIXED VERSION - NULL SAFETY IN INITSTATE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/progress/achievement_badge.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  Timer? _backgroundRefreshTimer;
  Timer? _debounceTimer;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _statsSubscription;
  StreamSubscription? _streakSubscription;
  StreamSubscription? _authSubscription;
  StreamSubscription? _connectivitySubscription;
  bool _isOffline = false;
  int _pendingCount = 0;
  bool _hasInitialData = false;
  DateTime? _lastRefreshTime;
  bool _isMounted = false; // ✅ Track mounted state

  final Map<String, bool> _loadingSections = {
    'stats': true,
    'overview': true,
    'exams': true,
    'achievements': true,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.addObserver(this);

    // ✅ DON'T access context here - use post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _initialize();
      }
    });

    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isMounted && !_isRefreshing && !_isOffline) {
        _refreshDataInBackground();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false; // ✅ Mark as unmounted immediately
    WidgetsBinding.instance.removeObserver(this);
    _backgroundRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _progressSubscription?.cancel();
    _statsSubscription?.cancel();
    _streakSubscription?.cancel();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_isMounted) return;

    await _checkConnectivity();
    _setupConnectivityListener();
    _setupStreamListeners();
    _initializeData();
  }

  void _setupConnectivityListener() {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!_isMounted) return;

      setState(() {
        _isOffline = !isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });

      if (isOnline && !_isRefreshing && _hasInitialData) {
        unawaited(_refreshDataInBackground());
      }
    });
  }

  void _setupStreamListeners() {
    if (!_isMounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted) return;

      final progressProvider = context.read<ProgressProvider>();
      final authProvider = context.read<AuthProvider>();

      _progressSubscription = progressProvider.progressUpdates.listen((
        progress,
      ) {
        if (_isMounted) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (_isMounted)
              setState(() => _updateLoadingStates(progressProvider));
          });
        }
      });

      _statsSubscription = progressProvider.overallStatsUpdates.listen((stats) {
        if (_isMounted) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (_isMounted)
              setState(() => _updateLoadingStates(progressProvider));
          });
        }
      });

      _authSubscription = authProvider.userChanges.listen((user) {
        if (_isMounted && user != null && !_isOffline) {
          _refreshDataInBackground();
        }
      });
    });
  }

  void _updateLoadingStates(ProgressProvider progressProvider) {
    _loadingSections['stats'] = progressProvider.isLoadingOverall;
    _loadingSections['overview'] = progressProvider.isLoadingOverall;
    _loadingSections['exams'] = progressProvider.isLoadingOverall;
    _loadingSections['achievements'] = progressProvider.isLoadingOverall;
  }

  Future<void> _checkConnectivity() async {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!_isMounted) return;

    setState(() {
      _isOffline = !connectivityService.isOnline;
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    });
  }

  Future<void> _initializeData() async {
    try {
      final streakProvider = context.read<StreakProvider>();
      final examProvider = context.read<ExamProvider>();
      final progressProvider = context.read<ProgressProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      await Future.wait([
        streakProvider.loadStreak(),
        examProvider.loadMyExamResults(),
        categoryProvider.loadCategories(),
        progressProvider.loadOverallProgress(),
      ]);

      await _loadNotifications();
      if (!_isMounted) return;

      _hasInitialData = progressProvider.hasLoadedOverall ||
          progressProvider.hasLoadedProgress ||
          examProvider.myExamResults.isNotEmpty ||
          streakProvider.streak != null;

      if (_isMounted) {
        setState(() {
          _updateLoadingStates(progressProvider);
        });
      }
    } catch (e) {
      debugLog('ProgressScreen', 'Error initializing data: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (_isRefreshing || !_isMounted) return;
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 30)) {
      return;
    }

    _isRefreshing = true;

    try {
      final streakProvider = context.read<StreakProvider>();
      final examProvider = context.read<ExamProvider>();
      final progressProvider = context.read<ProgressProvider>();

      await Future.wait([
        streakProvider.loadStreak(forceRefresh: true),
        examProvider.loadMyExamResults(forceRefresh: true),
        progressProvider.loadOverallProgress(forceRefresh: true),
      ]);

      await _loadNotifications();
      if (!_isMounted) return;

      _lastRefreshTime = DateTime.now();

      if (_isMounted) {
        setState(() => _updateLoadingStates(progressProvider));
      }
    } catch (e) {
      debugLog('ProgressScreen', 'Background refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing || !_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final streakProvider = context.read<StreakProvider>();
      final examProvider = context.read<ExamProvider>();
      final progressProvider = context.read<ProgressProvider>();

      await Future.wait([
        streakProvider.loadStreak(forceRefresh: true, isManualRefresh: true),
        examProvider.loadMyExamResults(
          forceRefresh: true,
          isManualRefresh: true,
        ),
        progressProvider.loadOverallProgress(
          forceRefresh: true,
          isManualRefresh: true,
        ),
      ]);

      await _loadNotifications();
      if (!_isMounted) return;

      _lastRefreshTime = DateTime.now();
      setState(() => _isOffline = false);

      SnackbarService().showSuccess(context, AppStrings.progressUpdated);
    } catch (e) {
      final message = e.toString();
      final looksOffline = message.toLowerCase().contains('network error') ||
          message.toLowerCase().contains('socket') ||
          message.toLowerCase().contains('connection');

      if (looksOffline) {
        setState(() => _isOffline = true);
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        setState(() => _isOffline = false);
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
    } finally {
      if (_isMounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.loadNotifications();
    } catch (e) {
      // Silent fail
    }
  }

  Widget _buildStatShimmer() {
    return AppCard.glass(
      child: Container(
        width: ResponsiveValues.statCircleSize(context),
        height: ResponsiveValues.statCircleSize(context),
        padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
        child: const AppShimmer(type: ShimmerType.circle),
      ),
    );
  }

  Widget _buildStatCircle({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard.glass(
          child: Container(
            width: ResponsiveValues.statCircleSize(context),
            height: ResponsiveValues.statCircleSize(context),
            padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: ResponsiveValues.iconSizeS(context),
                  color: color,
                ),
                SizedBox(height: ResponsiveValues.spacingXS(context)),
                Text(
                  value,
                  style: AppTextStyles.titleMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          label,
          style: AppTextStyles.labelSmall(
            context,
          ).copyWith(color: AppColors.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildStatsSection({
    required int streakCount,
    required int chaptersCompleted,
    required double totalAccuracy,
    required bool isLoading,
  }) {
    if (isLoading && !_hasInitialData) {
      return AppCard.stats(
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: ResponsiveValues.spacingL(context),
          spacing: ResponsiveValues.spacingL(context),
          children: List.generate(3, (index) => _buildStatShimmer()),
        ),
      );
    }

    return AppCard.stats(
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: ResponsiveValues.spacingL(context),
        spacing: ResponsiveValues.spacingL(context),
        children: [
          _buildStatCircle(
            value: streakCount.toString(),
            label: AppStrings.dayStreak,
            color: AppColors.telegramBlue,
            icon: Icons.local_fire_department_rounded,
          ),
          _buildStatCircle(
            value: chaptersCompleted.toString(),
            label: AppStrings.chapters,
            color: AppColors.telegramGreen,
            icon: Icons.book_rounded,
          ),
          _buildStatCircle(
            value: '${totalAccuracy.toStringAsFixed(0)}%',
            label: AppStrings.accuracy,
            color: totalAccuracy >= 70
                ? AppColors.telegramGreen
                : totalAccuracy >= 40
                    ? AppColors.telegramYellow
                    : AppColors.telegramRed,
            icon: Icons.auto_graph_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection({
    required int totalChaptersAttempted,
    required int chaptersCompleted,
    required double totalAccuracy,
    required double studyTimeHours,
    required bool isLoading,
  }) {
    final completedPercentage = totalChaptersAttempted > 0
        ? (chaptersCompleted / totalChaptersAttempted * 100.0).clamp(0, 100)
        : 0.0;

    if (isLoading && !_hasInitialData) {
      return AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppShimmer(type: ShimmerType.textLine, customWidth: 200),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              ...List.generate(
                2,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: ResponsiveValues.spacingXL(context),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppShimmer(
                            type: ShimmerType.textLine,
                            customWidth: 120,
                          ),
                          AppShimmer(
                            type: ShimmerType.textLine,
                            customWidth: 60,
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveValues.spacingS(context)),
                      AppShimmer(
                        type: ShimmerType.rectangle,
                        customHeight: ResponsiveValues.progressBarHeight(
                          context,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.progressOverview,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              children: [
                _buildProgressItem(
                  title: AppStrings.chapterCompletion,
                  value: '$chaptersCompleted/$totalChaptersAttempted',
                  percentage: completedPercentage.toDouble(),
                  color: completedPercentage >= 80
                      ? AppColors.telegramGreen
                      : completedPercentage >= 40
                          ? AppColors.telegramBlue
                          : AppColors.telegramYellow,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                _buildProgressItem(
                  title: AppStrings.questionAccuracy,
                  value:
                      '${totalAccuracy.toStringAsFixed(1)}% ${AppStrings.correct}',
                  percentage: totalAccuracy.toDouble(),
                  color: totalAccuracy >= 80
                      ? AppColors.telegramGreen
                      : totalAccuracy >= 60
                          ? AppColors.telegramBlue
                          : AppColors.telegramYellow,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.studyTime,
                            style: AppTextStyles.titleSmall(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: ResponsiveValues.spacingXS(context)),
                          Text(
                            '${studyTimeHours.toStringAsFixed(1)} ${AppStrings.hours}',
                            style: AppTextStyles.bodyMedium(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: ResponsiveValues.iconSizeXL(context) * 1.5,
                      height: ResponsiveValues.iconSizeXL(context) * 1.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.purpleGradient,
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.timer_rounded,
                          size: ResponsiveValues.iconSizeL(context),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem({
    required String title,
    required String value,
    required double percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXS(context)),
                  Text(
                    value,
                    style: AppTextStyles.bodySmall(
                      context,
                    ).copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingS(context)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.titleMedium(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        ClipRRect(
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusSmall(context),
          ),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.getSurface(
              context,
            ).withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: ResponsiveValues.progressBarHeight(context),
          ),
        ),
      ],
    );
  }

  Widget _buildExamPerformanceSection(List examResults, bool isLoading) {
    if (isLoading && !_hasInitialData) {
      return AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            children: [
              const AppShimmer(type: ShimmerType.textLine, customWidth: 150),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              ...List.generate(
                2,
                (index) => Container(
                  margin: EdgeInsets.only(
                    bottom: ResponsiveValues.spacingM(context),
                  ),
                  height: ResponsiveValues.spacingXXL(context) * 2,
                  child: const AppShimmer(type: ShimmerType.rectangle),
                ),
              ),
            ],
          ),
        ),
      );
    }

    int passedCount = 0;
    double totalScore = 0;
    int validExams = 0;

    for (var exam in examResults) {
      try {
        if (exam.passed == true) passedCount++;
        final score = exam.score;
        if (score != null) {
          totalScore += score;
          validExams++;
        }
      } catch (e) {}
    }

    final averageScore = validExams > 0 ? (totalScore / validExams) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.examPerformance,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              children: [
                if (examResults.isEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: ResponsiveValues.iconSizeXXL(context),
                          color: AppColors.getTextSecondary(
                            context,
                          ).withValues(alpha: 0.3),
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          _isOffline
                              ? AppStrings.noCachedExamResults
                              : AppStrings.noExamsTaken,
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          _isOffline
                              ? AppStrings.connectToViewExamResults
                              : AppStrings.takeFirstExam,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: AppColors.getTextSecondary(
                              context,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runSpacing: ResponsiveValues.spacingL(context),
                    spacing: ResponsiveValues.spacingL(context),
                    children: [
                      _buildExamStat(
                        title: AppStrings.total,
                        value: '${examResults.length}',
                        color: AppColors.telegramBlue,
                        icon: Icons.assignment_rounded,
                      ),
                      _buildExamStat(
                        title: AppStrings.passed,
                        value: '$passedCount',
                        color: AppColors.telegramGreen,
                        icon: Icons.check_circle_rounded,
                      ),
                      _buildExamStat(
                        title: AppStrings.avgScore,
                        value: '${averageScore.toStringAsFixed(1)}%',
                        color: averageScore >= 70
                            ? AppColors.telegramGreen
                            : averageScore >= 50
                                ? AppColors.telegramYellow
                                : AppColors.telegramRed,
                        icon: Icons.score_rounded,
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  ...List.generate(
                    examResults.length > 3 ? 3 : examResults.length,
                    (index) {
                      final exam = examResults[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < (examResults.length - 1)
                              ? ResponsiveValues.spacingM(context)
                              : 0,
                        ),
                        child: _buildExamResultCard(exam),
                      );
                    },
                  ),
                  if (examResults.length > 3)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: ResponsiveValues.spacingS(context),
                        ),
                        child: Text(
                          '+ ${examResults.length - 3} ${AppStrings.moreExams}',
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningMetricsSection(
    Map<String, dynamic> stats,
    bool isLoading,
  ) {
    if (isLoading && !_hasInitialData) {
      return AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: AppShimmer(
            type: ShimmerType.rectangle,
            customHeight: ResponsiveValues.spacingXXL(context) * 3,
          ),
        ),
      );
    }

    final videosCompleted = stats['videos_completed'] ?? 0;
    final notesViewed = stats['total_notes_viewed'] ?? 0;
    final questionsAttempted = stats['total_questions_attempted'] ?? 0;
    final examsTaken = stats['exams_taken'] ?? 0;
    final examsPassed = stats['exams_passed'] ?? 0;
    final averageExamScore = (stats['average_exam_score'] ?? 0).toDouble();
    final overallCompletion = stats['overall_completion_percentage'] ?? 0;

    Widget metric(String title, String value, IconData icon, Color color) {
      return Container(
        padding: ResponsiveValues.cardPadding(context),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusMedium(context),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: ResponsiveValues.iconSizeS(context), color: color),
            SizedBox(width: ResponsiveValues.spacingS(context)),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodySmall(
                  context,
                ).copyWith(color: AppColors.getTextSecondary(context)),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.titleSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.learningMetrics,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              children: [
                metric(
                  AppStrings.overallCompletion,
                  '$overallCompletion%',
                  Icons.track_changes_rounded,
                  AppColors.telegramBlue,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                metric(
                  AppStrings.videosCompleted,
                  '$videosCompleted',
                  Icons.ondemand_video_rounded,
                  AppColors.telegramPurple,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                metric(
                  AppStrings.notesViewed,
                  '$notesViewed',
                  Icons.note_alt_rounded,
                  AppColors.telegramGreen,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                metric(
                  AppStrings.questionsAttempted,
                  '$questionsAttempted',
                  Icons.quiz_rounded,
                  AppColors.telegramYellow,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                metric(
                  AppStrings.examsPassedTaken,
                  '$examsPassed/$examsTaken',
                  Icons.assignment_turned_in_rounded,
                  AppColors.telegramGreen,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                metric(
                  AppStrings.averageExamScore,
                  '${averageExamScore.toStringAsFixed(1)}%',
                  Icons.leaderboard_rounded,
                  AppColors.telegramBlue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExamStat({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: ResponsiveValues.iconSizeXL(context),
            height: ResponsiveValues.iconSizeXL(context),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusSmall(context),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: ResponsiveValues.iconSizeS(context),
                color: color,
              ),
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            value,
            style: AppTextStyles.titleSmall(
              context,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            title,
            style: AppTextStyles.labelSmall(
              context,
            ).copyWith(color: AppColors.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildExamResultCard(dynamic exam) {
    final score = exam.score?.toDouble() ?? 0.0;
    final title = exam.title?.toString() ?? AppStrings.exam;
    final courseName = exam.courseName?.toString() ?? AppStrings.general;
    final passed = exam.passed == true;
    final examType = (exam.examType?.toString() ?? 'GENERAL').toUpperCase();
    final scoreText =
        exam.formattedScore?.toString() ?? '${score.toStringAsFixed(1)}%';

    return AppCard.glass(
      child: Container(
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: passed
                      ? [
                          AppColors.telegramGreen.withValues(alpha: 0.2),
                          AppColors.telegramGreen.withValues(alpha: 0.1),
                        ]
                      : [
                          AppColors.telegramRed.withValues(alpha: 0.2),
                          AppColors.telegramRed.withValues(alpha: 0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusSmall(context),
                ),
              ),
              child: Center(
                child: Icon(
                  passed ? Icons.check_rounded : Icons.close_rounded,
                  size: ResponsiveValues.iconSizeS(context),
                  color:
                      passed ? AppColors.telegramGreen : AppColors.telegramRed,
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          courseName,
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingS(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: passed
                                ? [
                                    AppColors.telegramGreen.withValues(
                                      alpha: 0.2,
                                    ),
                                    AppColors.telegramGreen.withValues(
                                      alpha: 0.1,
                                    ),
                                  ]
                                : [
                                    AppColors.telegramRed.withValues(
                                      alpha: 0.2,
                                    ),
                                    AppColors.telegramRed.withValues(
                                      alpha: 0.1,
                                    ),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: Text(
                          passed ? AppStrings.passed : AppStrings.failed,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: passed
                                ? AppColors.telegramGreen
                                : AppColors.telegramRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingS(context)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  scoreText,
                  style: AppTextStyles.titleSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  examType,
                  style: AppTextStyles.labelSmall(
                    context,
                  ).copyWith(color: AppColors.getTextSecondary(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(List achievements, bool isLoading) {
    if (isLoading && !_hasInitialData) {
      return AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppShimmer(type: ShimmerType.textLine, customWidth: 150),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveValues.gridColumns(context),
                  crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                  mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                  childAspectRatio: 0.9,
                ),
                itemCount: 6,
                itemBuilder: (context, index) =>
                    const AppShimmer(type: ShimmerType.rectangle),
              ),
            ],
          ),
        ),
      );
    }

    if (achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.achievements,
          style: AppTextStyles.titleLarge(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: ResponsiveValues.spacingS(context),
                mainAxisSpacing: ResponsiveValues.spacingS(context),
                childAspectRatio: 0.9,
              ),
              itemCount: achievements.length > 6 ? 6 : achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return AchievementBadge(
                  title: achievement['title'] ?? AppStrings.achievement,
                  description: achievement['description'] ?? '',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.telegramYellow,
                  unlocked: true,
                  earnedDate: achievement['earnedAt'] != null
                      ? DateTime.parse(achievement['earnedAt'])
                      : null,
                );
              },
            ),
          ),
        ),
        if (achievements.length > 6)
          Padding(
            padding: EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
            child: Center(
              child: Text(
                '+ ${achievements.length - 6} ${AppStrings.moreAchievements}',
                style: AppTextStyles.labelSmall(
                  context,
                ).copyWith(color: AppColors.getTextSecondary(context)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline) {
      _refreshDataInBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer5<AuthProvider, StreakProvider, ExamProvider,
        ProgressProvider, CategoryProvider>(
      builder: (
        context,
        authProvider,
        streakProvider,
        examProvider,
        progressProvider,
        categoryProvider,
        child,
      ) {
        final statsData = progressProvider.overallStats['stats'];
        final Map<String, dynamic> stats =
            statsData is Map ? Map<String, dynamic>.from(statsData) : {};

        final chaptersCompleted = stats['chapters_completed'] ?? 0;
        final totalChaptersAttempted = stats['total_chapters_attempted'] ?? 0;
        final totalAccuracy = stats['accuracy_percentage']?.toDouble() ?? 0.0;
        final studyTimeHours = stats['study_time_hours']?.toDouble() ?? 0.0;
        final streakCount = streakProvider.streak?.currentStreak ??
            authProvider.currentUser?.streakCount ??
            0;
        final examResults = examProvider.myExamResults;
        final achievements = progressProvider.achievements;

        if (_isOffline &&
            !progressProvider.hasLoadedOverall &&
            !progressProvider.hasLoadedProgress &&
            examResults.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.getBackground(context),
            appBar: const CustomAppBar(
              title: AppStrings.progress,
              subtitle: AppStrings.offlineMode,
              showOfflineIndicator: true,
            ),
            body: Center(
              child: AppEmptyState.offline(
                dataType: AppStrings.progress,
                message: AppStrings.offlineProgressMessage,
                onRetry: () {
                  setState(() => _isOffline = false);
                  _checkConnectivity();
                  _manualRefresh();
                },
                pendingCount: _pendingCount,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.getBackground(context),
          body: RefreshIndicator(
            onRefresh: _manualRefresh,
            color: AppColors.telegramBlue,
            backgroundColor: AppColors.getSurface(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: CustomAppBar(
                    title: AppStrings.progress,
                    subtitle: _isOffline
                        ? AppStrings.offlineCachedData
                        : AppStrings.trackLearningJourney,
                    showOfflineIndicator: _isOffline,
                  ),
                ),
                if (_isOffline && _pendingCount > 0)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.all(
                        ResponsiveValues.spacingM(context),
                      ),
                      padding: ResponsiveValues.cardPadding(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.info.withValues(alpha: 0.2),
                            AppColors.info.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: AppColors.info,
                            size: ResponsiveValues.iconSizeS(context),
                          ),
                          SizedBox(
                            width: ResponsiveValues.spacingM(context),
                          ),
                          Expanded(
                            child: Text(
                              '$_pendingCount pending change${_pendingCount > 1 ? 's' : ''}',
                              style: AppTextStyles.bodySmall(
                                context,
                              ).copyWith(color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.all(
                    ResponsiveValues.sectionPadding(context),
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatsSection(
                        streakCount: streakCount,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        isLoading: progressProvider.isLoadingOverall &&
                            !_hasInitialData,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      _buildOverviewSection(
                        totalChaptersAttempted: totalChaptersAttempted,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        studyTimeHours: studyTimeHours,
                        isLoading: progressProvider.isLoadingOverall &&
                            !_hasInitialData,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      _buildExamPerformanceSection(
                        examResults,
                        progressProvider.isLoadingOverall && !_hasInitialData,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      _buildLearningMetricsSection(
                        stats,
                        progressProvider.isLoadingOverall && !_hasInitialData,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      if (achievements.isNotEmpty)
                        _buildAchievementsSection(
                          achievements,
                          progressProvider.isLoadingOverall && !_hasInitialData,
                        ),
                      SizedBox(
                        height: ResponsiveValues.spacingXXL(context),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: AppThemes.animationMedium);
      },
    );
  }
}
