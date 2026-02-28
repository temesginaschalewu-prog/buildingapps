import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/helpers.dart';
import '../../widgets/progress/streak_widget.dart';
import '../../widgets/progress/achievement_badge.dart';
import '../../widgets/progress/progress_chart.dart';

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
  int _unreadNotifications = 0;
  bool _isInitialLoad = true;
  bool _hasInitialData = false;
  DateTime? _lastRefreshTime;

  // Track which sections are loading
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
      _initializeData();
      _setupStreamListeners();
      _checkSubscriptionAccess();
    });

    // Set up background refresh every 5 minutes
    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && !_isRefreshing) {
        _refreshDataInBackground();
      }
    });
  }

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStatShimmer() {
    return _buildGlassContainer(
      context,
      child: Container(
        width: 80,
        height: 80,
        padding: const EdgeInsets.all(8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withOpacity(0.3),
          highlightColor: Colors.grey[100]!.withOpacity(0.6),
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
      await notificationProvider.loadNotifications(forceRefresh: false);
      if (mounted) {
        setState(() => _unreadNotifications = notificationProvider.unreadCount);
      }
    } catch (e) {}
  }

  Future<void> _checkSubscriptionAccess() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null && user.accountStatus != 'active') {
        final subscriptionProvider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        await subscriptionProvider.loadSubscriptions(forceRefresh: false);

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
      final streakProvider =
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
        if (mounted && user != null) {
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

      // Load data in parallel
      await Future.wait([
        streakProvider.loadStreak(forceRefresh: false),
        examProvider.loadMyExamResults(forceRefresh: false),
        categoryProvider.loadCategories(forceRefresh: false),
        progressProvider.loadOverallProgress(forceRefresh: false),
      ]);

      await _loadNotifications();

      _hasInitialData = true;

      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _updateLoadingStates(progressProvider);
        });

        // Trigger a background refresh after initial load
        _refreshDataInBackground();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _refreshDataInBackground() async {
    // Prevent multiple refreshes in quick succession
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
      // Silently fail in background
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

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
        setState(() => _updateLoadingStates(progressProvider));
        showTopSnackBar(context, 'Progress refreshed');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Failed to refresh progress', isError: true);
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
          context,
          child: Container(
            width: ScreenSize.responsiveValue(
                context: context, mobile: 60, tablet: 70, desktop: 80),
            height: ScreenSize.responsiveValue(
                context: context, mobile: 60, tablet: 70, desktop: 80),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: ScreenSize.responsiveIconSize(
                      context: context, mobile: 20, tablet: 22, desktop: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
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
        context,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) => _buildStatShimmer()),
          ),
        ),
      );
    }

    return _buildGlassContainer(
      context,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
        context,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withOpacity(0.3),
                highlightColor: Colors.grey[100]!.withOpacity(0.6),
                child: Container(
                  width: 150,
                  height: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                2,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withOpacity(0.3),
                            highlightColor: Colors.grey[100]!.withOpacity(0.6),
                            child: Container(
                              width: 100,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withOpacity(0.3),
                            highlightColor: Colors.grey[100]!.withOpacity(0.6),
                            child: Container(
                              width: 50,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withOpacity(0.3),
                        highlightColor: Colors.grey[100]!.withOpacity(0.6),
                        child: Container(
                          width: double.infinity,
                          height: 6,
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
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          context,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Study Time',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${studyTimeHours.toStringAsFixed(1)} hours',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.purpleGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.timer_rounded,
                          color: Colors.white,
                          size: 24,
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
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.titleMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.getSurface(context).withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildExamPerformanceSection(List examResults, bool isLoading) {
    if (isLoading && !_hasInitialData) {
      return _buildGlassContainer(
        context,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withOpacity(0.3),
                highlightColor: Colors.grey[100]!.withOpacity(0.6),
                child: Container(
                  width: 150,
                  height: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                2,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 60,
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withOpacity(0.3),
                    highlightColor: Colors.grey[100]!.withOpacity(0.6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          context,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (examResults.isEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 48,
                          color: AppColors.getTextSecondary(context)
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No exams taken yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Take your first exam to see results here',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.getTextSecondary(context)
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  const SizedBox(height: 20),
                  ...List.generate(
                    examResults.length > 3 ? 3 : examResults.length,
                    (index) {
                      final exam = examResults[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < (examResults.length - 1) ? 12 : 0,
                        ),
                        child: _buildExamResultCard(exam),
                      );
                    },
                  ),
                  if (examResults.length > 3)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+ ${examResults.length - 3} more exams',
                          style: AppTextStyles.bodySmall.copyWith(
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
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
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
      context,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: passed
                      ? [
                          AppColors.telegramGreen.withOpacity(0.2),
                          AppColors.telegramGreen.withOpacity(0.1)
                        ]
                      : [
                          AppColors.telegramRed.withOpacity(0.2),
                          AppColors.telegramRed.withOpacity(0.1)
                        ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  passed ? Icons.check_rounded : Icons.close_rounded,
                  color:
                      passed ? AppColors.telegramGreen : AppColors.telegramRed,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          courseName,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: passed
                                ? [
                                    AppColors.telegramGreen.withOpacity(0.2),
                                    AppColors.telegramGreen.withOpacity(0.1)
                                  ]
                                : [
                                    AppColors.telegramRed.withOpacity(0.2),
                                    AppColors.telegramRed.withOpacity(0.1)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          passed ? 'PASSED' : 'FAILED',
                          style: AppTextStyles.labelSmall.copyWith(
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.toStringAsFixed(1)}%',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                Text(
                  examType,
                  style: AppTextStyles.labelSmall.copyWith(
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
        context,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withOpacity(0.3),
                highlightColor: Colors.grey[100]!.withOpacity(0.6),
                child: Container(
                  width: 150,
                  height: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: 6,
                itemBuilder: (context, index) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withOpacity(0.3),
                  highlightColor: Colors.grey[100]!.withOpacity(0.6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassContainer(
          context,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '+ ${achievements.length - 6} more achievements',
                style: AppTextStyles.labelSmall.copyWith(
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
    if (state == AppLifecycleState.resumed) {
      _refreshDataInBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                    subtitle: _isRefreshing && !_isInitialLoad
                        ? 'Refreshing...'
                        : 'Track your learning journey',
                    showThemeToggle: true,
                    showNotification: true,
                    showRefresh: true,
                    isLoading: _isRefreshing,
                    onRefresh: _manualRefresh,
                    useSliver: false,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(
                    ScreenSize.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 24,
                      desktop: 32,
                    ),
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
                      const SizedBox(height: 24),
                      _buildOverviewSection(
                        totalChaptersAttempted: totalChaptersAttempted,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        studyTimeHours: studyTimeHours,
                        isLoading: progressProvider.isLoadingOverall &&
                            !_hasInitialData,
                      ),
                      const SizedBox(height: 24),
                      _buildExamPerformanceSection(
                        examResults,
                        progressProvider.isLoadingOverall && !_hasInitialData,
                      ),
                      const SizedBox(height: 24),
                      if (achievements.isNotEmpty)
                        _buildAchievementsSection(
                          achievements,
                          progressProvider.isLoadingOverall && !_hasInitialData,
                        ),
                      const SizedBox(height: 32),
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
}
