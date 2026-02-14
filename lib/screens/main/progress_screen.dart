import 'dart:async';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:badges/badges.dart' as badges;
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/helpers.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  StreamSubscription? _progressSubscription;
  StreamSubscription? _statsSubscription;
  StreamSubscription? _authSubscription;
  int _unreadNotifications = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _setupStreamListeners();
    _setupAutoRefresh();
    _checkSubscriptionAccess();
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

          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugLog('ProgressScreen', 'Error checking subscription access: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _progressSubscription?.cancel();
    _statsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupStreamListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      _progressSubscription =
          progressProvider.progressUpdates.listen((progress) {
        if (mounted) {
          setState(() {});
        }
      });

      _statsSubscription = progressProvider.overallStatsUpdates.listen((stats) {
        if (mounted) {
          setState(() {});
        }
      });

      _authSubscription = authProvider.userChanges.listen((user) {
        if (mounted && user != null) {
          _initializeData();
        }
      });
    });
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isRefreshing) {
        _refreshData(silent: true);
      }
    });
  }

  Future<void> _initializeData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final streakProvider =
          Provider.of<StreakProvider>(context, listen: false);
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Load cached data first
      await Future.wait([
        streakProvider.loadStreak(forceRefresh: false),
        examProvider.loadMyExamResults(forceRefresh: false),
        categoryProvider.loadCategories(),
      ]);

      // Try to refresh in background if needed
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshData(silent: true);
        });
      }

      debugLog('ProgressScreen', '✅ All data initialized');
    } catch (e) {
      debugLog('ProgressScreen', '❌ Error initializing data: $e');
    }
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (_isRefreshing) return;

    if (!silent && mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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

      if (!silent) {
        showSnackBar(context, 'Progress refreshed', isError: false);
      }
    } catch (e) {
      debugLog('ProgressScreen', '❌ Refresh error: $e');
      if (!silent) {
        showSnackBar(context, 'Failed to refresh progress', isError: true);
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Widget _buildProgressContent() {
    return Consumer5<AuthProvider, StreakProvider, ExamProvider,
        ProgressProvider, CategoryProvider>(
      builder: (context, authProvider, streakProvider, examProvider,
          progressProvider, categoryProvider, child) {
        // Always show cached data first
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

        if (progressProvider.isLoadingOverall && _userProgress.isEmpty) {
          return _buildLoadingSkeleton();
        }

        return RefreshIndicator(
          onRefresh: () => _refreshData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Section
                Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 24,
                      desktop: 32,
                    ),
                    right: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 24,
                      desktop: 32,
                    ),
                  ),
                  child: _buildStatsSection(
                    streakCount: streakCount,
                    chaptersCompleted: chaptersCompleted,
                    totalAccuracy: totalAccuracy,
                  ),
                ),

                // Main Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 24,
                      desktop: 32,
                    ),
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewSection(
                        totalChaptersAttempted: totalChaptersAttempted,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                        studyTimeHours: studyTimeHours,
                      ),
                      const SizedBox(height: 24),
                      _buildExamPerformanceSection(examResults),
                      const SizedBox(height: 24),
                      _buildNextStepsSection(
                        hasStudied: totalChaptersAttempted > 0,
                        hasExamResults: examResults.isNotEmpty,
                        streakCount: streakCount,
                        chaptersCompleted: chaptersCompleted,
                        totalAccuracy: totalAccuracy,
                      ),
                      const SizedBox(height: 32),
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

  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      height: ScreenSize.responsiveValue(
        context: context,
        mobile: 160,
        tablet: 180,
        desktop: 200,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.telegramBlue,
            AppColors.telegramBlue.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 24,
              desktop: 32,
            ),
            right: ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 24,
              desktop: 32,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      _buildIconButton(
                        icon: Icons.dark_mode_outlined,
                        color: Colors.white,
                        onTap: () {
                          Provider.of<ThemeProvider>(context, listen: false)
                              .toggleTheme();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildNotificationButton(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Track your learning journey',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const Spacer(),
              // User info or progress summary
              _buildHeaderInfo(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final username = user?.username?.split(' ').first ?? 'Student';

        return Row(
          children: [
            CircleAvatar(
              radius: ScreenSize.responsiveValue(
                context: context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                username.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ScreenSize.responsiveFontSize(
                    context: context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $username!',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Keep up the great work!',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (_isRefreshing)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ScreenSize.responsiveValue(
          context: context,
          mobile: 40,
          tablet: 44,
          desktop: 48,
        ),
        height: ScreenSize.responsiveValue(
          context: context,
          mobile: 40,
          tablet: 44,
          desktop: 48,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: ScreenSize.responsiveIconSize(
              context: context,
              mobile: 20,
              tablet: 22,
              desktop: 24,
            ),
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        // Navigate to notifications
      },
      child: Container(
        width: ScreenSize.responsiveValue(
          context: context,
          mobile: 40,
          tablet: 44,
          desktop: 48,
        ),
        height: ScreenSize.responsiveValue(
          context: context,
          mobile: 40,
          tablet: 44,
          desktop: 48,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _unreadNotifications > 0
              ? badges.Badge(
                  position: badges.BadgePosition.topEnd(top: -2, end: -2),
                  badgeContent: Text(
                    _unreadNotifications > 9
                        ? '9+'
                        : _unreadNotifications.toString(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.telegramRed,
                    padding: const EdgeInsets.all(3),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: ScreenSize.responsiveIconSize(
                      context: context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.notifications_outlined,
                  size: ScreenSize.responsiveIconSize(
                    context: context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildStatsSection({
    required int streakCount,
    required int chaptersCompleted,
    required double totalAccuracy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
            color: AppColors.telegramYellow,
            icon: Icons.auto_graph_rounded,
          ),
        ],
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
        Container(
          width: ScreenSize.responsiveValue(
            context: context,
            mobile: 60,
            tablet: 70,
            desktop: 80,
          ),
          height: ScreenSize.responsiveValue(
            context: context,
            mobile: 60,
            tablet: 70,
            desktop: 80,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: ScreenSize.responsiveIconSize(
                    context: context,
                    mobile: 24,
                    tablet: 26,
                    desktop: 28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.titleLarge.copyWith(
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

  Widget _buildOverviewSection({
    required int totalChaptersAttempted,
    required int chaptersCompleted,
    required double totalAccuracy,
    required double studyTimeHours,
  }) {
    final completedPercentage = totalChaptersAttempted > 0
        ? (chaptersCompleted / totalChaptersAttempted * 100.0).clamp(0, 100)
        : 0.0;

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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressItem(
                  title: 'Chapter Completion',
                  value: '$chaptersCompleted/$totalChaptersAttempted',
                  percentage: completedPercentage.toDouble(),
                  color: _getProgressColor(completedPercentage.toDouble()),
                ),
                const SizedBox(height: 20),
                _buildProgressItem(
                  title: 'Question Accuracy',
                  value: '${totalAccuracy.toStringAsFixed(1)}% correct',
                  percentage: totalAccuracy,
                  color: _getAccuracyColor(totalAccuracy),
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
              style: AppTextStyles.titleLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusSmall),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.getSurface(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildExamPerformanceSection(List examResults) {
    final hasExamResults = examResults.isNotEmpty;
    final averageScore = _calculateAverageScore(examResults);
    final passedExams = examResults.where((e) => e.passed == true).length;

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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasExamResults) _buildNoExams(),
                if (hasExamResults) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildExamStat(
                        title: 'Total Exams',
                        value: '${examResults.length}',
                        color: AppColors.telegramBlue,
                        icon: Icons.assignment_rounded,
                      ),
                      _buildExamStat(
                        title: 'Passed',
                        value: '$passedExams',
                        color: AppColors.telegramGreen,
                        icon: Icons.check_circle_rounded,
                      ),
                      _buildExamStat(
                        title: 'Avg Score',
                        value: '${averageScore.toStringAsFixed(1)}%',
                        color: AppColors.telegramYellow,
                        icon: Icons.score_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(
                    examResults.length < 3 ? examResults.length : 3,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index < (examResults.length - 1) ? 12 : 0,
                      ),
                      child: _buildExamResultCard(examResults[index]),
                    ),
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

  Widget _buildNoExams() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: AppColors.getTextSecondary(context).withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No exams taken yet',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take your first exam to see results here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
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

    return Container(
      decoration: BoxDecoration(
        color: passed
            ? AppColors.telegramGreen.withOpacity(0.05)
            : AppColors.telegramRed.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: passed
              ? AppColors.telegramGreen.withOpacity(0.1)
              : AppColors.telegramRed.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: passed
                    ? AppColors.telegramGreen.withOpacity(0.1)
                    : AppColors.telegramRed.withOpacity(0.1),
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
                          color: passed
                              ? AppColors.telegramGreen.withOpacity(0.1)
                              : AppColors.telegramRed.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
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
            const SizedBox(width: 12),
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

  Widget _buildNextStepsSection({
    required bool hasStudied,
    required bool hasExamResults,
    required int streakCount,
    required int chaptersCompleted,
    required double totalAccuracy,
  }) {
    final nextSteps = <Map<String, dynamic>>[];

    if (!hasStudied) {
      nextSteps.add({
        'title': 'Start Your First Lesson',
        'description': 'Complete a chapter to begin tracking progress',
        'icon': Icons.play_arrow_rounded,
        'color': AppColors.telegramBlue,
      });
    }

    if (!hasExamResults) {
      nextSteps.add({
        'title': 'Take Your First Exam',
        'description': 'Test your knowledge with practice exams',
        'icon': Icons.quiz_rounded,
        'color': AppColors.telegramGreen,
      });
    }

    if (streakCount < 7) {
      nextSteps.add({
        'title': 'Build a 7-Day Streak',
        'description': 'Study every day for 7 consecutive days',
        'icon': Icons.local_fire_department_rounded,
        'color': AppColors.telegramYellow,
        'progress': (streakCount / 7).toDouble(),
      });
    }

    if (chaptersCompleted < 5) {
      nextSteps.add({
        'title': 'Complete 5 Chapters',
        'description': 'Master your subjects chapter by chapter',
        'icon': Icons.book_rounded,
        'color': AppColors.telegramBlue,
        'progress': (chaptersCompleted / 5).toDouble(),
      });
    }

    if (totalAccuracy < 80 && hasStudied) {
      nextSteps.add({
        'title': 'Improve Accuracy',
        'description': 'Aim for 80%+ accuracy on practice questions',
        'icon': Icons.trending_up_rounded,
        'color': AppColors.telegramGreen,
        'progress': totalAccuracy / 100,
      });
    }

    if (nextSteps.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.telegramBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          border: Border.all(
            color: AppColors.telegramBlue.withOpacity(0.1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: 64,
                color: AppColors.telegramBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'Amazing Progress!',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re doing fantastic! Keep up the excellent work.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text('🔥 ${streakCount} Day Streak'),
                    backgroundColor: AppColors.telegramBlue.withOpacity(0.1),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  Chip(
                    label: Text('📚 $chaptersCompleted Chapters'),
                    backgroundColor: AppColors.telegramGreen.withOpacity(0.1),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  Chip(
                    label: Text(
                        '🎯 ${totalAccuracy.toStringAsFixed(1)}% Accuracy'),
                    backgroundColor: AppColors.telegramYellow.withOpacity(0.1),
                    labelStyle: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
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
          'Next Steps',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: nextSteps.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final step = nextSteps[index];
            return _buildNextStepCard(
              step['title'],
              step['description'],
              step['icon'],
              step['color'],
              step['progress'] as double?,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNextStepCard(
    String title,
    String description,
    IconData icon,
    Color color,
    double? progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.getSurface(context),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header skeleton
          Container(
            width: double.infinity,
            height: 160,
            color: AppColors.telegramBlue.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: AppColors.getSurface(context),
                    highlightColor: AppColors.getBackground(context),
                    child: Container(
                      height: 28,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Shimmer.fromColors(
                    baseColor: AppColors.getSurface(context),
                    highlightColor: AppColors.getBackground(context),
                    child: Container(
                      height: 16,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: AppColors.getSurface(context),
                  highlightColor: AppColors.getBackground(context),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Shimmer.fromColors(
                  baseColor: AppColors.getSurface(context),
                  highlightColor: AppColors.getBackground(context),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Shimmer.fromColors(
                  baseColor: AppColors.getSurface(context),
                  highlightColor: AppColors.getBackground(context),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) return AppColors.telegramGreen;
    if (percentage >= 60) return AppColors.telegramBlue;
    return AppColors.telegramYellow;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) return AppColors.telegramGreen;
    if (accuracy >= 60) return AppColors.telegramYellow;
    return AppColors.telegramRed;
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

  double _calculateAverageScore(List exams) {
    if (exams.isEmpty) return 0.0;

    double totalScore = 0;
    int validExams = 0;

    for (var exam in exams) {
      try {
        final score = _parseDouble(exam.score);
        if (score != null) {
          totalScore += score;
          validExams++;
        }
      } catch (e) {
        debugLog('ProgressScreen', 'Error parsing exam score: $e');
      }
    }

    return validExams > 0 ? (totalScore / validExams) : 0.0;
  }

  List<UserProgress> get _userProgress {
    final progressProvider =
        Provider.of<ProgressProvider>(context, listen: false);
    return progressProvider.userProgress;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: AppColors.getBackground(context),
              foregroundColor: AppColors.getTextPrimary(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 100.0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.telegramBlue.withOpacity(0.05),
                        AppColors.getBackground(context),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: AppThemes.spacingL,
                    right: AppThemes.spacingL,
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: AppThemes.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppThemes.spacingXS),
                              Text(
                                'Track your learning journey',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildThemeToggleButton(),
                              const SizedBox(width: AppThemes.spacingS),
                              _buildNotificationButton(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _buildProgressContent(),
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: () {
            themeProvider.toggleTheme();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 22,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
