import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../widgets/progress/achievement_badge.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  bool _isInitialLoad = true;
  bool _hasInitialData = false;
  bool _isOffline = false;
  DateTime? _lastRefreshTime;

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
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentUserId();
      _checkConnectivity();
      _initializeData();
      _setupStreamListeners();
      _checkSubscriptionAccess();
    });

    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && !_isRefreshing && !_isOffline) {
        _refreshDataInBackground();
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    Provider.of<AuthProvider>(context, listen: false);
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
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

  Widget _buildStatShimmer() {
    return _buildGlassContainer(
      child: Container(
        width: ResponsiveValues.iconSizeXXL(context),
        height: ResponsiveValues.iconSizeXXL(context),
        padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.loadNotifications();
    } catch (e) {}
  }

  Future<void> _checkSubscriptionAccess() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null && user.accountStatus != 'active') {
        final subscriptionProvider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        await subscriptionProvider.loadSubscriptions();

        if (subscriptionProvider.activeSubscriptions.isNotEmpty) {
          final updatedUser = user.copyWith(accountStatus: 'active');
          await authProvider.updateUser(updatedUser);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _progressSubscription?.cancel();
    _statsSubscription?.cancel();
    _streakSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupStreamListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<StreakProvider>(context, listen: false);

      _progressSubscription =
          progressProvider.progressUpdates.listen((progress) {
        if (mounted) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _updateLoadingStates(progressProvider));
            }
          });
        }
      });

      _statsSubscription = progressProvider.overallStatsUpdates.listen((stats) {
        if (mounted) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _updateLoadingStates(progressProvider));
            }
          });
        }
      });

      _authSubscription = authProvider.userChanges.listen((user) {
        if (mounted && user != null && !_isOffline) {
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

  Future<void> _initializeData() async {
    try {
      final streakProvider =
          Provider.of<StreakProvider>(context, listen: false);
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      await Future.wait([
        streakProvider.loadStreak(),
        examProvider.loadMyExamResults(),
        categoryProvider.loadCategories(),
        progressProvider.loadOverallProgress(),
      ]);

      await _loadNotifications();

      _hasInitialData = true;

      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _updateLoadingStates(progressProvider);
        });

        if (!_isOffline) {
          await _refreshDataInBackground();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;

          final progressProvider =
              Provider.of<ProgressProvider>(context, listen: false);
          if (progressProvider.hasLoadedOverall ||
              progressProvider.hasLoadedProgress) {
            _isOffline = true;
          }
        });
      }
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (_isRefreshing) return;
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 30)) {
      return;
    }

    _isRefreshing = true;

    try {
      final streakProvider =
          Provider.of<StreakProvider>(context, listen: false);
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);

      await Future.wait([
        streakProvider.loadStreak(forceRefresh: true),
        examProvider.loadMyExamResults(forceRefresh: true),
        progressProvider.loadOverallProgress(forceRefresh: true),
      ]);

      await _loadNotifications();

      _lastRefreshTime = DateTime.now();

      if (mounted) {
        setState(() => _updateLoadingStates(progressProvider));
      }
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
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final streakProvider =
          Provider.of<StreakProvider>(context, listen: false);
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);

      await Future.wait([
        streakProvider.loadStreak(forceRefresh: true),
        examProvider.loadMyExamResults(forceRefresh: true),
        progressProvider.loadOverallProgress(forceRefresh: true),
      ]);

      await _loadNotifications();

      _lastRefreshTime = DateTime.now();

      if (mounted) {
        setState(() {
          _updateLoadingStates(progressProvider);
          _isOffline = false;
        });
        showTopSnackBar(context, 'Progress refreshed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOffline = true);
        showTopSnackBar(
            context, 'Failed to refresh progress. Using cached data.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
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
        _buildGlassContainer(
          child: Container(
            width: ResponsiveValues.statCircleSize(context),
            height: ResponsiveValues.statCircleSize(context),
            padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResponsiveIcon(
                  icon,
                  size: ResponsiveValues.iconSizeS(context),
                  color: color,
                ),
                ResponsiveSizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        ResponsiveSizedBox(height: AppSpacing.s),
        Text(
          label,
          style: AppTextStyles.labelSmall(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
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
      return _buildGlassContainer(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveValues.spacingXL(context),
            horizontal: ResponsiveValues.spacingL(context),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runSpacing: ResponsiveValues.spacingL(context),
            spacing: ResponsiveValues.spacingL(context),
            children: List.generate(3, (index) => _buildStatShimmer()),
          ),
        ),
      );
    }

    return _buildGlassContainer(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveValues.spacingXL(context),
          horizontal: ResponsiveValues.spacingL(context),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: ResponsiveValues.spacingL(context),
          spacing: ResponsiveValues.spacingL(context),
          children: [
            _buildStatCircle(
              value: streakCount.toString(),
              label: 'Day Streak',
              color: AppColors.telegramBlue,
              icon: Icons.local_fire_department_rounded,
            ),
            _buildStatCircle(
              value: chaptersCompleted.toString(),
              label: 'Chapters',
              color: AppColors.telegramGreen,
              icon: Icons.book_rounded,
            ),
            _buildStatCircle(
              value: '${totalAccuracy.toStringAsFixed(0)}%',
              label: 'Accuracy',
              color: totalAccuracy >= 70
                  ? AppColors.telegramGreen
                  : totalAccuracy >= 40
                      ? AppColors.telegramYellow
                      : AppColors.telegramRed,
              icon: Icons.auto_graph_rounded,
            ),
          ],
        ),
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
      return _buildGlassContainer(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                child: Container(
                  width: ResponsiveValues.spacingXXXL(context) * 4,
                  height: ResponsiveValues.spacingXL(context),
                  color: Colors.white,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ...List.generate(
                2,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: ResponsiveValues.spacingXL(context),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: ResponsiveValues.spacingXXXL(context) * 2,
                              height: ResponsiveValues.spacingL(context),
                              color: Colors.white,
                            ),
                          ),
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: ResponsiveValues.spacingXXXL(context),
                              height: ResponsiveValues.spacingL(context),
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ResponsiveSizedBox(height: AppSpacing.s),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                        highlightColor:
                            Colors.grey[100]!.withValues(alpha: 0.6),
                        child: Container(
                          width: double.infinity,
                          height: ResponsiveValues.spacingS(context),
                          color: Colors.white,
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
          'Progress Overview',
          style: AppTextStyles.titleLarge(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        ResponsiveSizedBox(height: AppSpacing.l),
        _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              children: [
                _buildProgressItem(
                  title: 'Chapter Completion',
                  value: '$chaptersCompleted/$totalChaptersAttempted',
                  percentage: completedPercentage.toDouble(),
                  color: completedPercentage >= 80
                      ? AppColors.telegramGreen
                      : completedPercentage >= 40
                          ? AppColors.telegramBlue
                          : AppColors.telegramYellow,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                _buildProgressItem(
                  title: 'Question Accuracy',
                  value: '${totalAccuracy.toStringAsFixed(1)}% correct',
                  percentage: totalAccuracy.toDouble(),
                  color: totalAccuracy >= 80
                      ? AppColors.telegramGreen
                      : totalAccuracy >= 60
                          ? AppColors.telegramBlue
                          : AppColors.telegramYellow,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Study Time',
                            style: AppTextStyles.titleSmall(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ResponsiveSizedBox(height: AppSpacing.xs),
                          Text(
                            '${studyTimeHours.toStringAsFixed(1)} hours',
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
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                      child: Center(
                        child: ResponsiveIcon(
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
                    style: AppTextStyles.titleSmall(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xxs),
                  Text(
                    value,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.s),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.titleMedium(context).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        ResponsiveSizedBox(height: AppSpacing.s),
        ClipRRect(
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusSmall(context),
          ),
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

  Widget _buildExamPerformanceSection(List examResults, bool isLoading) {
    if (isLoading && !_hasInitialData) {
      return _buildGlassContainer(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                child: Container(
                  width: ResponsiveValues.spacingXXXL(context) * 3,
                  height: ResponsiveValues.spacingXL(context),
                  color: Colors.white,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ...List.generate(
                2,
                (index) => Container(
                  margin: EdgeInsets.only(
                    bottom: ResponsiveValues.spacingM(context),
                  ),
                  height: ResponsiveValues.spacingXXL(context) * 2,
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                    highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                    ),
                  ),
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
        final score = _parseDouble(exam.score);
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
          'Exam Performance',
          style: AppTextStyles.titleLarge(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        ResponsiveSizedBox(height: AppSpacing.l),
        _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              children: [
                if (examResults.isEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        ResponsiveIcon(
                          Icons.quiz_outlined,
                          size: ResponsiveValues.iconSizeXXL(context),
                          color: AppColors.getTextSecondary(context)
                              .withValues(alpha: 0.3),
                        ),
                        ResponsiveSizedBox(height: AppSpacing.m),
                        Text(
                          _isOffline
                              ? 'No cached exam results'
                              : 'No exams taken yet',
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        ResponsiveSizedBox(height: AppSpacing.xs),
                        Text(
                          _isOffline
                              ? 'Connect to view exam results'
                              : 'Take your first exam to see results here',
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
                        title: 'Total',
                        value: '${examResults.length}',
                        color: AppColors.telegramBlue,
                        icon: Icons.assignment_rounded,
                      ),
                      _buildExamStat(
                        title: 'Passed',
                        value: '$passedCount',
                        color: AppColors.telegramGreen,
                        icon: Icons.check_circle_rounded,
                      ),
                      _buildExamStat(
                        title: 'Avg Score',
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
                  ResponsiveSizedBox(height: AppSpacing.xl),
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
                          '+ ${examResults.length - 3} more exams',
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
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusSmall(context),
              ),
            ),
            child: Center(
              child: ResponsiveIcon(
                icon,
                size: ResponsiveValues.iconSizeS(context),
                color: color,
              ),
            ),
          ),
          ResponsiveSizedBox(height: AppSpacing.s),
          Text(
            value,
            style: AppTextStyles.titleSmall(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.labelSmall(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamResultCard(dynamic exam) {
    final score = _parseDouble(exam.score) ?? 0.0;
    final title = exam.title?.toString() ?? 'Exam';
    final courseName = exam.courseName?.toString() ?? 'General';
    final passed = exam.passed == true;
    final examType = (exam.examType?.toString() ?? 'GENERAL').toUpperCase();

    return _buildGlassContainer(
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
                          AppColors.telegramGreen.withValues(alpha: 0.1)
                        ]
                      : [
                          AppColors.telegramRed.withValues(alpha: 0.2),
                          AppColors.telegramRed.withValues(alpha: 0.1)
                        ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusSmall(context),
                ),
              ),
              child: Center(
                child: ResponsiveIcon(
                  passed ? Icons.check_rounded : Icons.close_rounded,
                  size: ResponsiveValues.iconSizeS(context),
                  color:
                      passed ? AppColors.telegramGreen : AppColors.telegramRed,
                ),
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xs),
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
                                    AppColors.telegramGreen
                                        .withValues(alpha: 0.2),
                                    AppColors.telegramGreen
                                        .withValues(alpha: 0.1)
                                  ]
                                : [
                                    AppColors.telegramRed
                                        .withValues(alpha: 0.2),
                                    AppColors.telegramRed.withValues(alpha: 0.1)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: Text(
                          passed ? 'PASSED' : 'FAILED',
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
            ResponsiveSizedBox(width: AppSpacing.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.toStringAsFixed(1)}%',
                  style: AppTextStyles.titleSmall(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  examType,
                  style: AppTextStyles.labelSmall(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
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
      return _buildGlassContainer(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                child: Container(
                  width: ResponsiveValues.spacingXXXL(context) * 3,
                  height: ResponsiveValues.spacingXL(context),
                  color: Colors.white,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
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
                itemBuilder: (context, index) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: AppTextStyles.titleLarge(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        ResponsiveSizedBox(height: AppSpacing.l),
        _buildGlassContainer(
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
                  title: achievement.title ?? 'Achievement',
                  description: achievement.description ?? '',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.telegramYellow,
                  unlocked: true,
                  earnedDate: achievement.earnedAt,
                );
              },
            ),
          ),
        ),
        if (achievements.length > 6)
          Padding(
            padding: EdgeInsets.only(
              top: ResponsiveValues.spacingS(context),
            ),
            child: Center(
              child: Text(
                '+ ${achievements.length - 6} more achievements',
                style: AppTextStyles.labelSmall(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline) {
      _refreshDataInBackground();
    }
  }

  Widget _buildMobileLayout() {
    return Consumer5<AuthProvider, StreakProvider, ExamProvider,
        ProgressProvider, CategoryProvider>(
      builder: (context, authProvider, streakProvider, examProvider,
          progressProvider, categoryProvider, child) {
        final stats =
            progressProvider.overallStats['stats'] as Map<String, dynamic>? ??
                {};
        final chaptersCompleted = _parseInt(stats['chapters_completed']) ?? 0;
        final totalChaptersAttempted =
            _parseInt(stats['total_chapters_attempted']) ?? 0;
        final totalAccuracy = _parseDouble(stats['accuracy_percentage']) ?? 0.0;
        final studyTimeHours = _parseDouble(stats['study_time_hours']) ?? 0.0;
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
            appBar: CustomAppBar(
              title: 'Progress',
              subtitle: 'Offline Mode',
            ),
            body: Center(
              child: OfflineState(
                dataType: 'progress',
                message: 'You are offline. Connect to view your progress.',
                onRetry: () {
                  setState(() => _isOffline = false);
                  _checkConnectivity();
                  _manualRefresh();
                },
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
                    title: 'Progress',
                    subtitle: _isOffline
                        ? 'Offline mode - showing cached data'
                        : (_isRefreshing && !_isInitialLoad
                            ? 'Refreshing...'
                            : 'Track your learning journey'),
                  ),
                ),
                SliverPadding(
                  padding:
                      EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatsSection(
                        streakCount: streakCount,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        isLoading: progressProvider.isLoadingOverall &&
                            !_hasInitialData,
                      ),
                      ResponsiveSizedBox(height: AppSpacing.xl),
                      _buildOverviewSection(
                        totalChaptersAttempted: totalChaptersAttempted,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        studyTimeHours: studyTimeHours,
                        isLoading: progressProvider.isLoadingOverall &&
                            !_hasInitialData,
                      ),
                      ResponsiveSizedBox(height: AppSpacing.xl),
                      _buildExamPerformanceSection(
                        examResults,
                        progressProvider.isLoadingOverall && !_hasInitialData,
                      ),
                      ResponsiveSizedBox(height: AppSpacing.xl),
                      if (achievements.isNotEmpty)
                        _buildAchievementsSection(
                          achievements,
                          progressProvider.isLoadingOverall && !_hasInitialData,
                        ),
                      ResponsiveSizedBox(height: AppSpacing.xxl),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
