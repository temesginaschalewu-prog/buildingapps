// lib/screens/category/category_detail_screen.dart
// COMPLETE FINAL VERSION - PROPER SHIMMER & LOADING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/category_model.dart';
import '../../models/payment_model.dart';
import '../../services/device_service.dart';
import '../../services/snackbar_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/access_banner.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final Category? category;

  const CategoryDetailScreen(
      {super.key, required this.categoryId, this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen>
    with BaseScreenMixin<CategoryDetailScreen>, TickerProviderStateMixin {
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  String? _rejectionReason;

  bool _hasCachedData = false;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;

  final RefreshController _refreshController = RefreshController();

  late CategoryProvider _categoryProvider;
  late CourseProvider _courseProvider;
  late SubscriptionProvider _subscriptionProvider;
  late PaymentProvider _paymentProvider;

  @override
  String get screenTitle => _category?.name ?? AppStrings.category;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : AppStrings.categoryDetails;

  // ✅ CRITICAL: Only show loading if no cached data AND loading
  @override
  bool get isLoading => _isLoading && !_hasCachedData;

  @override
  bool get hasCachedData => _hasCachedData;

  @override
  dynamic get errorMessage =>
      _category == null ? AppStrings.categoryNotFound : null;

  // ✅ Shimmer type for category detail (courses)
  @override
  ShimmerType get shimmerType => ShimmerType.courseCard;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoryProvider = Provider.of<CategoryProvider>(context);
    _courseProvider = Provider.of<CourseProvider>(context);
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    _paymentProvider = Provider.of<PaymentProvider>(context);

    _subscriptionProvider.subscriptionUpdates.listen((_) {
      if (isMounted && _category != null) _updateAccessStatus();
    });

    // Mark as loaded if we have data
    if (_category != null && _hasCachedData) {
      _hasLoadedOnce = true;
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadFromCache();

    if (_category != null && _hasCachedData) {
      if (isMounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
      unawaited(_loadCourses());
      if (!isOffline) unawaited(_refreshInBackground());
    } else {
      await _loadFreshData();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final cachedCategory =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        'category_${widget.categoryId}',
        isUserSpecific: true,
      );

      if (cachedCategory != null) {
        _category = Category.fromJson(cachedCategory['category']);
        _hasAccess = cachedCategory['has_access'] ?? false;
        _hasPendingPayment = cachedCategory['has_pending_payment'] ?? false;
        _rejectionReason = cachedCategory['rejection_reason'];
        _hasCachedData = true;
        debugLog('CategoryDetail', '✅ Loaded from cache');
      } else {
        if (_categoryProvider.categories.isNotEmpty) {
          _category = _categoryProvider.getCategoryById(widget.categoryId);
          if (_category != null) _hasCachedData = true;
        }
      }
    } catch (e) {
      debugLog('CategoryDetail', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    if (!isOffline) {
      try {
        if (_categoryProvider.categories.isEmpty) {
          await _categoryProvider.loadCategories();
        }
        if (_categoryProvider.categories.isEmpty && !isOffline) {
          await _categoryProvider.loadCategories(forceRefresh: true);
        }

        _category = _categoryProvider.getCategoryById(widget.categoryId);
        if (_category == null) throw Exception(AppStrings.categoryNotFound);

        await _checkAccessStatus();
        await _loadCourses();

        if (isMounted) {
          setState(() {
            _isLoading = false;
            _hasLoadedOnce = true;
          });
        }
        await _saveToCache();
        if (!isOffline) unawaited(_refreshPaymentInfoInBackground());
      } catch (e) {
        debugLog('CategoryDetail', 'Error loading fresh data: $e');
        if (isMounted) setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshInBackground() async {
    if (isRefreshing) return;

    try {
      await _categoryProvider.loadCategories(forceRefresh: true);
      if (!isMounted) return;

      final freshCategory =
          _categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      if (!isMounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (!isMounted) return;

      await _loadCourses(forceRefresh: true);
      if (!isMounted) return;

      await _saveToCache();
      if (isMounted) setState(() {});
    } catch (e) {
      debugLog('CategoryDetail', 'Background refresh error: $e');
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
      await _categoryProvider.loadCategories(
          forceRefresh: true, isManualRefresh: true);
      if (!isMounted) return;

      final freshCategory =
          _categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      if (!isMounted) return;

      await _loadPaymentInfo(forceRefresh: true, isManualRefresh: true);
      if (!isMounted) return;

      await _loadCourses(forceRefresh: true, isManualRefresh: true);
      if (!isMounted) return;

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
          .checkHasActiveSubscriptionForCategory(widget.categoryId);
    } else {
      _hasAccess = _subscriptionProvider
          .hasActiveSubscriptionForCategory(widget.categoryId);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;
    final newAccess = _subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);
    if (newAccess != _hasAccess && isMounted) {
      setState(() => _hasAccess = newAccess);
      unawaited(_saveToCache());
    }
  }

  Future<void> _loadPaymentInfo(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_category == null) return;
    try {
      await _paymentProvider.loadPayments(
          forceRefresh: forceRefresh && !isOffline,
          isManualRefresh: isManualRefresh);
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
      debugLog('CategoryDetail', 'Error loading payment info: $e');
    }
  }

  bool _matchesPaymentToCategory(Payment payment) {
    if (_category == null) return false;
    if (payment.categoryId != null && payment.categoryId == _category!.id)
      return true;
    return payment.categoryName.toLowerCase() == _category!.name.toLowerCase();
  }

  Future<void> _refreshPaymentInfoInBackground() async {
    await _loadPaymentInfo();
    if (!isMounted) return;
    setState(() {});
    unawaited(_saveToCache());
  }

  Future<void> _loadCourses(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_category == null) return;

    if (isOffline) {
      await _courseProvider.loadCoursesByCategory(widget.categoryId,
          hasAccess: _hasAccess);
      return;
    }

    await _courseProvider.loadCoursesByCategory(
      widget.categoryId,
      forceRefresh: forceRefresh,
      hasAccess: _hasAccess,
      isManualRefresh: isManualRefresh,
    );
  }

  Future<void> _saveToCache() async {
    if (_category == null) return;
    try {
      final deviceService = context.read<DeviceService>();
      deviceService.saveCacheItem(
        'category_${widget.categoryId}',
        {
          'category': _category!.toJson(),
          'has_access': _hasAccess,
          'has_pending_payment': _hasPendingPayment,
          'rejection_reason': _rejectionReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        ttl: const Duration(hours: 1),
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('CategoryDetail', 'Error saving to cache: $e');
    }
  }

  void _handlePaymentAction() {
    if (_category == null) return;

    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.makePayment);
      return;
    }

    if (_hasPendingPayment) {
      _showPendingPaymentDialog();
      return;
    }
    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    final bool hasExpiredSubscription =
        _subscriptionProvider.allSubscriptions.any(
      (sub) => sub.categoryId == _category!.id && sub.isExpired,
    );

    final String paymentType =
        hasExpiredSubscription ? 'repayment' : 'first_time';

    context.push('/payment',
        extra: {'category': _category, 'paymentType': paymentType});
  }

  void _showPendingPaymentDialog() {
    AppDialog.info(
      context: context,
      title: AppStrings.paymentPending,
      message:
          '${AppStrings.youHavePendingPayment} ${_category?.name}. ${AppStrings.pleaseWaitForVerification}',
    );
  }

  void _showRejectedPaymentDialog() {
    AppDialog.warning(
      context: context,
      title: AppStrings.paymentRejected,
      message: _rejectionReason != null
          ? '${AppStrings.reason}: $_rejectionReason'
          : AppStrings.yourPaymentWasRejected,
    ).then((_) {
      context.push('/payment', extra: {
        'category': _category,
        'paymentType': 'first_time',
      });
    });
  }

  Widget _buildAccessBanner() {
    if (_category == null) return const SizedBox.shrink();

    if (_category!.isFree) return AccessBanner.freeCategory();
    if (_hasAccess) return AccessBanner.fullAccess();
    if (_hasPendingPayment) return AccessBanner.paymentPending();
    if (_rejectionReason != null) {
      return AccessBanner.paymentRejected(
        reason: _rejectionReason!,
        onPayNow: _handlePaymentAction,
      );
    }
    return AccessBanner.limitedAccess(onPurchase: _handlePaymentAction);
  }

  Widget _buildHeader() {
    if (_category == null) return const SizedBox.shrink();

    final headerHeight = ScreenSize.responsiveDouble(
      context: context,
      mobile: 200.0,
      tablet: 250.0,
      desktop: 300.0,
    );

    return Stack(
      children: [
        SizedBox(
          height: headerHeight,
          width: double.infinity,
          child: isOffline
              ? _buildLocalPlaceholder()
              : (_category!.imageUrl != null && _category!.imageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: _category!.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildHeaderShimmer(),
                      errorWidget: (context, url, error) =>
                          _buildLocalPlaceholder(),
                    )
                  : _buildLocalPlaceholder(),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7)
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: ResponsiveValues.spacingXL(context),
          left: ResponsiveValues.spacingL(context),
          right: ResponsiveValues.spacingL(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _category!.name,
                      style: AppTextStyles.displaySmall(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isOffline)
                    Padding(
                      padding: EdgeInsets.only(
                          left: ResponsiveValues.spacingS(context)),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: ResponsiveValues.iconSizeS(context),
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
              if (_category!.description != null &&
                  _category!.description!.isNotEmpty)
                Padding(
                  padding:
                      EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
                  child: Text(
                    _category!.description!,
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_category!.price != null &&
                  _category!.price! > 0 &&
                  !isOffline) ...[
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingM(context),
                    vertical: ResponsiveValues.spacingXS(context),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue,
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_money,
                          size: 16, color: Colors.white),
                      Text(
                        _category!.priceDisplay,
                        style: AppTextStyles.labelSmall(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalPlaceholder() {
    if (_category == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramBlue.withValues(alpha: 0.8),
            AppColors.telegramPurple.withValues(alpha: 0.8)
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveValues.avatarSizeLarge(context),
              height: ResponsiveValues.avatarSizeLarge(context),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: Center(
                child: Text(
                  _category!.initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveValues.fontCategoryInitials(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              _category!.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveValues.fontCategoryTitle(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderShimmer() => const AppShimmer(type: ShimmerType.rectangle);

  @override
  Widget buildContent(BuildContext context) {
    final courses = _courseProvider.getCoursesByCategory(widget.categoryId);
    final isLoadingCourses =
        _courseProvider.isLoadingCategory(widget.categoryId);

    if (_category == null && !_hasCachedData) {
      return buildErrorWidget(
        isOffline
            ? AppStrings.noCachedDataAvailable
            : AppStrings.categoryDoesNotExist,
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
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildAccessBanner()),
          if (isOffline && pendingCount > 0)
            SliverToBoxAdapter(
              child: Container(
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
                        AppStrings.pendingChangesLabel(pendingCount),
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: ResponsiveValues.screenPadding(context),
            sliver: SliverToBoxAdapter(
              child: Text(
                AppStrings.courses,
                style: AppTextStyles.titleLarge(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: ResponsiveValues.screenPadding(context),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Show shimmer only if loading and no courses AND no cached data
                  if ((isLoading || isLoadingCourses) &&
                      courses.isEmpty &&
                      !_hasCachedData &&
                      !isOffline) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingL(context)),
                      child: AppShimmer(
                          type: ShimmerType.courseCard, index: index),
                    );
                  }

                  if (index < courses.length) {
                    final course = courses[index];
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingL(context)),
                      child: CourseCard(
                        course: course,
                        categoryId: widget.categoryId,
                        onTap: () =>
                            context.push('/course/${course.id}', extra: {
                          'course': course,
                          'category': _category,
                          'hasAccess': _hasAccess,
                        }),
                        index: index,
                      ),
                    );
                  }

                  if (!(isLoading || isLoadingCourses) &&
                      courses.isEmpty &&
                      index == 0) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingXXL(context)),
                        child: buildEmptyWidget(
                          dataType: AppStrings.courses,
                          customMessage: isOffline
                              ? AppStrings.noCachedCourses
                              : AppStrings.coursesWillAppearHere,
                          isOffline: isOffline,
                        ),
                      ),
                    );
                  }

                  return null;
                },
                childCount: courses.isNotEmpty
                    ? courses.length
                    : (isLoading || isLoadingCourses ? 5 : 1),
              ),
            ),
          ),
          SliverToBoxAdapter(
              child: SizedBox(height: ResponsiveValues.spacingXXL(context))),
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
