import 'dart:async';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/chapter/chapter_card.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/common/error_widget.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/exam/exam_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/chapter_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:shimmer/shimmer.dart';

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

  // Offline-first flags
  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  bool _isFirstLoad = true;

  StreamSubscription? _subscriptionListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  void _setupListeners() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    _subscriptionListener?.cancel();
    _subscriptionListener =
        subscriptionProvider.subscriptionUpdates.listen((_) {
      if (mounted && _category != null) {
        _updateAccessStatus();
      }
    });
  }

  // 🎯 Telegram-style cache-first loading
  Future<void> _initializeScreen() async {
    // First, try to load from cache
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      debugLog('CourseDetail', '📦 Showing cached course data');
      setState(() {
        _isFirstLoad = false;
      });

      // Refresh in background
      _refreshInBackground();
    } else {
      // No cache, load fresh
      await _loadFreshData();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(
        context,
        listen: false,
      );

      // Try to get cached course
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

        debugLog('CourseDetail', '✅ Loaded course from cache');
      } else if (widget.course != null) {
        _course = widget.course;
        _category = widget.category;
        _hasAccess = widget.hasAccess ?? false;
        _hasCachedData = true;
      }
    } catch (e) {
      debugLog('CourseDetail', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    try {
      debugLog('CourseDetail', '🚀 Loading fresh data...');

      final courseProvider = Provider.of<CourseProvider>(
        context,
        listen: false,
      );
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      // Find the course if not provided
      if (_course == null) {
        _course = await _findCourse(courseProvider, categoryProvider);
      }

      if (_course == null) {
        throw Exception('Course not found');
      }

      // Get category info
      if (_category == null && _course!.categoryId > 0) {
        _category = categoryProvider.getCategoryById(_course!.categoryId);
      }

      // Check access status
      await _checkAccessStatus();

      // Load payment info
      await _loadPaymentInfo();

      // Load chapters and exams in parallel
      await Future.wait([
        _loadChapters(),
        _loadExams(),
      ]);

      // Save to cache
      await _saveToCache();

      debugLog('CourseDetail', '✅ Fresh data loaded');
    } catch (e) {
      debugLog('CourseDetail', '❌ Error loading fresh data: $e');
      setState(() {
        _isOffline = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<Course?> _findCourse(
    CourseProvider courseProvider,
    CategoryProvider categoryProvider,
  ) async {
    for (final category in categoryProvider.categories) {
      final courses = courseProvider.getCoursesByCategory(category.id);
      final foundCourse = courses.firstWhere(
        (c) => c.id == widget.courseId,
        orElse: () => Course(
          id: 0,
          name: '',
          categoryId: 0,
          chapterCount: 0,
        ),
      );

      if (foundCourse.id > 0) {
        if (_category == null) {
          _category = category;
        }
        return foundCourse;
      }
    }
    return null;
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugLog('CourseDetail', '🔄 Background refresh started');

    try {
      final courseProvider = Provider.of<CourseProvider>(
        context,
        listen: false,
      );

      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
          _category!.id,
          _hasAccess,
        );
      }

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadChapters(forceRefresh: true);
      await _loadExams(forceRefresh: true);
      await _saveToCache();

      debugLog('CourseDetail', '✅ Background refresh complete');
    } catch (e) {
      debugLog('CourseDetail', 'Background refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final courseProvider = Provider.of<CourseProvider>(
        context,
        listen: false,
      );

      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
          _category!.id,
          _hasAccess,
        );
      }

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadChapters(forceRefresh: true);
      await _loadExams(forceRefresh: true);
      await _saveToCache();

      setState(() {
        _isOffline = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course updated'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugLog('CourseDetail', 'Manual refresh error: $e');
      setState(() {
        _isOffline = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed, using cached data'),
          backgroundColor: AppColors.telegramRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;

    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    if (forceCheck) {
      _hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(_category!.id);
    } else {
      _hasAccess =
          subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;

    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final newAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);

    if (newAccess != _hasAccess && mounted) {
      setState(() {
        _hasAccess = newAccess;
      });
      await _saveToCache();
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;

    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );

    try {
      await paymentProvider.loadPayments(forceRefresh: forceRefresh);

      final pendingPayments = paymentProvider.getPendingPayments();
      _hasPendingPayment = pendingPayments.any((payment) =>
          payment.categoryName.toLowerCase() == _category!.name.toLowerCase());

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
      debugLog('CourseDetail', 'Error loading payment info: $e');
    }
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null) return;

    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );

    await chapterProvider.loadChaptersByCourse(
      _course!.id,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null) return;

    final examProvider = Provider.of<ExamProvider>(
      context,
      listen: false,
    );

    await examProvider.loadExamsByCourse(
      _course!.id,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _saveToCache() async {
    if (_course == null) return;

    try {
      final deviceService = Provider.of<DeviceService>(
        context,
        listen: false,
      );

      final cacheData = {
        'course': _course!.toJson(),
        'category': _category?.toJson(),
        'has_access': _hasAccess,
        'has_pending_payment': _hasPendingPayment,
        'rejection_reason': _rejectionReason,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await deviceService.saveCacheItem(
        'course_${widget.courseId}',
        cacheData,
        ttl: Duration(hours: 1),
        isUserSpecific: true,
      );

      debugLog('CourseDetail', '✅ Saved course to cache');
    } catch (e) {
      debugLog('CourseDetail', 'Error saving to cache: $e');
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
      showSnackBar(context, 'Category not found', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppThemes.borderRadiusLarge),
            topRight: Radius.circular(AppThemes.borderRadiusLarge),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),

              // Icon and title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: AppColors.telegramBlue,
                      size: AppThemes.iconSizeL,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock Content',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: AppThemes.spacingXS),
                        Text(
                          'Purchase "${_category!.name}" to access all content',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppThemes.spacingXL),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/payment',
                      extra: {
                        'category': _category,
                        'paymentType': _hasAccess ? 'repayment' : 'first_time',
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                  ),
                  child: Text(
                    'Purchase Access',
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.getTextSecondary(context),
                  ),
                  child: Text(
                    'Not Now',
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingPaymentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppThemes.borderRadiusLarge),
            topRight: Radius.circular(AppThemes.borderRadiusLarge),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),

              // Icon and title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.statusPending,
                      size: AppThemes.iconSizeL,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Pending',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: AppThemes.spacingXS),
                        Text(
                          'Your payment is being verified (1-3 working days)',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppThemes.spacingXL),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                  ),
                  child: Text(
                    'View Payments',
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.getTextSecondary(context),
                  ),
                  child: Text(
                    'Close',
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌐 Offline banner
  Widget _buildOfflineBanner() {
    if (!_isOffline && !_hasCachedData) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        ),
        vertical: AppThemes.spacingS,
      ),
      padding: EdgeInsets.all(AppThemes.spacingM),
      decoration: BoxDecoration(
        color: _isOffline
            ? AppColors.telegramYellow.withOpacity(0.1)
            : AppColors.telegramBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: _isOffline
              ? AppColors.telegramYellow.withOpacity(0.3)
              : AppColors.telegramBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOffline
                ? Icons.signal_wifi_off_rounded
                : Icons.cloud_done_rounded,
            color:
                _isOffline ? AppColors.telegramYellow : AppColors.telegramBlue,
            size: 20,
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              _isOffline
                  ? 'Offline mode - showing cached content'
                  : 'Using cached data - refreshing in background',
              style: AppTextStyles.bodySmall.copyWith(
                color: _isOffline
                    ? AppColors.telegramYellow
                    : AppColors.telegramBlue,
              ),
            ),
          ),
          if (_isOffline)
            TextButton(
              onPressed: _manualRefresh,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.telegramBlue,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }

  // 🎨 Access banner
  Widget _buildAccessBanner() {
    if (_category == null) return SizedBox.shrink();

    if (_category!.isFree) {
      return _buildStatusBanner(
        icon: Icons.lock_open_rounded,
        color: AppColors.telegramGreen,
        title: 'Free Category',
        message: 'All content is free and accessible',
      );
    }

    if (_hasAccess) {
      return _buildStatusBanner(
        icon: Icons.check_circle_rounded,
        color: AppColors.telegramGreen,
        title: 'Full Access',
        message: 'You have access to all content in this course',
      );
    }

    if (_hasPendingPayment) {
      return _buildStatusBanner(
        icon: Icons.schedule_rounded,
        color: AppColors.statusPending,
        title: 'Payment Pending',
        message: 'Please wait for admin verification (1-3 working days)',
        actionText: 'View Payments',
        onAction: () => context.go('/profile'),
      );
    }

    if (_rejectionReason != null) {
      return _buildStatusBanner(
        icon: Icons.error_outline_rounded,
        color: AppColors.telegramRed,
        title: 'Payment Rejected',
        message: 'Reason: $_rejectionReason',
        actionText: 'Pay Now',
        onAction: _showPaymentDialog,
      );
    }

    return _buildStatusBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: 'Limited Access',
      message: 'Free chapters only. Purchase to unlock all content.',
      actionText: 'Purchase',
      onAction: _showPaymentDialog,
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        ),
        vertical: AppThemes.spacingS,
      ),
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppThemes.spacingM),
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: AppThemes.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemes.spacingL,
                  vertical: AppThemes.spacingS,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🦴 Skeleton loader for first load
  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 200,
            height: 24,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Chapters'),
                Tab(text: 'Exams'),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppThemes.spacingL),
        child: ListView.separated(
          itemCount: 5,
          separatorBuilder: (_, __) => SizedBox(height: AppThemes.spacingL),
          itemBuilder: (context, index) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusLarge),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton loader on first load with no cache
    if (_isFirstLoad && !_hasCachedData) {
      return _buildSkeletonLoader();
    }

    // Show error if no course
    if (_course == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Course not found',
            message: _isOffline
                ? 'No cached data available. Please check your connection.'
                : 'The course you\'re looking for doesn\'t exist.',
            type: EmptyStateType.error,
            actionText: 'Retry',
            onAction: _manualRefresh,
          ),
        ),
      );
    }

    final chapterProvider = Provider.of<ChapterProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);
    final chapters = chapterProvider.getChaptersByCourse(_course!.id);
    final exams = examProvider.getExamsByCourse(_course!.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _course!.name,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Icon(Icons.menu_book_rounded),
                  text: 'Chapters',
                ),
                Tab(
                  icon: Icon(Icons.quiz_rounded),
                  text: 'Exams',
                ),
              ],
              labelStyle: AppTextStyles.labelMedium,
              unselectedLabelStyle: AppTextStyles.labelMedium,
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
            ),
          ),
        ),
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _manualRefresh,
        enablePullDown: true,
        header: WaterDropHeader(
          waterDropColor: AppColors.telegramBlue,
          refresh: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
            ),
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Offline banner
            SliverToBoxAdapter(
              child: _buildOfflineBanner(),
            ),

            // Access banner
            SliverToBoxAdapter(
              child: _buildAccessBanner(),
            ),

            // Tab content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Chapters tab
                  _buildChaptersList(chapters),

                  // Exams tab
                  _buildExamsList(exams),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildChaptersList(List<Chapter> chapters) {
    if (chapters.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.menu_book_rounded,
          title: 'No Chapters Yet',
          message: _isOffline
              ? 'No cached chapters available. Connect to load chapters.'
              : 'Chapters will appear here when available.',
          type: EmptyStateType.noData,
          actionText: 'Retry',
          onAction: _manualRefresh,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return ChapterCard(
          chapter: chapter,
          courseId: _course!.id,
          categoryId: _category?.id ?? 0,
          categoryName: _category?.name ?? 'Category',
          onTap: () => _handleChapterTap(chapter),
        );
      },
    );
  }

  Widget _buildExamsList(List<Exam> exams) {
    if (exams.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.quiz_rounded,
          title: 'No Exams Yet',
          message: _isOffline
              ? 'No cached exams available. Connect to load exams.'
              : 'Exams will appear here when available.',
          type: EmptyStateType.noData,
          actionText: 'Retry',
          onAction: _manualRefresh,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Padding(
          padding: EdgeInsets.only(bottom: AppThemes.spacingL),
          child: ExamCard(
            exam: exam,
            onTap: () => _handleExamTap(exam),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    _subscriptionListener?.cancel();
    super.dispose();
  }
}
