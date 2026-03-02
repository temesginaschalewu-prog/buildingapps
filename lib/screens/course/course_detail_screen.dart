import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/chapter/chapter_card.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/exam/exam_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
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
import 'package:familyacademyclient/utils/helpers.dart';
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

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  bool _isFirstLoad = true;

  StreamSubscription? _subscriptionListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeScreen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupListeners();
  }

  void _setupListeners() {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    _subscriptionListener?.cancel();
    _subscriptionListener =
        subscriptionProvider.subscriptionUpdates.listen((_) {
      if (mounted && _category != null) _updateAccessStatus();
    });
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection && mounted) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Future<void> _initializeScreen() async {
    await _checkConnectivity();
    await _loadFromCache();

    if (_course != null && _hasCachedData) {
      setState(() => _isFirstLoad = false);
      if (!_isOffline) {
        _refreshInBackground();
      }
    } else {
      await _loadFreshData();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cachedCourse = await deviceService
          .getCacheItem<Map<String, dynamic>>('course_${widget.courseId}',
              isUserSpecific: true);

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
    } catch (e) {}
  }

  Future<void> _loadFreshData() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() {
        _isOffline = true;
        _isFirstLoad = false;
      });
      return;
    }

    try {
      final courseProvider =
          Provider.of<CourseProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

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
      setState(() => _isOffline = true);
    } finally {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<Course?> _findCourse(
      CourseProvider courseProvider, CategoryProvider categoryProvider) async {
    for (final category in categoryProvider.categories) {
      final courses = courseProvider.getCoursesByCategory(category.id);
      final foundCourse = courses.firstWhere((c) => c.id == widget.courseId,
          orElse: () =>
              Course(id: 0, name: '', categoryId: 0, chapterCount: 0));
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
      final courseProvider =
          Provider.of<CourseProvider>(context, listen: false);
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }
      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadChapters(forceRefresh: true);
      await _loadExams(forceRefresh: true);
      await _saveToCache();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      _refreshController.refreshFailed();
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final courseProvider =
          Provider.of<CourseProvider>(context, listen: false);
      if (_course != null && _category != null) {
        await courseProvider.refreshCoursesWithAccessCheck(
            _category!.id, _hasAccess);
      }
      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadChapters(forceRefresh: true);
      await _loadExams(forceRefresh: true);
      await _saveToCache();

      setState(() => _isOffline = false);
      showTopSnackBar(context, 'Course updated');
    } catch (e) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() => _isRefreshing = false);
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

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
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final newAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(_category!.id);
    if (newAccess != _hasAccess && mounted) {
      setState(() => _hasAccess = newAccess);
      await _saveToCache();
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    try {
      await paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !_isOffline);
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
            categoryName: ''),
      );
      _rejectionReason =
          recentRejected.id != 0 ? recentRejected.rejectionReason : null;
    } catch (e) {}
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    if (_course == null) return;
    final chapterProvider =
        Provider.of<ChapterProvider>(context, listen: false);
    await chapterProvider.loadChaptersByCourse(_course!.id,
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_course == null) return;
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    await examProvider.loadExamsByCourse(_course!.id,
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _saveToCache() async {
    if (_course == null) return;
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
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
          isUserSpecific: true);
    } catch (e) {}
  }

  void _handleChapterTap(Chapter chapter) {
    if (chapter.isFree || _hasAccess) {
      context.push('/chapter/${chapter.id}', extra: {
        'chapter': chapter,
        'course': _course,
        'category': _category,
        'hasAccess': _hasAccess
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
      showTopSnackBar(context, 'Category not found', isError: true);
      return;
    }

    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(),
            const SizedBox(height: 20),
            _buildPaymentDialogContent(
              icon: Icons.lock_open_rounded,
              iconColor: AppColors.telegramBlue,
              title: 'Unlock Content',
              message: 'Purchase "${_category!.name}" to access all content',
              buttonText: 'Purchase Access',
              onButtonPressed: () {
                Navigator.pop(context);
                context.push('/payment', extra: {
                  'category': _category,
                  'paymentType': _hasAccess ? 'repayment' : 'first_time'
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectedPaymentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(),
            const SizedBox(height: 20),
            _buildPaymentDialogContent(
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.telegramRed,
              title: 'Payment Rejected',
              message: _rejectionReason != null
                  ? 'Reason: $_rejectionReason'
                  : 'Your previous payment was rejected.',
              buttonText: 'Pay Now',
              onButtonPressed: () {
                Navigator.pop(context);
                context.push('/payment', extra: {
                  'category': _category,
                  'paymentType': 'first_time',
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPendingPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.statusPending.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.statusPending,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment Pending',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have a pending payment for ${_category?.name}. Please wait for admin verification (1-3 working days).',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _buildGradientButton(
                      label: 'OK',
                      onPressed: () => Navigator.pop(context),
                      gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBottomSheet({required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildPaymentDialogContent({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessBanner() {
    if (_category == null) return const SizedBox.shrink();

    if (_category!.isFree) {
      return _buildStatusBanner(
        icon: Icons.lock_open_rounded,
        color: AppColors.telegramGreen,
        title: 'Free Category',
        message: 'All content is free and accessible',
        backgroundColor: AppColors.greenFaded,
        borderColor: AppColors.telegramGreen.withValues(alpha: 0.3),
      );
    }

    if (_hasAccess) {
      return _buildStatusBanner(
        icon: Icons.check_circle_rounded,
        color: AppColors.telegramGreen,
        title: 'Full Access',
        message: 'You have access to all content in this course',
        backgroundColor: AppColors.greenFaded,
        borderColor: AppColors.telegramGreen.withValues(alpha: 0.3),
      );
    }

    if (_hasPendingPayment) {
      return _buildStatusBanner(
        icon: Icons.schedule_rounded,
        color: AppColors.statusPending,
        title: 'Payment Pending',
        message: 'Please wait for admin verification (1-3 working days)',
        backgroundColor: AppColors.orangeFaded,
        borderColor: AppColors.statusPending.withValues(alpha: 0.3),
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
        backgroundColor: AppColors.redFaded,
        borderColor: AppColors.telegramRed.withValues(alpha: 0.3),
      );
    }

    return _buildStatusBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: 'Limited Access',
      message: 'Free chapters only. Purchase to unlock all content.',
      actionText: 'Purchase',
      onAction: _showPaymentDialog,
      backgroundColor: AppColors.blueFaded,
      borderColor: AppColors.telegramBlue.withValues(alpha: 0.3),
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        ),
        vertical: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            )),
            decoration: BoxDecoration(
              color: backgroundColor ?? color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor ?? color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionText != null && onAction != null) ...[
                  const SizedBox(width: 12),
                  _buildGlassButton(
                    label: actionText,
                    onPressed: onAction,
                    color: color,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: color.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

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
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            width: 200,
            height: 24,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
            highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad && !_hasCachedData) return _buildSkeletonLoader();

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.telegramRed.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.telegramRed.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Course not found',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOffline
                          ? 'No cached data available. Please check your connection.'
                          : 'The course you\'re looking for doesn\'t exist.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildGradientButton(
                      label: 'Retry',
                      onPressed: _manualRefresh,
                      gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                    ),
                  ],
                ),
              ),
            ),
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
            letterSpacing: -0.3,
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
            const Padding(
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
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_rounded), text: 'Chapters'),
                Tab(icon: Icon(Icons.quiz_rounded), text: 'Exams'),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.getBackground(context).withValues(alpha: 0.95),
              AppColors.getBackground(context),
            ],
          ),
        ),
        child: SmartRefresher(
          controller: _refreshController,
          onRefresh: _manualRefresh,
          header: const WaterDropHeader(
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
              SliverToBoxAdapter(child: _buildAccessBanner()),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChaptersList(chapters),
                    _buildExamsList(exams),
                  ],
                ),
              ),
            ],
          ),
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
        mobile: 16,
        tablet: 20,
        desktop: 24,
      )),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
          child: ChapterCard(
            chapter: chapter,
            courseId: _course!.id,
            categoryId: _category?.id ?? 0,
            categoryName: _category?.name ?? 'Category',
            onTap: () => _handleChapterTap(chapter),
            index: index,
          ),
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
        mobile: 16,
        tablet: 20,
        desktop: 24,
      )),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            ),
          ),
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
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    _subscriptionListener?.cancel();
    super.dispose();
  }
}
