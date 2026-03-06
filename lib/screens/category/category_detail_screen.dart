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
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_dialog.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_enums.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final Category? category;

  const CategoryDetailScreen(
      {super.key, required this.categoryId, this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  String? _rejectionReason;

  bool _isLoadingCategory = true;
  bool _isLoadingCourses = false;
  bool _isLoadingPayments = false;
  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;

  final RefreshController _refreshController = RefreshController();
  StreamSubscription? _subscriptionListener;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
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
        setState(() => _isOffline = !isOnline);
        if (isOnline && !_isRefreshing && _category != null) {
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
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  Future<void> _initializeScreen() async {
    await _checkConnectivity();

    setState(() => _isLoadingCategory = true);

    await _loadFromCache();

    if (_category != null && _hasCachedData) {
      setState(() => _isLoadingCategory = false);

      if (!_isOffline) {
        _refreshInBackground();
      }
    } else {
      await _loadFreshData();
      setState(() => _isLoadingCategory = false);
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
      } else {
        final categoryProvider = context.read<CategoryProvider>();
        if (categoryProvider.categories.isNotEmpty) {
          _category = categoryProvider.getCategoryById(widget.categoryId);
          if (_category != null) _hasCachedData = true;
        }
      }
    } catch (e) {
      debugLog('CategoryDetail', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      return;
    }

    try {
      final categoryProvider = context.read<CategoryProvider>();

      debugLog('CategoryDetail',
          '🔍 Calling getCategoryByIdAsync for ${widget.categoryId}');

      _category =
          await categoryProvider.getCategoryByIdAsync(widget.categoryId);

      debugLog('CategoryDetail',
          '✅ getCategoryByIdAsync returned: ${_category != null}');

      if (_category == null) throw Exception('Category not found');

      await _checkAccessStatus();
      await _loadPaymentInfo();
      await _loadCourses();
      await _saveToCache();
    } catch (e) {
      debugLog('CategoryDetail', 'Error loading fresh data: $e');
      setState(() => _isOffline = true);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final categoryProvider = context.read<CategoryProvider>();
      await categoryProvider.loadCategories(forceRefresh: true);

      if (!mounted) return;

      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      if (!mounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (!mounted) return;

      await _loadCourses(forceRefresh: true);
      if (!mounted) return;

      await _saveToCache();

      if (mounted) setState(() {});
    } finally {
      if (mounted) _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() {
        _isOffline = true;
        _isRefreshing = false;
      });
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context);
      return;
    }

    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final categoryProvider = context.read<CategoryProvider>();
      await categoryProvider.loadCategories(forceRefresh: true);

      if (!mounted) return;

      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      if (!mounted) return;

      await _loadPaymentInfo(forceRefresh: true);
      if (!mounted) return;

      await _loadCourses(forceRefresh: true);
      if (!mounted) return;

      await _saveToCache();

      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, 'Category updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOffline = true);
      SnackbarService().showError(context, 'Refresh failed, using cached data');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();

    if (!_isOffline && forceCheck) {
      _hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(widget.categoryId);
    } else {
      _hasAccess = subscriptionProvider
          .hasActiveSubscriptionForCategory(widget.categoryId);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final newAccess = subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);
    if (newAccess != _hasAccess && mounted) {
      setState(() => _hasAccess = newAccess);
      await _saveToCache();
    }
  }

  Future<void> _loadPaymentInfo({bool forceRefresh = false}) async {
    if (_category == null) return;

    setState(() => _isLoadingPayments = true);

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
      debugLog('CategoryDetail', 'Error loading payment info: $e');
    } finally {
      setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    if (_category == null) return;

    setState(() => _isLoadingCourses = true);

    final courseProvider = context.read<CourseProvider>();
    await courseProvider.loadCoursesByCategory(
      widget.categoryId,
      forceRefresh: forceRefresh && !_isOffline,
      hasAccess: _hasAccess,
    );

    setState(() => _isLoadingCourses = false);
  }

  Future<void> _saveToCache() async {
    if (_category == null) return;
    try {
      final deviceService = context.read<DeviceService>();
      await deviceService.saveCacheItem(
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
    if (_hasPendingPayment) {
      _showPendingPaymentDialog();
      return;
    }
    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final subscriptions = subscriptionProvider.allSubscriptions;

    final bool hasExpiredSubscription = subscriptions.any(
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
      title: 'Payment Pending',
      message:
          'You have a pending payment for ${_category?.name}. Please wait for admin verification (1-3 working days).',
    );
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

  Widget _buildAccessBanner() {
    if (_category == null) return const SizedBox.shrink();

    final accessColor = UiHelpers.getCategoryAccessColor(
      isComingSoon: _category!.isComingSoon,
      isFree: _category!.isFree,
      hasActiveSubscription: _hasAccess,
      hasPendingPayment: _hasPendingPayment,
    );

    final accessIcon = UiHelpers.getCategoryAccessIcon(
      isComingSoon: _category!.isComingSoon,
      isFree: _category!.isFree,
      hasActiveSubscription: _hasAccess,
      hasPendingPayment: _hasPendingPayment,
    );

    final accessTitle = UiHelpers.getCategoryAccessLabel(
      isComingSoon: _category!.isComingSoon,
      isFree: _category!.isFree,
      hasActiveSubscription: _hasAccess,
      hasPendingPayment: _hasPendingPayment,
    );

    String message;
    if (_category!.isFree) {
      message = 'All content is free and accessible';
    } else if (_hasAccess) {
      message = 'You have access to all content in this category';
    } else if (_hasPendingPayment) {
      message = 'Please wait for admin verification (1-3 working days)';
    } else if (_rejectionReason != null) {
      message = 'Reason: $_rejectionReason';
    } else {
      message = 'Free chapters only. Purchase to unlock all content.';
    }

    String? actionText;
    VoidCallback? onAction;

    if (_rejectionReason != null) {
      actionText = 'Pay Now';
      onAction = _handlePaymentAction;
    } else if (!_hasAccess && !_hasPendingPayment && !_category!.isFree) {
      actionText = 'Purchase';
      onAction = _handlePaymentAction;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.sectionPadding(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: AppCard.glass(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                decoration: BoxDecoration(
                  color: accessColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context)),
                ),
                child: Icon(accessIcon,
                    size: ResponsiveValues.iconSizeL(context),
                    color: accessColor),
              ),
              SizedBox(width: ResponsiveValues.spacingL(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accessTitle,
                      style: AppTextStyles.titleSmall(context).copyWith(
                          color: accessColor, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      message,
                      style: AppTextStyles.bodySmall(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),
              ),
              if (actionText != null && onAction != null) ...[
                SizedBox(width: ResponsiveValues.spacingM(context)),
                AppButton.glass(label: actionText, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
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
          child:
              (_category!.imageUrl != null && _category!.imageUrl!.isNotEmpty)
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
              Text(
                _category!.name,
                style: AppTextStyles.displaySmall(context)
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              if (_category!.description != null &&
                  _category!.description!.isNotEmpty)
                Padding(
                  padding:
                      EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
                  child: Text(
                    _category!.description!,
                    style: AppTextStyles.bodyLarge(context)
                        .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(height: ResponsiveValues.spacingM(context)),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingM(context),
                      vertical: ResponsiveValues.spacingXS(context),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: ResponsiveValues.spacingXS(context)),
                        Text(
                          '${_category!.courseCount} courses',
                          style: AppTextStyles.labelSmall(context)
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (_category!.price != null && _category!.price! > 0) ...[
                    SizedBox(width: ResponsiveValues.spacingM(context)),
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
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top +
              ResponsiveValues.spacingM(context),
          left: ResponsiveValues.spacingL(context),
          child: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        ),
        if (_isRefreshing)
          Positioned(
            top: MediaQuery.of(context).padding.top +
                ResponsiveValues.spacingM(context),
            right: ResponsiveValues.spacingL(context),
            child: Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle),
              child: Center(
                child: SizedBox(
                  width: ResponsiveValues.iconSizeS(context),
                  height: ResponsiveValues.iconSizeS(context),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              _category!.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderShimmer() {
    return const AppShimmer(type: ShimmerType.rectangle);
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: ScreenSize.responsiveDouble(
                context: context, mobile: 200, tablet: 250, desktop: 300),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(background: _buildHeaderShimmer()),
            leading: AppButton.icon(
                icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: Column(
                children: [
                  const AppShimmer(
                      type: ShimmerType.rectangle, customHeight: 60),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmer(type: ShimmerType.textLine, customWidth: 150),
                      AppShimmer(type: ShimmerType.textLine, customWidth: 50),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingL(context)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: ResponsiveValues.screenPadding(context),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(
                      bottom: ResponsiveValues.spacingL(context)),
                  child: AppShimmer(type: ShimmerType.courseCard, index: index),
                ),
                childCount: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);

    final isCategoryLoading =
        categoryProvider.isLoadingCategory(widget.categoryId) ||
            _isLoadingCategory;

    debugLog('CategoryDetail',
        'Building - isCategoryLoading: $isCategoryLoading, hasCachedData: $_hasCachedData, category: ${_category != null}');

    if (isCategoryLoading || _isLoadingCourses || _isLoadingPayments) {
      debugLog('CategoryDetail',
          'Showing shimmer - loading states: cat:$isCategoryLoading, courses:$_isLoadingCourses, payments:$_isLoadingPayments');
      return _buildSkeletonLoader();
    }

    if (_category == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        ),
        body: Center(
          child: AppEmptyState.error(
            title: 'Category not found',
            message: _isOffline && !_hasCachedData
                ? 'No cached data available. Please check your connection.'
                : 'The category you\'re looking for doesn\'t exist.',
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildAccessBanner()),
              SliverPadding(
                padding: ResponsiveValues.screenPadding(context),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Courses',
                        style: AppTextStyles.titleLarge(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (!_isLoadingCourses &&
                          !_isLoadingPayments &&
                          courses.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingM(context),
                            vertical: ResponsiveValues.spacingXS(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blueFaded,
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context)),
                            border: Border.all(
                                color: AppColors.telegramBlue
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${courses.length}',
                            style: AppTextStyles.labelMedium(context).copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: ResponsiveValues.screenPadding(context),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (_isLoadingCourses && courses.isEmpty) {
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

                      if (!_isLoadingCourses && courses.isEmpty && index == 0) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingXXL(context)),
                            child: AppEmptyState.noData(
                              dataType: 'Courses',
                              customMessage: _isOffline
                                  ? 'No cached courses available. Connect to load courses.'
                                  : 'Courses will appear here when available.',
                              onRefresh: _manualRefresh,
                            ),
                          ),
                        );
                      }

                      return null;
                    },
                    childCount: courses.isNotEmpty
                        ? courses.length
                        : (_isLoadingCourses ? 5 : 1),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                  child:
                      SizedBox(height: ResponsiveValues.spacingXXL(context))),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _connectivitySubscription?.cancel();
    _refreshController.dispose();
    super.dispose();
  }
}
