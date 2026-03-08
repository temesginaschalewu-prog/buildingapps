import 'dart:async';
import 'package:familyacademyclient/services/refresh_service.dart';
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
  bool _isFirstLoad = true;
  int _pendingCount = 0;

  StreamSubscription? _subscriptionListener;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeScreen());
    _setupConnectivityListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
        if (isOnline && !_isRefreshing && _course != null) {
          _refreshInBackground();
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

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() {
      _isOffline = !connectivityService.isOnline;
      _pendingCount = connectivityService.pendingActionsCount;
    });
  }

  Future<void> _initializeScreen() async {
    await _checkConnectivity();
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      setState(() => _isFirstLoad = false);
      if (!_isOffline) {
        await _refreshInBackground();
      }
    } else {
      await _loadFreshData();
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
        _course = Course.fromJson(cachedCourse['course']);
        _category = cachedCourse['category'] != null
            ? Category.fromJson(cachedCourse['category'])
            : widget.category;
        _hasAccess = cachedCourse['has_access'] ?? false;
        _hasPendingPayment = cachedCourse['has_pending_payment'] ?? false;
        _hasCachedData = true;
      } else if (widget.course != null) {
        _course = widget.course;
        _category = widget.category;
        _hasAccess = widget.hasAccess ?? false;
        _hasCachedData = true;
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
        _isFirstLoad = false;
      });
      return;
    }

    try {
      final courseProvider = context.read<CourseProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      _course ??= await _findCourse(courseProvider, categoryProvider);
      if (_course == null) throw Exception('Course not found');

      if (_category == null && _course!.categoryId > 0) {
        _category = categoryProvider.getCategoryById(_course!.categoryId);
      }

      await _checkAccessStatus();
      await _loadPaymentInfo();
      await Future.wait([_loadChapters(), _loadExams()]);
      await _saveToCache();
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading fresh data: $e');
      setState(() => _isOffline = true);
    } finally {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<Course?> _findCourse(
      CourseProvider courseProvider, CategoryProvider categoryProvider) async {
    for (final category in categoryProvider.categories) {
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
    _isRefreshing = true;

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

      await _loadChapters(forceRefresh: true);
      if (!mounted) return;

      await _loadExams(forceRefresh: true);
      if (!mounted) return;

      await _saveToCache();
    } finally {
      if (mounted) _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivity = ConnectivityService();
    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'refresh');
      setState(() => _isOffline = true);
      _refreshController.refreshFailed();
      return;
    }

    setState(() => _isRefreshing = true);

    await RefreshService().pullToRefresh(
      context: context,
      refreshFunction: () async {
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

        await _loadChapters(forceRefresh: true);
        if (!mounted) return;

        await _loadExams(forceRefresh: true);
        if (!mounted) return;

        await _saveToCache();
        setState(() => _isOffline = false);
      },
      successMessage: 'Course updated',
    );

    _refreshController.refreshCompleted();
    setState(() => _isRefreshing = false);
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
      await _saveToCache();
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;
    final paymentProvider = context.read<PaymentProvider>();
    try {
      await paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !_isOffline);
      final pendingPayments = paymentProvider.getPendingPayments();
      _hasPendingPayment = pendingPayments.any(
        (payment) =>
            payment.categoryName.toLowerCase() == _category!.name.toLowerCase(),
      );

      final rejectedPayments = paymentProvider.getRejectedPayments();
      final recentRejected = rejectedPayments.firstWhere(
        (p) => p.categoryName.toLowerCase() == _category!.name.toLowerCase(),
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

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null) return;
    final chapterProvider = context.read<ChapterProvider>();
    await chapterProvider.loadChaptersByCourse(_course!.id,
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null) return;
    final examProvider = context.read<ExamProvider>();
    await examProvider.loadExamsByCourse(_course!.id,
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _saveToCache() async {
    if (_course == null) return;
    try {
      final deviceService = context.read<DeviceService>();
      await deviceService.saveCacheItem(
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
    if (exam.canTakeExam) {
      context.push('/exam/${exam.id}', extra: exam);
    } else if (exam.requiresPayment) {
      _showPaymentDialog();
    }
  }

  void _showPaymentDialog() {
    if (_category == null) {
      SnackbarService().showError(context, 'Category not found');
      return;
    }

    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    AppDialog.confirm(
      context: context,
      title: 'Unlock Content',
      message: 'Purchase "${_category!.name}" to access all content',
      confirmText: 'Purchase Access',
    ).then((confirmed) {
      if (confirmed == true) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': _hasAccess ? 'repayment' : 'first_time',
        });
      }
    });
  }

  void _showRejectedPaymentDialog() {
    AppDialog.warning(
      context: context,
      title: 'Payment Rejected',
      message: _rejectionReason != null
          ? 'Reason: $_rejectionReason'
          : 'Your previous payment was rejected.',
    ).then((_) {
      context.push('/payment', extra: {
        'category': _category,
        'paymentType': 'first_time',
      });
    });
  }

  void _showPendingPaymentDialog() {
    AppDialog.info(
      context: context,
      title: 'Payment Pending',
      message:
          'You have a pending payment for ${_category?.name}. Please wait for admin verification (1-3 working days).',
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

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: 'Course',
        subtitle: 'Loading...',
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
                Tab(icon: Icon(Icons.menu_book_rounded), text: 'Chapters'),
                Tab(icon: Icon(Icons.quiz_rounded), text: 'Exams'),
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

  int _getChaptersChildCount(List<Chapter> chapters, bool isLoading) {
    if (chapters.isNotEmpty) return chapters.length;
    if (isLoading) return 5;
    return 1;
  }

  int _getExamsChildCount(List<Exam> exams, bool isLoading) {
    if (exams.isNotEmpty) return exams.length;
    if (isLoading) return 5;
    return 1;
  }

  Widget _buildChaptersList(List<Chapter> chapters) {
    final chapterProvider = context.watch<ChapterProvider>();
    final isLoading = chapterProvider.isLoadingForCourse(_course!.id);

    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: _getChaptersChildCount(chapters, isLoading),
      itemBuilder: (context, index) {
        if (isLoading && chapters.isEmpty) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: AppShimmer(type: ShimmerType.chapterCard, index: index),
          );
        }

        if (index < chapters.length) {
          final chapter = chapters[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: ChapterCard(
              chapter: chapter,
              courseId: _course!.id,
              categoryId: _category?.id ?? 0,
              categoryName: _category?.name ?? 'Category',
              onTap: () => _handleChapterTap(chapter),
              index: index,
            ),
          );
        }

        if (!isLoading && chapters.isEmpty && index == 0) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: ResponsiveValues.spacingXXL(context)),
              child: AppEmptyState.noData(
                dataType: 'Chapters',
                customMessage: _isOffline
                    ? 'No cached chapters available. Connect to load chapters.'
                    : 'Chapters will appear here when available.',
                onRefresh: _manualRefresh,
                isOffline: _isOffline,
                pendingCount: _pendingCount,
              ),
            ),
          );
        }

        return null;
      },
    );
  }

  Widget _buildExamsList(List<Exam> exams) {
    final examProvider = context.watch<ExamProvider>();
    final isLoading = examProvider.isLoading;

    return ListView.builder(
      padding: ResponsiveValues.screenPadding(context),
      itemCount: _getExamsChildCount(exams, isLoading),
      itemBuilder: (context, index) {
        if (isLoading && exams.isEmpty) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: AppShimmer(type: ShimmerType.examCard, index: index),
          );
        }

        if (index < exams.length) {
          final exam = exams[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: ExamCard(
              exam: exam,
              onTap: () => _handleExamTap(exam),
              index: index,
            ),
          );
        }

        if (!isLoading && exams.isEmpty && index == 0) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  vertical: ResponsiveValues.spacingXXL(context)),
              child: AppEmptyState.noData(
                dataType: 'Exams',
                customMessage: _isOffline
                    ? 'No cached exams available. Connect to load exams.'
                    : 'Exams will appear here when available.',
                onRefresh: _manualRefresh,
                isOffline: _isOffline,
                pendingCount: _pendingCount,
              ),
            ),
          );
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad && !_hasCachedData) return _buildSkeletonLoader();

    if (_course == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'Course',
          subtitle: 'Not found',
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        ),
        body: Center(
          child: AppEmptyState.error(
            title: 'Course not found',
            message: _isOffline
                ? 'No cached data available. Please check your connection.'
                : 'The course you\'re looking for doesn\'t exist.',
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    final chapterProvider = context.watch<ChapterProvider>();
    final examProvider = context.watch<ExamProvider>();
    final chapters = chapterProvider.getChaptersByCourse(_course!.id);
    final exams = examProvider.getExamsByCourse(_course!.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: _course!.name,
        subtitle: _isRefreshing
            ? 'Refreshing...'
            : (_isOffline ? 'Offline mode' : 'Course content'),
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.getBackground(context).withValues(alpha: 0.95),
              AppColors.getBackground(context)
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color:
                          AppColors.getDivider(context).withValues(alpha: 0.5),
                      width: 0.5),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.menu_book_rounded), text: 'Chapters'),
                  Tab(icon: Icon(Icons.quiz_rounded), text: 'Exams'),
                ],
                labelStyle: AppTextStyles.labelMedium(context),
                unselectedLabelStyle: AppTextStyles.labelMedium(context),
                indicatorColor: AppColors.telegramBlue,
                indicatorWeight: 3,
                labelColor: AppColors.telegramBlue,
                unselectedLabelColor: AppColors.getTextSecondary(context),
              ),
            ),
            _buildAccessBanner(),
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
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.telegramBlue),
                    ),
                  ),
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChaptersList(chapters),
                    _buildExamsList(exams)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    _subscriptionListener?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
