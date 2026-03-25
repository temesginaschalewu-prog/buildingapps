import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

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
import '../../providers/settings_provider.dart';
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
  final RefreshController _chaptersRefreshController = RefreshController();
  final RefreshController _examsRefreshController = RefreshController();

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
  bool _showChaptersRefreshShimmer = false;
  bool _showExamsRefreshShimmer = false;

  StreamSubscription? _subscriptionListener;
  StreamSubscription? _connectivitySubscription;
  bool _paymentListenerAttached = false;
  PaymentProvider? _paymentProviderRef;
  late SettingsProvider _settingsProvider;

  // ✅ Flag to prevent operations after dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsProvider = Provider.of<SettingsProvider>(context);
    _setupListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_paymentListenerAttached && _paymentProviderRef != null) {
      _paymentProviderRef!.removeListener(_handlePaymentProviderChange);
    }
    _tabController.dispose();
    _chaptersRefreshController.dispose();
    _examsRefreshController.dispose();
    _subscriptionListener?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      if (!_isOffline) {
        await _loadPaymentInfo(forceRefresh: true);
        await _saveToCache();
      }
      if (mounted && !_isDisposed) {
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
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted && !_isDisposed) {
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
      if (mounted && !_isDisposed && _category != null) _updateAccessStatus();
    });

    final paymentProvider = context.read<PaymentProvider>();
    _paymentProviderRef = paymentProvider;
    if (!_paymentListenerAttached) {
      paymentProvider.addListener(_handlePaymentProviderChange);
      _paymentListenerAttached = true;
    }
  }

  void _handlePaymentProviderChange() {
    if (_isDisposed || !mounted || _category == null) return;
    _syncPaymentInfoFromProvider();
    if (mounted && !_isDisposed) setState(() {});
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
    if (mounted && !_isDisposed) {
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
      final subscriptionProvider = context.read<SubscriptionProvider>();
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
        final knownAccess = _category != null
            ? subscriptionProvider
                .hasActiveSubscriptionForCategory(_category!.id)
            : false;
        _hasAccess = knownAccess || (cachedCourse['has_access'] ?? false);
        _hasPendingPayment =
            _hasAccess ? false : (cachedCourse['has_pending_payment'] ?? false);
        _rejectionReason = _hasAccess ? null : cachedCourse['rejection_reason'];
        _hasCachedData = true;
        debugLog('CourseDetailScreen', '✅ Loaded course from cache');
        return;
      }

      final restoredFromProviders = await _restoreFromSavedProviders();
      if (restoredFromProviders) {
        return;
      }

      if (widget.course != null) {
        _course = widget.course;
        _category = widget.category;
        _hasAccess = (widget.hasAccess ?? false) ||
            (_category != null
                ? subscriptionProvider
                    .hasActiveSubscriptionForCategory(_category!.id)
                : false);
        _hasPendingPayment = _hasAccess ? false : _hasPendingPayment;
        _rejectionReason = _hasAccess ? null : _rejectionReason;
        _hasCachedData = true;
        debugLog('CourseDetailScreen', '✅ Using passed course data');
      }
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading from cache: $e');
    }
  }

  Future<bool> _restoreFromSavedProviders() async {
    try {
      final categoryProvider = context.read<CategoryProvider>();
      final courseProvider = context.read<CourseProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.loadCategories();
      }

      Course? restoredCourse = courseProvider.getCourseById(widget.courseId);
      Category? restoredCategory = restoredCourse != null
          ? categoryProvider.getCategoryById(restoredCourse.categoryId)
          : null;

      if (restoredCourse == null) {
        for (final category in categoryProvider.categories) {
          if (!courseProvider.hasLoadedCategory(category.id)) {
            await courseProvider.loadCoursesByCategory(
              category.id,
              hasAccess: widget.hasAccess ??
                  subscriptionProvider
                      .hasActiveSubscriptionForCategory(category.id),
            );
          }

          final categoryCourses = courseProvider.getCoursesByCategory(category.id);
          try {
            restoredCourse =
                categoryCourses.firstWhere((course) => course.id == widget.courseId);
            restoredCategory = category;
            break;
          } catch (_) {
            continue;
          }
        }
      }

      if (restoredCourse == null) {
        return false;
      }

      _course = restoredCourse;
      _category = restoredCategory ??
          widget.category ??
          categoryProvider.getCategoryById(restoredCourse.categoryId);
      _hasAccess = widget.hasAccess ??
          (_category != null
              ? subscriptionProvider
                  .hasActiveSubscriptionForCategory(_category!.id)
              : false);
      if (_hasAccess) {
        _hasPendingPayment = false;
        _rejectionReason = null;
      }
      _hasCachedData = true;
      debugLog(
        'CourseDetailScreen',
        '✅ Restored course from saved provider caches',
      );
      return true;
    } catch (e) {
      debugLog(
        'CourseDetailScreen',
        '⚠️ Failed provider cache recovery: $e',
      );
      return false;
    }
  }

  Future<void> _loadFreshData() async {
    final connectivityService = context.read<ConnectivityService>();

    if (!connectivityService.isOnline) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
        });
      }
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

      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }

      if (!_isOffline) {
        unawaited(_refreshPaymentInfoInBackground());
      }
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading fresh data: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
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
    if (_isRefreshing || _isDisposed) return;
    if (mounted && !_isDisposed) setState(() => _isRefreshing = true);

    try {
      final courseProvider = context.read<CourseProvider>();
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (_isDisposed || !mounted) return;

      await _checkAccessStatus(forceCheck: true);
      if (_isDisposed || !mounted) return;

      unawaited(_refreshPaymentInfoInBackground(forceRefresh: true));
      unawaited(_loadChapters(forceRefresh: true));
      unawaited(_loadExams(forceRefresh: true));

      await _saveToCache();
    } finally {
      if (mounted && !_isDisposed) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing || _isDisposed) return;

    final connectivityService = context.read<ConnectivityService>();

    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      if (mounted && !_isDisposed) setState(() => _isOffline = true);
      return;
    }

    final chapterProvider = context.read<ChapterProvider>();
    final examProvider = context.read<ExamProvider>();
    final hasChapterData =
        chapterProvider.getChaptersByCourse(_course?.id ?? 0).isNotEmpty;
    final hasExamData =
        examProvider.getExamsByCourse(_course?.id ?? 0).isNotEmpty;

    if (mounted && !_isDisposed) {
      setState(() {
        _isRefreshing = true;
        _showChaptersRefreshShimmer = !hasChapterData;
        _showExamsRefreshShimmer = !hasExamData;
      });
    }

    try {
      final courseProvider = context.read<CourseProvider>();
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (_isDisposed || !mounted) return;

      await _checkAccessStatus(forceCheck: true);
      if (_isDisposed || !mounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (_isDisposed || !mounted) return;

      await Future.wait([
        _loadChapters(forceRefresh: true),
        _loadExams(forceRefresh: true),
      ]);

      await _saveToCache();
      if (mounted && !_isDisposed) setState(() => _isOffline = false);

      SnackbarService().showSuccess(context, AppStrings.courseUpdated);
    } catch (e) {
      if (_isDisposed || !mounted) return;
      if (_looksLikeNetworkError(e)) {
        if (mounted && !_isDisposed) setState(() => _isOffline = true);
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        if (mounted && !_isDisposed) setState(() => _isOffline = false);
        SnackbarService().showInfo(
          context,
          _hasCachedData
              ? 'We could not refresh this course just now. Your saved content is still available.'
              : AppStrings.refreshFailed,
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isRefreshing = false;
          _showChaptersRefreshShimmer = false;
          _showExamsRefreshShimmer = false;
        });
      }
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null || _isDisposed) return;
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
    if (_category == null || _isDisposed) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final newAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    if (newAccess != _hasAccess && mounted && !_isDisposed) {
      if (mounted && !_isDisposed) setState(() => _hasAccess = newAccess);
      unawaited(_saveToCache());
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null || _isDisposed) return;
    final paymentProvider = context.read<PaymentProvider>();
    try {
      await paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !_isOffline);
      if (mounted && !_isDisposed) _syncPaymentInfoFromProvider();
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading payment info: $e');
    }
  }

  void _syncPaymentInfoFromProvider() {
    if (_category == null || _isDisposed) return;

    final paymentProvider = context.read<PaymentProvider>();
    if (_hasAccess) {
      final changed = _hasPendingPayment || _rejectionReason != null;
      _hasPendingPayment = false;
      _rejectionReason = null;

      if (changed && mounted && !_isDisposed) {
        if (mounted && !_isDisposed) setState(() {});
        unawaited(_saveToCache());
      }
      return;
    }

    final pendingPayments = paymentProvider.getPendingPayments();
    final hasPendingPayment = pendingPayments.any(_matchesPaymentToCategory);

    final rejectedPayments = paymentProvider.getRejectedPayments();
    final recentRejected =
        rejectedPayments.where(_matchesPaymentToCategory).fold<Payment?>(
              null,
              (latest, payment) =>
                  latest == null || payment.createdAt.isAfter(latest.createdAt)
                      ? payment
                      : latest,
            );
    final rejectionReason = recentRejected?.rejectionReason;

    final changed = hasPendingPayment != _hasPendingPayment ||
        rejectionReason != _rejectionReason;

    _hasPendingPayment = hasPendingPayment;
    _rejectionReason = rejectionReason;

    if (changed && mounted && !_isDisposed) {
      if (mounted && !_isDisposed) setState(() {});
      unawaited(_saveToCache());
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
    if (_isDisposed || !mounted) return;
    if (mounted && !_isDisposed) setState(() {});
    unawaited(_saveToCache());
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null || _isDisposed) return;

    if (mounted && !_isDisposed) setState(() => _chaptersLoading = true);

    final chapterProvider = context.read<ChapterProvider>();

    try {
      if (_isOffline) {
        await chapterProvider.loadChaptersByCourse(_course!.id);
      } else {
        await chapterProvider.loadChaptersByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _chaptersLoading = false;
          _chaptersLoaded = true;
        });
      }
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null || _isDisposed) return;

    if (mounted && !_isDisposed) setState(() => _examsLoading = true);

    final examProvider = context.read<ExamProvider>();

    try {
      if (_isOffline) {
        await examProvider.loadExamsByCourse(_course!.id);
      } else {
        await examProvider.loadExamsByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _examsLoading = false;
          _examsLoaded = true;
        });
      }
    }
  }

  Future<void> _saveToCache() async {
    if (_course == null || _isDisposed) return;
    try {
      final deviceService = context.read<DeviceService>();
      deviceService.saveCacheItem(
        'course_${widget.courseId}',
        {
          'course': _course!.toJson(),
          'category': _category?.toJson(),
          'has_access': _hasAccess,
          'has_pending_payment': _hasAccess ? false : _hasPendingPayment,
          'rejection_reason': _hasAccess ? null : _rejectionReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        ttl: const Duration(hours: 1),
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error saving to cache: $e');
    }
  }

  Future<bool> _hasOfflineChapterContent(Chapter chapter) async {
    try {
      final deviceService = context.read<DeviceService>();

      final cachedVideos =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        'cached_videos_chapter_${chapter.id}',
        isUserSpecific: true,
      );
      if (cachedVideos != null && cachedVideos.isNotEmpty) {
        return true;
      }

      final cachedNotes =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        'cached_notes_chapter_${chapter.id}',
        isUserSpecific: true,
      );
      return cachedNotes != null && cachedNotes.isNotEmpty;
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error checking chapter offline cache: $e');
      return false;
    }
  }

  Future<void> _handleChapterTap(Chapter chapter) async {
    if (_isOffline) {
      final hasOfflineContent =
          chapter.isFree || _hasAccess || await _hasOfflineChapterContent(chapter);

      if (hasOfflineContent) {
        if (!mounted || _isDisposed) return;
        unawaited(context.push('/chapter/${chapter.id}', extra: {
          'chapter': chapter,
          'course': _course,
          'category': _category,
          'hasAccess': true,
        }));
        return;
      }

      SnackbarService().showOffline(context, action: AppStrings.openChapter);
      return;
    }

    if (_hasPendingPayment) {
      _showPendingPaymentDialog();
      return;
    }

    if (chapter.isFree || _hasAccess) {
      unawaited(context.push('/chapter/${chapter.id}', extra: {
        'chapter': chapter,
        'course': _course,
        'category': _category,
        'hasAccess': _hasAccess,
      }));
    } else {
      _showPaymentDialog();
    }
  }

  void _handleExamTap(Exam exam) {
    if (_isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.startExam);
      return;
    }

    if (_hasPendingPayment) {
      _showPendingPaymentDialog();
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

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasExpiredSubscription = subscriptionProvider.expiredSubscriptions
        .any((sub) => sub.categoryId == _category!.id);

    final paymentType = hasExpiredSubscription ? 'repayment' : 'first_time';

    AppDialog.confirm(
      context: context,
      title: AppStrings.unlockContent,
      message: hasExpiredSubscription
          ? 'Your subscription for "${_category!.name}" has expired. Renew to access all content.'
          : '${AppStrings.purchase} "${_category!.name}" ${AppStrings.toAccessAllContent}',
      confirmText:
          hasExpiredSubscription ? 'Renew Now' : AppStrings.purchaseAccess,
    ).then((confirmed) {
      if (confirmed == true && !_isOffline && mounted && !_isDisposed) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': paymentType,
        });
      } else if (_isOffline && mounted) {
        SnackbarService().showOffline(context, action: AppStrings.makePayment);
      }
    });
  }

  void _showRejectedPaymentDialog() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasExpiredSubscription = subscriptionProvider.expiredSubscriptions
        .any((sub) => sub.categoryId == _category!.id);

    AppDialog.warning(
      context: context,
      title: AppStrings.paymentRejected,
      message: _rejectionReason != null
          ? '${AppStrings.reason}: $_rejectionReason'
          : AppStrings.yourPaymentWasRejected,
    ).then((_) {
      if (!_isOffline && mounted && !_isDisposed) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': hasExpiredSubscription ? 'repayment' : 'first_time',
        });
      }
    });
  }

  void _showPendingPaymentDialog() {
    AppDialog.info(
      context: context,
      title: AppStrings.paymentPending,
      message:
          '${AppStrings.youHavePendingPayment} ${_category?.name}. ${_settingsProvider.getPendingPaymentStatusMessage()}',
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
      return AccessBanner.paymentPending(
        message: _settingsProvider.getPendingPaymentStatusMessage(),
      );
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

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getDivider(context).withValues(alpha: 0.7),
            width: 0.6,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: AppStrings.chapters),
          Tab(text: AppStrings.exams),
        ],
        labelStyle: AppTextStyles.labelMedium(context).copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTextStyles.labelMedium(context),
        indicatorColor: AppColors.telegramBlue,
        indicatorWeight: 2.5,
        labelColor: AppColors.telegramBlue,
        unselectedLabelColor: AppColors.getTextSecondary(context),
      ),
    );
  }

  Widget _buildChaptersList(List<Chapter> chapters) {
    final chapterProvider = context.watch<ChapterProvider>();
    final isLoading =
        _chaptersLoading || chapterProvider.isLoadingForCourse(_course!.id);
    final hasLoaded =
        _chaptersLoaded || chapterProvider.hasLoadedForCourse(_course!.id);

    // ✅ FIXED: Only show shimmer if NO cached data AND loading
    final shouldShowShimmer = chapters.isEmpty &&
        !_isOffline &&
        (_showChaptersRefreshShimmer || (isLoading && !hasLoaded));

    if (shouldShowShimmer) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.chapterCard, index: index),
        ),
      );
    }

    if (chapters.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingXXL(context),
        ),
        children: [
          AppEmptyState.noData(
            dataType: AppStrings.chapters,
            customMessage: _isOffline
                ? AppStrings.noCachedChapters
                : 'Chapters for this course will appear here.',
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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

    // ✅ FIXED: Only show shimmer if NO cached data AND loading
    final shouldShowShimmer = exams.isEmpty &&
        !_isOffline &&
        (_showExamsRefreshShimmer || (isLoading && !hasLoaded));

    if (shouldShowShimmer) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.examCard, index: index),
        ),
      );
    }

    if (exams.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingXXL(context),
        ),
        children: [
          AppEmptyState.noData(
            dataType: AppStrings.exams,
            customMessage: _isOffline
                ? AppStrings.noCachedExams
                : 'Exams for this course will appear here.',
            onRefresh: _manualRefresh,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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

  Widget _buildRefreshableTab({
    required Widget child,
    required RefreshController controller,
  }) {
    return SmartRefresher(
      controller: controller,
      onRefresh: () async {
        await _manualRefresh();
        if (mounted && !_isDisposed) {
          controller.refreshCompleted();
        }
      },
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
      child: child,
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
              tabs: const [
                Tab(text: AppStrings.chapters),
                Tab(text: AppStrings.exams),
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

    // ✅ CRITICAL: Only show shimmer if loading AND no cached data
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
              _buildAccessBanner(),
              _buildTabs(),
              Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRefreshableTab(
                  child: _buildChaptersList(chapters),
                  controller: _chaptersRefreshController,
                ),
                _buildRefreshableTab(
                  child: _buildExamsList(exams),
                  controller: _examsRefreshController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
