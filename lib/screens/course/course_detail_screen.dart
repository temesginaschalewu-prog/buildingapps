// lib/screens/course/course_detail_screen.dart
// COMPLETE FINAL VERSION - PROPER SHIMMER & LOADING

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
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/common/access_banner.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
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
    with BaseScreenMixin<CourseDetailScreen>, TickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _refreshController = RefreshController();

  Course? _course;
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  String? _rejectionReason;

  bool _hasCachedData = false;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  bool _chaptersLoaded = false;
  bool _examsLoaded = false;
  bool _chaptersLoading = false;
  bool _examsLoading = false;

  late CourseProvider _courseProvider;
  late ChapterProvider _chapterProvider;
  late ExamProvider _examProvider;
  late SubscriptionProvider _subscriptionProvider;
  late PaymentProvider _paymentProvider;
  late CategoryProvider _categoryProvider;

  @override
  String get screenTitle => _course?.name ?? AppStrings.course;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : AppStrings.courseContent;

  // ✅ CRITICAL: Only show loading if no cached data AND loading
  @override
  bool get isLoading => _isLoading && !_hasCachedData;

  @override
  bool get hasCachedData => _hasCachedData;

  @override
  dynamic get errorMessage =>
      _course == null ? AppStrings.courseNotFound : null;

  // ✅ Shimmer type for course detail (chapters)
  @override
  ShimmerType get shimmerType => ShimmerType.chapterCard;

  @override
  int get shimmerItemCount => 5;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context)),
        onPressed: () => context.pop(),
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _courseProvider = Provider.of<CourseProvider>(context);
    _chapterProvider = Provider.of<ChapterProvider>(context);
    _examProvider = Provider.of<ExamProvider>(context);
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    _paymentProvider = Provider.of<PaymentProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context);

    _subscriptionProvider.subscriptionUpdates.listen((_) {
      if (isMounted && _category != null) _updateAccessStatus();
    });

    // Mark as loaded if we have data
    if (_course != null && _hasCachedData) {
      _hasLoadedOnce = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      if (isMounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
      unawaited(_loadChapters());
      unawaited(_loadExams());
      if (!isOffline) unawaited(_refreshInBackground());
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
    if (!isOffline) {
      try {
        if (_categoryProvider.categories.isEmpty) {
          await _categoryProvider.loadCategories();
        }

        _course ??= await _findCourse();
        if (_course == null && !isOffline) {
          await _categoryProvider.loadCategories(forceRefresh: true);
          _course = await _findCourse(forceRefreshCourses: true);
        }
        if (_course == null) throw Exception(AppStrings.courseNotFound);

        if (_category == null && _course!.categoryId > 0) {
          _category = _categoryProvider.getCategoryById(_course!.categoryId);
        }

        await _checkAccessStatus();
        await Future.wait([_loadChapters(), _loadExams()]);
        await _saveToCache();

        if (isMounted) {
          setState(() {
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
        if (!isOffline) unawaited(_refreshPaymentInfoInBackground());
      } catch (e) {
        debugLog('CourseDetailScreen', 'Error loading fresh data: $e');
        if (isMounted) setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<Course?> _findCourse({bool forceRefreshCourses = false}) async {
    for (final category in _categoryProvider.categories) {
      if (!_courseProvider.hasLoadedCategory(category.id) ||
          forceRefreshCourses) {
        await _courseProvider.loadCoursesByCategory(
          category.id,
          forceRefresh: forceRefreshCourses,
          hasAccess: widget.hasAccess ?? _hasAccess,
        );
      }

      final courses = _courseProvider.getCoursesByCategory(category.id);
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
    if (isRefreshing) return;

    try {
      if (_course != null && _category != null) {
        await _courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (!isMounted) return;
      await _checkAccessStatus(forceCheck: true);
      if (!isMounted) return;

      unawaited(_refreshPaymentInfoInBackground(forceRefresh: true));
      unawaited(_loadChapters(forceRefresh: true));
      unawaited(_loadExams(forceRefresh: true));
      await _saveToCache();
    } catch (e) {
      debugLog('CourseDetailScreen', 'Background refresh error: $e');
    }
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    try {
      if (_course != null && _category != null) {
        await _courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }

      if (!isMounted) return;
      await _checkAccessStatus(forceCheck: true);
      if (!isMounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (!isMounted) return;

      await Future.wait(
          [_loadChapters(forceRefresh: true), _loadExams(forceRefresh: true)]);
      await _saveToCache();
      _refreshController.refreshCompleted();
      setState(() => _hasLoadedOnce = true);
    } catch (e) {
      _refreshController.refreshFailed();
      rethrow;
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;

    if (!isOffline && forceCheck) {
      _hasAccess = await _subscriptionProvider
          .checkHasActiveSubscriptionForCategory(_category!.id);
    } else {
      _hasAccess =
          _subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;
    final newAccess =
        _subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    if (newAccess != _hasAccess && isMounted) {
      setState(() => _hasAccess = newAccess);
      unawaited(_saveToCache());
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;
    try {
      await _paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !isOffline);
      final pendingPayments = _paymentProvider.getPendingPayments();
      _hasPendingPayment = pendingPayments.any(_matchesPaymentToCategory);

      final rejectedPayments = _paymentProvider.getRejectedPayments();
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
    if (payment.categoryId != null && payment.categoryId == _category!.id)
      return true;
    return payment.categoryName.toLowerCase() == _category!.name.toLowerCase();
  }

  Future<void> _refreshPaymentInfoInBackground(
      {bool forceRefresh = false}) async {
    await _loadPaymentInfo(forceRefresh: forceRefresh);
    if (!isMounted) return;
    setState(() {});
    unawaited(_saveToCache());
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null) return;

    setState(() => _chaptersLoading = true);

    try {
      if (isOffline) {
        await _chapterProvider.loadChaptersByCourse(_course!.id);
      } else {
        await _chapterProvider.loadChaptersByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (isMounted) {
        setState(() {
          _chaptersLoading = false;
          _chaptersLoaded = true;
        });
      }
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null) return;

    setState(() => _examsLoading = true);

    try {
      if (isOffline) {
        await _examProvider.loadExamsByCourse(_course!.id);
      } else {
        await _examProvider.loadExamsByCourse(_course!.id,
            forceRefresh: forceRefresh);
      }
    } finally {
      if (isMounted) {
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
    if (isOffline) {
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
    if (isOffline) {
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
      if (confirmed == true && !isOffline) {
        context.push('/payment', extra: {
          'category': _category,
          'paymentType': _hasAccess ? 'repayment' : 'first_time',
        });
      } else if (isOffline) {
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
      if (!isOffline) {
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

    if (_category!.isFree) return AccessBanner.freeCategory();
    if (_hasAccess) return AccessBanner.fullAccess();
    if (_hasPendingPayment) return AccessBanner.paymentPending();
    if (_rejectionReason != null) {
      return AccessBanner.paymentRejected(
        reason: _rejectionReason!,
        onPayNow: _showPaymentDialog,
      );
    }
    return AccessBanner.limitedAccess(onPurchase: _showPaymentDialog);
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _course!.name,
            style: AppTextStyles.headlineMedium(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_course!.description?.isNotEmpty == true) ...[
            SizedBox(height: ResponsiveValues.spacingS(context)),
            Text(
              _course!.description!,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    final chapters = _chapterProvider.getChaptersByCourse(_course!.id);
    final isLoading =
        _chaptersLoading || _chapterProvider.isLoadingForCourse(_course!.id);

    // Show shimmer only if loading and no chapters AND no cached data
    if (isLoading && chapters.isEmpty && !_hasCachedData && !isOffline) {
      return buildLoadingShimmer();
    }

    if (chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: buildEmptyWidget(
            dataType: AppStrings.chapters,
            customMessage: isOffline
                ? 'No cached chapters available'
                : 'No chapters available for this course',
            isOffline: isOffline,
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

  Widget _buildExamsList() {
    final exams = _examProvider.getExamsByCourse(_course!.id);
    final isLoading =
        _examsLoading || _examProvider.isLoadingForCourse(_course!.id);

    // Show shimmer only if loading and no exams AND no cached data
    if (isLoading && exams.isEmpty && !_hasCachedData && !isOffline) {
      return buildLoadingShimmer();
    }

    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingXXL(context)),
          child: buildEmptyWidget(
            dataType: AppStrings.exams,
            customMessage: isOffline
                ? 'No cached exams available'
                : 'No exams available for this course',
            isOffline: isOffline,
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

  @override
  Widget buildContent(BuildContext context) {
    if (_course == null && !_hasCachedData) {
      return buildErrorWidget(
        isOffline
            ? AppStrings.noCachedDataAvailable
            : AppStrings.courseDoesNotExist,
        onRetry: onRefresh,
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: handleRefresh,
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
      child: Column(
        children: [
          if (isOffline && pendingCount > 0)
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
                      '$pendingCount pending change${pendingCount > 1 ? 's' : ''}',
                      style: AppTextStyles.bodySmall(context)
                          .copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          _buildAccessBanner(),
          _buildHeader(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.getDivider(context).withValues(alpha: 0.5),
                  width: 0.5,
                ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChaptersList(),
                _buildExamsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showAppBar: true,
      showRefreshIndicator: false,
    );
  }
}
