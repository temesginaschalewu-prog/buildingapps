// lib/screens/main/progress_screen.dart
// PRODUCTION STANDARD - FIXED (no hasInitialData error)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/progress_provider.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/progress/achievement_badge.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with BaseScreenMixin<ProgressScreen>, AutomaticKeepAliveClientMixin {
  Timer? _backgroundRefreshTimer;
  Timer? _debounceTimer;
  DateTime? _lastRefreshTime;

  late StreakProvider _streakProvider;
  late ExamProvider _examProvider;
  late ProgressProvider _progressProvider;
  late AuthProvider _authProvider;
  bool _providersBound = false;
  VoidCallback? _streakListener;
  VoidCallback? _examListener;
  StreamSubscription? _progressUpdatesSubscription;
  StreamSubscription? _overallStatsSubscription;
  String? _boundUserId;

  final Map<String, bool> _loadingSections = {
    'stats': true,
    'overview': true,
    'exams': true,
    'achievements': true,
  };

  bool _hasData = false;

  @override
  bool get wantKeepAlive => true;

  @override
  String get screenTitle => AppStrings.progress;

  @override
  String? get screenSubtitle => isOffline
      ? AppStrings.offlineCachedData
      : AppStrings.trackLearningJourney;

  @override
  bool get isLoading =>
      _progressProvider.isLoadingOverall && !_progressProvider.hasLoadedOverall;

  @override
  bool get hasCachedData =>
      _progressProvider.hasLoadedOverall || _progressProvider.hasLoadedProgress;

  @override
  dynamic get errorMessage => null;

  @override
  void initState() {
    super.initState();

    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isMounted && !isRefreshing && !isOffline) {
        _refreshDataInBackground();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id.toString();

    if (_providersBound && _boundUserId == currentUserId) return;

    if (_providersBound) {
      _progressUpdatesSubscription?.cancel();
      _overallStatsSubscription?.cancel();
      if (_streakListener != null) {
        _streakProvider.removeListener(_streakListener!);
      }
      if (_examListener != null) {
        _examProvider.removeListener(_examListener!);
      }
      _hasData = false;
      _loadingSections.updateAll((key, value) => true);
    }

    _streakProvider = context.read<StreakProvider>();
    _examProvider = context.read<ExamProvider>();
    _progressProvider = context.read<ProgressProvider>();
    _authProvider = authProvider;
    _boundUserId = currentUserId;

    _setupStreamListeners();
    _providersBound = true;

    // ✅ Mark if we have data after first load - FIXED: use correct properties
    if (_progressProvider.hasLoadedOverall ||
        _streakProvider.streak != null ||
        _examProvider.hasLoadedResults) {
      _hasData = true;
    }
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _progressUpdatesSubscription?.cancel();
    _overallStatsSubscription?.cancel();
    if (_providersBound) {
      if (_streakListener != null) {
        _streakProvider.removeListener(_streakListener!);
      }
      if (_examListener != null) {
        _examProvider.removeListener(_examListener!);
      }
    }
    super.dispose();
  }

  void _setupStreamListeners() {
    _progressUpdatesSubscription = _progressProvider.progressUpdates.listen((_) {
      if (isMounted) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (isMounted) {
            setState(_updateLoadingStates);
            _hasData = true;
          }
        });
      }
    });

    _overallStatsSubscription =
        _progressProvider.overallStatsUpdates.listen((_) {
      if (isMounted) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (isMounted) {
            setState(_updateLoadingStates);
            _hasData = true;
          }
        });
      }
    });

    _streakListener = () {
      if (isMounted && _streakProvider.streak != null) {
        setState(() => _hasData = true);
      }
    };
    _streakProvider.addListener(_streakListener!);

    _examListener = () {
      if (isMounted && _examProvider.hasLoadedResults) {
        setState(() => _hasData = true);
      }
    };
    _examProvider.addListener(_examListener!);
  }

  void _updateLoadingStates() {
    _loadingSections['stats'] = _progressProvider.isLoadingOverall;
    _loadingSections['overview'] = _progressProvider.isLoadingOverall;
    _loadingSections['exams'] = _progressProvider.isLoadingOverall;
    _loadingSections['achievements'] = _progressProvider.isLoadingOverall;
  }

  @override
  Future<void> onRefresh() async {
    await Future.wait([
      _streakProvider.loadStreak(forceRefresh: true, isManualRefresh: true),
      _examProvider.loadMyExamResults(
          forceRefresh: true, isManualRefresh: true),
      _progressProvider.loadOverallProgress(
          forceRefresh: true, isManualRefresh: true),
    ]);
    _lastRefreshTime = DateTime.now();
    setState(() => _hasData = true);
  }

  Future<void> _refreshDataInBackground() async {
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 30)) {
      return;
    }

    await Future.wait([
      _streakProvider.loadStreak(forceRefresh: true),
      _examProvider.loadMyExamResults(forceRefresh: true),
      _progressProvider.loadOverallProgress(forceRefresh: true),
    ]);
    _lastRefreshTime = DateTime.now();
  }

  Widget _buildStatShimmer() {
    return AppCard.solid(
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
        AppCard.solid(
          child: Container(
            width: ResponsiveValues.statCircleSize(context),
            height: ResponsiveValues.statCircleSize(context),
            padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: ResponsiveValues.iconSizeS(context), color: color),
                SizedBox(height: ResponsiveValues.spacingXS(context)),
                Text(
                  value,
                  style: AppTextStyles.titleMedium(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          label,
          style: AppTextStyles.labelSmall(context)
              .copyWith(color: AppColors.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildStatsSection({
    required int streakCount,
    required int chaptersCompleted,
    required double totalAccuracy,
  }) {
    if (isLoading && !hasCachedData) {
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

  Widget _buildSectionHeader({
    required String title,
    String? description,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleLarge(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null) ...[
            SizedBox(height: ResponsiveValues.spacingXS(context)),
            Text(
              description,
              style: AppTextStyles.bodySmall(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewSection({
    required int totalChaptersAttempted,
    required int chaptersCompleted,
    required double totalAccuracy,
    required double studyTimeHours,
  }) {
    final completedPercentage = totalChaptersAttempted > 0
        ? (chaptersCompleted / totalChaptersAttempted * 100.0).clamp(0, 100)
        : 0.0;

    if (isLoading && !hasCachedData) {
      return AppCard.solid(
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
                      bottom: ResponsiveValues.spacingXL(context)),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppShimmer(
                              type: ShimmerType.textLine, customWidth: 120),
                          AppShimmer(
                              type: ShimmerType.textLine, customWidth: 60),
                        ],
                      ),
                      SizedBox(height: ResponsiveValues.spacingS(context)),
                      AppShimmer(
                        type: ShimmerType.rectangle,
                        customHeight:
                            ResponsiveValues.progressBarHeight(context),
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
        _buildSectionHeader(
          title: AppStrings.progressOverview,
          description:
              'A quick view of how steadily you are learning across chapters, questions, and study time.',
        ),
        AppCard.solid(
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
                            style: AppTextStyles.titleSmall(context)
                                .copyWith(fontWeight: FontWeight.w600),
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
                      width:
                          ResponsiveValues.featureCardIconContainerSize(
                              context),
                      height:
                          ResponsiveValues.featureCardIconContainerSize(
                              context),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C7FB4).withValues(alpha: 0.14),
                        border: Border.all(
                          color:
                              const Color(0xFF2C7FB4).withValues(alpha: 0.18),
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
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
                    style: AppTextStyles.titleSmall(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXS(context)),
                  Text(
                    value,
                    style: AppTextStyles.bodySmall(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingS(context)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.titleMedium(context)
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor:
                AppColors.getSurface(context).withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: ResponsiveValues.progressBarHeight(context),
          ),
        ),
      ],
    );
  }

  Widget _buildExamPerformanceSection() {
    final examResults = _examProvider.myExamResults;

    if (isLoading && !hasCachedData) {
      return AppCard.solid(
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
                      bottom: ResponsiveValues.spacingM(context)),
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
        totalScore += score;
        validExams++;
      } catch (e) {}
    }

    final averageScore = validExams > 0 ? (totalScore / validExams) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: AppStrings.examPerformance,
          description:
              'Recent results, pass rate, and average score across your completed exams.',
        ),
        AppCard.solid(
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
                          color: AppColors.getTextSecondary(context)
                              .withValues(alpha: 0.3),
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          isOffline
                              ? AppStrings.noCachedExamResults
                              : AppStrings.noExamsTaken,
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          isOffline
                              ? AppStrings.connectToViewExamResults
                              : AppStrings.takeFirstExam,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.7),
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
                            top: ResponsiveValues.spacingS(context)),
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
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
            ),
            child: Center(
              child: Icon(icon,
                  size: ResponsiveValues.iconSizeS(context), color: color),
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            value,
            style: AppTextStyles.titleSmall(context)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            title,
            style: AppTextStyles.labelSmall(context)
                .copyWith(color: AppColors.getTextSecondary(context)),
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

    return AppCard.solid(
      child: Container(
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                color: (passed ? AppColors.telegramGreen : AppColors.telegramRed)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color:
                      (passed ? AppColors.telegramGreen : AppColors.telegramRed)
                          .withValues(alpha: 0.18),
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context)),
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
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(fontWeight: FontWeight.w600),
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
                          color: (passed
                                  ? AppColors.telegramGreen
                                  : AppColors.telegramRed)
                              .withValues(alpha: 0.12),
                          border: Border.all(
                            color: (passed
                                    ? AppColors.telegramGreen
                                    : AppColors.telegramRed)
                                .withValues(alpha: 0.18),
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
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
                  style: AppTextStyles.titleSmall(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  examType,
                  style: AppTextStyles.labelSmall(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningMetricsSection() {
    final statsData = _progressProvider.overallStats['stats'];
    final Map<String, dynamic> stats =
        statsData is Map ? Map<String, dynamic>.from(statsData) : {};

    final videosCompleted = stats['videos_completed'] ?? 0;
    final notesViewed = stats['total_notes_viewed'] ?? 0;
    final questionsAttempted = stats['total_questions_attempted'] ?? 0;
    final examsTaken = stats['exams_taken'] ?? 0;
    final examsPassed = stats['exams_passed'] ?? 0;
    final averageExamScore = (stats['average_exam_score'] ?? 0).toDouble();
    final overallCompletion = stats['overall_completion_percentage'] ?? 0;

    if (isLoading && !hasCachedData) {
      return AppCard.solid(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: AppShimmer(
            type: ShimmerType.rectangle,
            customHeight: ResponsiveValues.spacingXXL(context) * 3,
          ),
        ),
      );
    }

    Widget metric(String title, String value, IconData icon, Color color) {
      return Container(
        padding: ResponsiveValues.cardPadding(context),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: ResponsiveValues.iconSizeS(context), color: color),
            SizedBox(width: ResponsiveValues.spacingS(context)),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodySmall(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.titleSmall(context)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: AppStrings.learningMetrics,
          description:
              'Your broader learning activity across videos, notes, questions, and exams.',
        ),
        AppCard.solid(
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

  Widget _buildAchievementsSection() {
    final achievements = _progressProvider.achievements;

    if (isLoading && !hasCachedData) {
      return AppCard.solid(
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
        _buildSectionHeader(
          title: AppStrings.achievements,
          description: 'Milestones you have unlocked along the way.',
        ),
        AppCard.solid(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
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
                style: AppTextStyles.labelSmall(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final statsData = _progressProvider.overallStats['stats'];
    final Map<String, dynamic> stats =
        statsData is Map ? Map<String, dynamic>.from(statsData) : {};

    final chaptersCompleted = stats['chapters_completed'] ?? 0;
    final totalChaptersAttempted = stats['total_chapters_attempted'] ?? 0;
    final totalAccuracy = stats['accuracy_percentage']?.toDouble() ?? 0.0;
    final studyTimeHours = stats['study_time_hours']?.toDouble() ?? 0.0;
    final streakCount = _streakProvider.streak?.currentStreak ??
        _authProvider.currentUser?.streakCount ??
        0;

    // ✅ CRITICAL: Only show empty state if NO data AND provider has finished loading
    final hasAnyData = _progressProvider.hasLoadedOverall ||
        _progressProvider.hasLoadedProgress ||
        _examProvider.myExamResults.isNotEmpty ||
        streakCount > 0 ||
        _hasData;

    // Offline with no data - show empty state
    if (isOffline && !hasAnyData && _progressProvider.hasLoadedOverall) {
      return buildOfflineWidget(dataType: AppStrings.progress);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatsSection(
                streakCount: streakCount,
                chaptersCompleted: chaptersCompleted,
                totalAccuracy: totalAccuracy,
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildOverviewSection(
                totalChaptersAttempted: totalChaptersAttempted,
                chaptersCompleted: chaptersCompleted,
                totalAccuracy: totalAccuracy,
                studyTimeHours: studyTimeHours,
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildExamPerformanceSection(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildLearningMetricsSection(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              if (_progressProvider.achievements.isNotEmpty)
                _buildAchievementsSection(),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildScreen(content: buildContent(context));
  }
}
