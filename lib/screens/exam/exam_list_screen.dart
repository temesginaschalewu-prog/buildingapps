import 'dart:async';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/error_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/exam/exam_card.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../services/device_service.dart';

class ExamListScreen extends StatefulWidget {
  final int? courseId;
  final bool forceRefresh;

  const ExamListScreen({
    super.key,
    this.courseId,
    this.forceRefresh = false,
  });

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  late StreamSubscription<Map<int, bool>> _subscriptionListener;
  late StreamSubscription<List<Exam>> _examsListener;
  late StreamSubscription<List<Payment>> _paymentsListener;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;
  bool _isOnline = true;
  List<Exam> _cachedExams = [];

  @override
  void initState() {
    super.initState();
    _initData();
    _setupListeners();
  }

  @override
  void dispose() {
    _subscriptionListener.cancel();
    _examsListener.cancel();
    _paymentsListener.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    if (!mounted) return;

    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);

    try {
      final cachedExams = await _loadCachedExams();
      if (cachedExams.isNotEmpty) {
        setState(() {
          _cachedExams = cachedExams;
        });
      }

      if (widget.forceRefresh) {
        examProvider.clearExamsForCourse(widget.courseId ?? 0);
      }

      if (widget.courseId != null) {
        await examProvider.loadExamsByCourse(widget.courseId!,
            forceRefresh: widget.forceRefresh);
      } else {
        await examProvider.loadAvailableExams(
            forceRefresh: widget.forceRefresh);
      }

      final exams = widget.courseId != null
          ? examProvider.getExamsByCourse(widget.courseId!)
          : examProvider.availableExams;

      if (exams.isNotEmpty) {
        final categoryIds =
            exams.map((e) => e.categoryId).where((id) => id != null).toSet();
        await subscriptionProvider
            .preCheckActiveCategories(categoryIds.toList());

        await paymentProvider.loadPayments(forceRefresh: widget.forceRefresh);
        await _updatePendingPaymentStatus(paymentProvider, examProvider);

        await _cacheExams(exams);
      }
    } catch (e) {
      debugLog('ExamListScreen', 'Init data error: $e');
    }
  }

  Future<void> _updatePendingPaymentStatus(
    PaymentProvider paymentProvider,
    ExamProvider examProvider,
  ) async {
    final pendingPayments = paymentProvider.getPendingPayments();
    final pendingByCategory = <int, bool>{};

    for (final payment in pendingPayments) {
      if (payment.categoryId != null) {
        pendingByCategory[payment.categoryId!] = true;
      }
    }

    if (pendingByCategory.isNotEmpty) {
      await examProvider.updatePendingPayments(pendingByCategory);
    }
  }

  Future<List<Exam>> _loadCachedExams() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cacheKey = widget.courseId != null
          ? 'cached_exams_course_${widget.courseId}'
          : 'cached_exams_all';

      final cached = await deviceService.getCacheItem<List<Exam>>(cacheKey);
      return cached ?? [];
    } catch (e) {
      debugLog('ExamListScreen', 'Load cached error: $e');
      return [];
    }
  }

  Future<void> _cacheExams(List<Exam> exams) async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cacheKey = widget.courseId != null
          ? 'cached_exams_course_${widget.courseId}'
          : 'cached_exams_all';

      await deviceService.saveCacheItem(cacheKey, exams,
          ttl: const Duration(hours: 24), isUserSpecific: true);

      setState(() {
        _cachedExams = exams;
      });
    } catch (e) {
      debugLog('ExamListScreen', 'Cache exams error: $e');
    }
  }

  void _setupListeners() {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    _subscriptionListener =
        subscriptionProvider.subscriptionUpdates.listen((statusMap) {
      if (mounted) {
        setState(() {
          debugLog('ExamListScreen', 'Subscription status updated: $statusMap');
        });
      }
    });

    _paymentsListener = paymentProvider.paymentsUpdates.listen((payments) {
      if (mounted) {
        debugLog(
            'ExamListScreen', 'Payments updated: ${payments.length} payments');
        _updatePendingPaymentStatus(paymentProvider, examProvider);
      }
    });

    _examsListener = examProvider.examsUpdates.listen((exams) {
      if (mounted) {
        setState(() {
          debugLog('ExamListScreen', 'Exams updated: ${exams.length} exams');
        });
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    if (mounted) setState(() {});

    try {
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final paymentProvider =
          Provider.of<PaymentProvider>(context, listen: false);

      if (widget.courseId != null) {
        await examProvider.loadExamsByCourse(widget.courseId!,
            forceRefresh: true);
      } else {
        await examProvider.loadAvailableExams(forceRefresh: true);
      }

      await subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await paymentProvider.loadPayments(forceRefresh: true);
      await examProvider.loadMyExamResults(forceRefresh: true);

      await _updatePendingPaymentStatus(paymentProvider, examProvider);

      debugLog('ExamListScreen', '✅ Data refreshed successfully');
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorizedError();
      } else {
        showSimpleSnackBar(context, e.userFriendlyMessage, isError: true);
      }
    } catch (e) {
      debugLog('ExamListScreen', 'Refresh error: $e');
      showSimpleSnackBar(context, 'Failed to refresh exams. Please try again.',
          isError: true);
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  void _handleUnauthorizedError() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.logout();
      if (mounted) {
        GoRouter.of(context).go('/auth/login');
      }
    });
  }

  void _handleExamTap(BuildContext context, Exam exam) async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      showSimpleSnackBar(context, 'Please login to take exams', isError: true);
      GoRouter.of(context).go('/auth/login');
      return;
    }

    if (exam.requiresPayment) {
      try {
        final hasAccess = await subscriptionProvider
            .checkHasActiveSubscriptionForCategory(exam.categoryId);

        final hasPendingPayment = paymentProvider.payments.any(
          (payment) =>
              payment.status == 'pending' &&
              payment.categoryId == exam.categoryId,
        );

        if (!hasAccess && hasPendingPayment) {
          _showPendingPaymentDialog(context, exam);
          return;
        }

        if (!hasAccess) {
          _showPaymentDialog(context, exam);
          return;
        }
      } catch (e) {
        debugLog('ExamListScreen', 'Subscription check error: $e');
        showSimpleSnackBar(
            context, 'Unable to verify access. Please try again.',
            isError: true);
        return;
      }
    }

    if (exam.canTakeExam) {
      GoRouter.of(context).push(
        '/exam/${exam.id}',
        extra: exam,
      );
    } else if (exam.isEnded) {
      showSimpleSnackBar(context, 'This exam has ended', isError: true);
    } else if (exam.isUpcoming) {
      showSimpleSnackBar(context, 'This exam will start soon', isError: false);
    } else if (exam.maxAttemptsReached) {
      showSimpleSnackBar(context, 'Maximum attempts reached for this exam',
          isError: true);
    } else if (exam.isInProgress) {
      showSimpleSnackBar(context, 'You have an exam in progress',
          isError: false);
    } else {
      showSimpleSnackBar(context, exam.message, isError: true);
    }
  }

  void _showPendingPaymentDialog(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: AppColors.statusPending,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Payment Pending',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'You have a pending payment for "${exam.categoryName}". '
                'Please wait for admin verification (1-3 working days).',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                  ),
                  child: Text('OK', style: AppTextStyles.buttonMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Required',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You need to purchase "${exam.categoryName}" to access this exam.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => GoRouter.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      GoRouter.of(context).pop();
                      GoRouter.of(context).push('/payment', extra: {
                        'category': exam.categoryName,
                        'categoryId': exam.categoryId,
                        'paymentType': 'first_time',
                        'context': 'exam',
                        'examId': exam.id,
                        'examTitle': exam.title,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.telegramBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                    ),
                    child: Text(
                      'Purchase',
                      style: AppTextStyles.buttonMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            widget.courseId != null ? 'Course Exams' : 'Exams',
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: AccessErrorWidget(
          message: 'Please login to view exams',
          onAction: () => GoRouter.of(context).go('/auth/login'),
          fullScreen: true,
        ),
      );
    }

    final exams = widget.courseId != null
        ? (examProvider.isLoading && _cachedExams.isNotEmpty
            ? _cachedExams
            : examProvider.getExamsByCourse(widget.courseId!))
        : (examProvider.isLoading && _cachedExams.isNotEmpty
            ? _cachedExams
            : examProvider.availableExams);

    debugLog('ExamListScreen',
        'Building with ${exams.length} exams (cached: ${_cachedExams.isNotEmpty})');

    final sortedExams = List<Exam>.from(exams)
      ..sort((a, b) {
        if (a.canTakeExam && !b.canTakeExam) return -1;
        if (!a.canTakeExam && b.canTakeExam) return 1;
        return b.startDate.compareTo(a.startDate);
      });

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          widget.courseId != null ? 'Course Exams' : 'Exams',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context)),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        actions: [
          if (subscriptionProvider.isLoading || _isRefreshing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.telegramBlue,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: AppColors.getTextSecondary(context)),
              onPressed: _isRefreshing ? null : _refreshData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildBody(context, examProvider, sortedExams),
    );
  }

  Widget _buildBody(
      BuildContext context, ExamProvider examProvider, List<Exam> exams) {
    final showCacheIndicator =
        examProvider.isLoading && _cachedExams.isNotEmpty;

    if (examProvider.isLoading && exams.isEmpty && _cachedExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.telegramBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading exams...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (exams.isEmpty) {
      return RefreshIndicator(
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getBackground(context),
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/no_exams.png',
                    width: 150,
                    height: 150,
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Exams Available',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.courseId != null
                        ? 'There are no exams for this course yet.'
                        : 'No exams are available at the moment.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refreshData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.telegramBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                    ),
                    child: Text(
                      'Refresh',
                      style: AppTextStyles.buttonMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: _refreshKey,
      onRefresh: _refreshData,
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getBackground(context),
      displacement: ScreenSize.responsiveValue(
        context: context,
        mobile: 40,
        tablet: 60,
        desktop: 80,
      ),
      notificationPredicate: (notification) {
        return notification.depth == 0;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showCacheIndicator)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  border: Border.all(
                    color: AppColors.telegramBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_download_rounded,
                      color: AppColors.telegramBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing cached exams. Refreshing...',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.telegramBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
              vertical: AppThemes.spacingL,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exam = exams[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: AppThemes.spacingL,
                    ),
                    child: ExamCard(
                      exam: exam,
                      onTap: () => _handleExamTap(context, exam),
                    )
                        .animate(
                          delay: Duration(milliseconds: 30 * index),
                        )
                        .slideX(
                          begin: 0.1,
                          end: 0,
                          duration: AppThemes.animationDurationMedium,
                          curve: Curves.easeOut,
                        )
                        .fadeIn(duration: AppThemes.animationDurationMedium),
                  );
                },
                childCount: exams.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
