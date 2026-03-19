// lib/screens/course/course_detail_screen.dart
// COMPLETE PRODUCTION-READY FILE - FIXED PENDING COUNT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/course_model.dart';
import '../../models/payment_model.dart';
import '../../models/category_model.dart';
import '../../models/chapter_model.dart';
import '../../models/exam_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../services/device_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/common/access_banner.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_bar.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  final Course? course;
  final Category? category;
  final bool? hasAccess;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.course,
    this.category,
    this.hasAccess,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _refreshController = RefreshController();

  Course? _course;
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  String? _rejectionReason;

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  bool _isLoading = true;
  int _pendingCount = 0;

  bool _chaptersLoaded = false;
  bool _examsLoaded = false;
  bool _chaptersLoading = false;
  bool _examsLoading = false;

  StreamSubscription? _subscriptionListener;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    _subscriptionListener?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      unawaited(_loadChapters());
      unawaited(_loadExams());
      if (!_isOffline) {
        unawaited(_refreshInBackground());
      }
    } else {
      await _loadFreshData();
    }
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          final queueManager = context.read<OfflineQueueManager>();
          _pendingCount = queueManager.pendingCount;
        });
        if (isOnline && !_isRefreshing && _course != null) {
          unawaited(_refreshInBackground());
        }
      }
    });
  }

  void _setupListeners() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    _subscriptionListener?.cancel();
    _subscriptionListener =
        subscriptionProvider.subscriptionUpdates.listen((_) {
      if (mounted && _category != null) _updateAccessStatus();
    });
  }

  bool _looksLikeNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('network error') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('offline');
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = !connectivityService.isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final cachedCourse =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        'course_${widget.courseId}',
        isUserSpecific: true,
      );

      if (cachedCourse != null) {
        _course =
            Course.fromJson(cachedCourse['course'] as Map<String, dynamic>);
        _category = cachedCourse['category'] != null
            ? Category.fromJson(
                cachedCourse['category'] as Map<String, dynamic>)
            : widget.category;
        _hasAccess = cachedCourse['has_access'] ?? false;
        _hasPendingPayment = cachedCourse['has_pending_payment'] ?? false;
        _hasCachedData = true;
        debugLog('CourseDetailScreen', '✅ Loaded course from cache');
      } else if (widget.course != null) {
        _course = widget.course;
        _category = widget.category;
        _hasAccess = widget.hasAccess ?? false;
        _hasCachedData = true;
        debugLog('CourseDetailScreen', '✅ Using passed course data');
      }
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    final connectivityService = context.read<ConnectivityService>();

    if (!connectivityService.isOnline) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final courseProvider = context.read<CourseProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.loadCategories();
      }

      _course ??= await _findCourse(courseProvider, categoryProvider);
      if (_course == null && !_isOffline) {
        await categoryProvider.loadCategories(forceRefresh: true);
        _course = await _findCourse(
          courseProvider,
          categoryProvider,
          forceRefreshCourses: true,
        );
      }
      if (_course == null) throw Exception(AppStrings.courseNotFound);

      if (_category == null && _course!.categoryId > 0) {
        _category = categoryProvider.getCategoryById(_course!.categoryId);
      }

      await _checkAccessStatus();

      await Future.wait([
        _loadChapters(),
        _loadExams(),
      ]);

      await _saveToCache();

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (!_isOffline) {
        unawaited(_refreshPaymentInfoInBackground());
      }
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading fresh data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<Course?> _findCourse(
      CourseProvider courseProvider, CategoryProvider categoryProvider,
      {bool forceRefreshCourses = false}) async {
    for (final category in categoryProvider.categories) {
      if (!courseProvider.hasLoadedCategory(category.id) ||
          forceRefreshCourses) {
        await courseProvider.loadCoursesByCategory(
          category.id,
          forceRefresh: forceRefreshCourses,
          hasAccess: widget.hasAccess ?? _hasAccess,
        );
      }

      final courses = courseProvider.getCoursesByCategory(category.id);
      final foundCourse = courses.firstWhere(
        (c) => c.id == widget.courseId,
        orElse: () => Course(id: 0, name: '', categoryId: 0, chapterCount: 0),
      );
      if (foundCourse.id > 0) {
        _category ??= category;
        return foundCourse;
      }
    }
    return null;
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    try {
      final courseProvider = context.read<CourseProvider>();
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (!mounted) return;

      await _checkAccessStatus(forceCheck: true);
      if (!mounted) return;

      unawaited(_refreshPaymentInfoInBackground(forceRefresh: true));
      unawaited(_loadChapters(forceRefresh: true));
      unawaited(_loadExams(forceRefresh: true));

      await _saveToCache();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();

    if (!connectivityService.isOnline) {
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      setState(() => _isOffline = true);
      return;
    }

    setState(() => _isRefreshing = true);
    var didFail = false;

    try {
      final courseProvider = context.read<CourseProvider>();
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (!mounted) return;

      await _checkAccessStatus(forceCheck: true);
      if (!mounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (!mounted) return;

      await Future.wait([
        _loadChapters(forceRefresh: true),
        _loadExams(forceRefresh: true),
      ]);

      await _saveToCache();
      setState(() => _isOffline = false);

      SnackbarService().showSuccess(context, AppStrings.courseUpdated);
    } catch (e) {
      if (!mounted) return;
      if (_looksLikeNetworkError(e)) {
        setState(() => _isOffline = true);
        _refreshController.refreshFailed();
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        setState(() => _isOffline = false);
        _refreshController.refreshFailed();
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
      didFail = true;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
      if (!didFail) {
        _refreshController.refreshCompleted();
      }
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!_isOffline && forceCheck) {
      _hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(_category!.id);
    } else {
      _hasAccess =
          subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final newAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    if (newAccess != _hasAccess && mounted) {
      setState(() => _hasAccess = newAccess);
      unawaited(_saveToCache());
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;
    final paymentProvider = context.read<PaymentProvider>();
    try {
      await paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !_isOffline);
      final pendingPayments = paymentProvider.getPendingPayments();
      _hasPendingPayment = pendingPayments.any(_matchesPaymentToCategory);

      final rejectedPayments = paymentProvider.getRejectedPayments();
      final recentRejected = rejectedPayments.firstWhere(
        _matchesPaymentToCategory,
        orElse: () => Payment(
          id: 0,
          paymentType: '',
          amount: 0,
          paymentMethod: '',
          status: '',
          createdAt: DateTime.now(),
          categoryName: '',
        ),
      );
      _rejectionReason =
          recentRejected.id != 0 ? recentRejected.rejectionReason : null;
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading payment info: $e');
    }
  }

  bool _matchesPaymentToCategory(Payment payment) {
    if (_category == null) return false;
    if (payment.categoryId != null && payment.categoryId == _category!.id) {
      return true;
    }

    return payment.categoryName.toLowerCase() == _category!.name.toLowerCase();
  }

  Future<void> _refreshPaymentInfoInBackground(
      {bool forceRefresh = false}) async {
    await _loadPaymentInfo(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {});
    unawaited(_saveToCache());
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null) return;

    setState(() {
      _chaptersLoading = true;
    });

    final chapterProvider = context.read<ChapterProvider>();

    try {
      if (_isOffline) {
        await chapterProvider.loadChaptersByCourse(_course!.id);
      } else {
        await chapterProvider.loadChaptersByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (mounted) {
        setState(() {
          _chaptersLoading = false;
          _chaptersLoaded = true;
        });
      }
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null) return;

    setState(() {
      _examsLoading = true;
    });

    final examProvider = context.read<ExamProvider>();

    try {
      if (_isOffline) {
        await examProvider.loadExamsByCourse(_course!.id);
      } else {
        await examProvider.loadExamsByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (mounted) {
        setState(() {
          _examsLoading = false;
          _examsLoaded = true;
        });
      }
    }
  }

  Future<void> _saveToCache() async {
    if (_course == null) return;
    try {
      final deviceService = context.read<DeviceService>();
      deviceService.saveCacheItem(
        'course_${widget.courseId}',
        {
          'course': _course!.toJson(),
          'category': _category?.toJson(),
          'has_access': _hasAccess,
          'has_pending_payment': _hasPendingPayment,
          'rejection_reason': _rejectionReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        ttl: const Duration(hours: 1),
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error saving to cache: $e');
    }
  }

  void _handleChapterTap(Chapter chapter) {
    if (_isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.openChapter);
      return;
    }

    if (chapter.isFree || _hasAccess) {
      context.push('/chapter/${chapter.id}', extra: {
        'chapter': chapter,
        'course': _course,
        'category': _category,
        'hasAccess': _hasAccess,
      });
    } else if (_hasPendingPayment) {
      _showPendingPaymentDialog();
    } else {
      _showPaymentDialog();
    }
  }

  void _handleExamTap(Exam exam) {
    if (_isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.startExam);
      return;
    }

    if (exam.canTakeExam) {
      context.push('/exam/${exam.id}', extra: exam);
    } else if (exam.requiresPayment) {
      _showPaymentDialog();
    }
  }

  void _showPaymentDialog() {
    if (_category == null) {
      SnackbarService().showError(context, AppStrings.categoryNotFound);
      return;
    }

    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    AppDialog.confirm(
      context: context,
      title: AppStrings.unlockContent,
      message:
          '${AppStrings.purchase} "${_category!.name}" ${AppStrings.toAccessAllContent}',
      confirmText: AppStrings.purchaseAccess,
    ).then((confirmed) {
      if (confirmed == true && !_isOffline) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': _hasAccess ? 'repayment' : 'first_time',
        });
      } else if (_isOffline) {
        SnackbarService().showOffline(context, action: AppStrings.makePayment);
      }
    });
  }

  void _showRejectedPaymentDialog() {
    AppDialog.warning(
      context: context,
      title: AppStrings.paymentRejected,
      message: _rejectionReason != null
          ? '${AppStrings.reason}: $_rejectionReason'
          : AppStrings.yourPaymentWasRejected,
    ).then((_) {
      if (!_isOffline) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': 'first_time',
        });
      }
    });
  }

  void _showPendingPaymentDialog() {
    AppDialog.info(
      context: context,
      title: AppStrings.paymentPending,
      message:
          '${AppStrings.youHavePendingPayment} ${_category?.name}. ${AppStrings.pleaseWaitForVerification}',
    );
  }

  Widget _buildAccessBanner() {
    if (_category == null) return const SizedBox.shrink();

    if (_category!.isFree) {
      return AccessBanner.freeCategory();
    }

    if (_hasAccess) {
      return AccessBanner.fullAccess();
    }

    if (_hasPendingPayment) {
      return AccessBanner.paymentPending();
    }

    if (_rejectionReason != null) {
      return AccessBanner.paymentRejected(
        reason: _rejectionReason!,
        onPayNow: _showPaymentDialog,
      );
    }

    return AccessBanner.limitedAccess(
      onPurchase: _showPaymentDialog,
    );
  }

  Widget _buildHeroMetric(
      {required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: Colors.white70,
                size: ResponsiveValues.iconSizeS(context)),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            Text(
              value,
              style: AppTextStyles.titleMedium(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXXS(context)),
            Text(
              label,
              style: AppTextStyles.bodySmall(context)
                  .copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXS(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: Colors.white70,
              size: ResponsiveValues.iconSizeXS(context)),
          SizedBox(width: ResponsiveValues.spacingXS(context)),
          Text(
            label,
            style: AppTextStyles.labelSmall(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHero(List<Chapter> chapters, List<Exam> exams) {
    final course = _course!;
    final categoryPrice = _category?.price;
    final billingLabel = _category?.isFree == true
        ? AppStrings.free
        : '${categoryPrice?.toStringAsFixed(0) ?? '0'} ${AppStrings.etb}';

    return Container(
      margin: EdgeInsets.fromLTRB(
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingS(context),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B5FFF),
              Color(0xFF118AB2),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B5FFF).withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: ResponsiveValues.spacingS(context),
                runSpacing: ResponsiveValues.spacingS(context),
                children: [
                  _buildHeroChip(
                    icon: Icons.category_rounded,
                    label: _category?.name ?? AppStrings.category,
                  ),
                  _buildHeroChip(
                    icon: _hasAccess
                        ? Icons.verified_rounded
                        : Icons.lock_outline_rounded,
                    label: _hasAccess
                        ? AppStrings.fullAccess
                        : (_hasPendingPayment
                            ? AppStrings.paymentPending
                            : AppStrings.limitedAccess),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(
                course.name,
                style: AppTextStyles.headlineSmall(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              if ((course.description ?? '').trim().isNotEmpty) ...[
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Text(
                  course.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.5,
                  ),
                ),
              ],
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              Row(
                children: [
                  _buildHeroMetric(
                    icon: Icons.menu_book_rounded,
                    label: AppStrings.chapters,
                    value: chapters.length.toString(),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  _buildHeroMetric(
                    icon: Icons.quiz_rounded,
                    label: AppStrings.exams,
                    value: exams.length.toString(),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  _buildHeroMetric(
                    icon: Icons.payments_rounded,
                    label: AppStrings.price,
                    value: billingLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIntro({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingS(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.telegramBlue.withValues(alpha: 0.18),
                  AppColors.info.withValues(alpha: 0.10),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            ),
            child: Icon(icon, color: AppColors.telegramBlue),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingXXS(context)),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall(context).copyWith(
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

  Widget _buildTabShell({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      children: [
        _buildSectionIntro(icon: icon, title: title, subtitle: subtitle),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildChaptersList(List<Chapter> chapters) {
    final chapterProvider = context.watch<ChapterProvider>();
    final isLoading =
        _chaptersLoading || chapterProvider.isLoadingForCourse(_course!.id);
    final hasLoaded =
        _chaptersLoaded || chapterProvider.hasLoadedForCourse(_course!.id);

    if (isLoading &&
        chapters.isEmpty &&
        !hasLoaded &&
        !_hasCachedData &&
        !_isOffline) {
      return ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.chapterCard, index: index),
        ),
      );
    }

    if (hasLoaded && chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: AppEmptyState.noData(
            dataType: AppStrings.chapters,
            customMessage: _isOffline
                ? 'No cached chapters available'
                : 'No chapters available for this course',
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    if (chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: AppEmptyState.noData(
            dataType: AppStrings.chapters,
            customMessage: _isOffline
                ? AppStrings.noCachedChapters
                : AppStrings.chaptersWillAppearHere,
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: ChapterCard(
            chapter: chapter,
            courseId: _course!.id,
            categoryId: _category?.id ?? 0,
            categoryName: _category?.name ?? AppStrings.category,
            onTap: () => _handleChapterTap(chapter),
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildExamsList(List<Exam> exams) {
    final examProvider = context.watch<ExamProvider>();
    final isLoading =
        _examsLoading || examProvider.isLoadingForCourse(_course!.id);
    final hasLoaded =
        _examsLoaded || examProvider.hasLoadedForCourse(_course!.id);

    if (isLoading &&
        exams.isEmpty &&
        !hasLoaded &&
        !_hasCachedData &&
        !_isOffline) {
      return ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.examCard, index: index),
        ),
      );
    }

    if (hasLoaded && exams.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: AppEmptyState.noData(
            dataType: AppStrings.exams,
            customMessage: _isOffline
                ? 'No cached exams available'
                : 'No exams available for this course',
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: AppEmptyState.noData(
            dataType: AppStrings.exams,
            customMessage: _isOffline
                ? AppStrings.noCachedExams
                : AppStrings.examsWillAppearHere,
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: ExamCard(
            exam: exam,
            onTap: () => _handleExamTap(exam),
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: AppStrings.course,
        subtitle: AppStrings.loading,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: AppColors.getDivider(context).withValues(alpha: 0.5),
                    width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                    icon: Icon(Icons.menu_book_rounded),
                    text: AppStrings.chapters),
                Tab(icon: Icon(Icons.quiz_rounded), text: AppStrings.exams),
              ],
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
            ),
          ),
          Expanded(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: ListView.separated(
                itemCount: 5,
                separatorBuilder: (_, __) =>
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                itemBuilder: (context, index) => AppShimmer(
                  type: index % 2 == 0
                      ? ShimmerType.chapterCard
                      : ShimmerType.examCard,
                  index: index,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterProvider = context.watch<ChapterProvider>();
    final examProvider = context.watch<ExamProvider>();

    final chapters = _course != null
        ? chapterProvider.getChaptersByCourse(_course!.id)
        : <Chapter>[];
    final exams =
        _course != null ? examProvider.getExamsByCourse(_course!.id) : <Exam>[];

    if (_isLoading && !_hasCachedData) {
      return _buildSkeletonLoader();
    }

    if (_course == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.course,
          subtitle: AppStrings.notFound,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: AppEmptyState.error(
            title: AppStrings.courseNotFound,
            message: _isOffline
                ? AppStrings.noCachedDataAvailable
                : AppStrings.courseDoesNotExist,
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: _course!.name,
        subtitle:
            _isOffline ? AppStrings.offlineMode : AppStrings.courseContent,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        showOfflineIndicator: _isOffline,
      ),
      body: Column(
        children: [
          if (_isOffline && _pendingCount > 0)
            Container(
              margin: EdgeInsets.all(ResponsiveValues.spacingM(context)),
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.info.withValues(alpha: 0.2),
                    AppColors.info.withValues(alpha: 0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: AppColors.info,
                      size: ResponsiveValues.iconSizeS(context)),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
                      '$_pendingCount pending change${_pendingCount > 1 ? 's' : ''}',
                      style: AppTextStyles.bodySmall(context)
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          _buildAccessBanner(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: AppColors.getDivider(context).withValues(alpha: 0.5),
                    width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                    icon: Icon(Icons.menu_book_rounded),
                    text: AppStrings.chapters),
                Tab(icon: Icon(Icons.quiz_rounded), text: AppStrings.exams),
              ],
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
            ),
          ),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              onRefresh: _manualRefresh,
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChaptersList(chapters),
                  _buildExamsList(exams),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}
