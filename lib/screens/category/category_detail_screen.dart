import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';
import 'package:shimmer/shimmer.dart';

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

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;

  // FIXED: Set to true by default to show skeleton immediately
  bool _isLoading = true;

  final RefreshController _refreshController = RefreshController();
  StreamSubscription? _subscriptionListener;

  @override
  void initState() {
    super.initState();
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

  Widget _buildLocalPlaceholder() {
    if (_category == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramBlue.withOpacity(0.8),
            AppColors.telegramPurple.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
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
            const SizedBox(height: 16),
            Text(_category!.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeScreen() async {
    // Try to load from cache first
    await _loadFromCache();

    if (_category != null && _hasCachedData) {
      // If we have cached data, show it immediately
      setState(() {
        _isLoading = false;
      });
      // Then refresh in background
      _refreshInBackground();
    } else {
      // If no cache, load fresh data
      await _loadFreshData();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cachedCategory = await deviceService
          .getCacheItem<Map<String, dynamic>>('category_${widget.categoryId}',
              isUserSpecific: true);

      if (cachedCategory != null) {
        _category = Category.fromJson(cachedCategory['category']);
        _hasAccess = cachedCategory['has_access'] ?? false;
        _hasPendingPayment = cachedCategory['has_pending_payment'] ?? false;
        _rejectionReason = cachedCategory['rejection_reason'];
        _hasCachedData = true;
      } else {
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        if (categoryProvider.categories.isNotEmpty) {
          _category = categoryProvider.getCategoryById(widget.categoryId);
          if (_category != null) _hasCachedData = true;
        }
      }
    } catch (e) {}
  }

  Future<void> _loadFreshData() async {
    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (categoryProvider.categories.isEmpty)
        await categoryProvider.loadCategories(forceRefresh: true);

      _category = categoryProvider.getCategoryById(widget.categoryId);
      if (_category == null) throw Exception('Category not found');

      await _checkAccessStatus();
      await _loadPaymentInfo();
      await _loadCourses();
      await _saveToCache();
    } catch (e) {
      setState(() => _isOffline = true);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories(forceRefresh: true);
      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadCourses(forceRefresh: true);
      await _saveToCache();

      if (mounted) setState(() {});
    } catch (e) {
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.loadCategories(forceRefresh: true);
      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) _category = freshCategory;

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadCourses(forceRefresh: true);
      await _saveToCache();

      setState(() => _isOffline = false);
      showTopSnackBar(context, 'Category updated');
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
    _hasAccess = forceCheck
        ? await subscriptionProvider
            .checkHasActiveSubscriptionForCategory(widget.categoryId)
        : subscriptionProvider
            .hasActiveSubscriptionForCategory(widget.categoryId);
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final newAccess = subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);
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
            categoryName: ''),
      );
      _rejectionReason =
          recentRejected.id != 0 ? recentRejected.rejectionReason : null;
    } catch (e) {}
  }

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    if (_category == null) return;
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    await courseProvider.loadCoursesByCategory(widget.categoryId,
        forceRefresh: forceRefresh, hasAccess: _hasAccess);
  }

  Future<void> _saveToCache() async {
    if (_category == null) return;
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
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
          isUserSpecific: true);
    } catch (e) {}
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

    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final subscriptions = subscriptionProvider.allSubscriptions;

    bool hasExpiredSubscription = subscriptions
        .any((sub) => sub.categoryId == _category!.id && sub.isExpired);

    String paymentType = hasExpiredSubscription ? 'repayment' : 'first_time';

    context.push('/payment',
        extra: {'category': _category, 'paymentType': paymentType});
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
                    AppColors.getCard(context).withOpacity(0.4),
                    AppColors.getCard(context).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.statusPending.withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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

  void _showRejectedPaymentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const SizedBox(height: 20),
            _buildDialogContent(
              context,
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

  Widget _buildGlassBottomSheet(BuildContext context, {required Widget child}) {
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
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

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDialogContent(
    BuildContext context, {
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
                color: iconColor.withOpacity(0.1),
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
            color: gradient.first.withOpacity(0.3),
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
        borderColor: AppColors.telegramGreen.withOpacity(0.3),
      );
    }

    if (_hasAccess) {
      return _buildStatusBanner(
        icon: Icons.check_circle_rounded,
        color: AppColors.telegramGreen,
        title: 'Full Access',
        message: 'You have access to all content in this category',
        backgroundColor: AppColors.greenFaded,
        borderColor: AppColors.telegramGreen.withOpacity(0.3),
      );
    }

    if (_hasPendingPayment) {
      return _buildStatusBanner(
        icon: Icons.schedule_rounded,
        color: AppColors.statusPending,
        title: 'Payment Pending',
        message: 'Please wait for admin verification (1-3 working days)',
        backgroundColor: AppColors.orangeFaded,
        borderColor: AppColors.statusPending.withOpacity(0.3),
      );
    }

    if (_rejectionReason != null) {
      return _buildStatusBanner(
        icon: Icons.error_outline_rounded,
        color: AppColors.telegramRed,
        title: 'Payment Rejected',
        message: 'Reason: $_rejectionReason',
        actionText: 'Pay Now',
        onAction: _handlePaymentAction,
        backgroundColor: AppColors.redFaded,
        borderColor: AppColors.telegramRed.withOpacity(0.3),
      );
    }

    return _buildStatusBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: 'Limited Access',
      message: 'Free chapters only. Purchase to unlock all content.',
      actionText: 'Purchase',
      onAction: _handlePaymentAction,
      backgroundColor: AppColors.blueFaded,
      borderColor: AppColors.telegramBlue.withOpacity(0.3),
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
              color: backgroundColor ?? color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor ?? color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
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
        color: color.withOpacity(0.1),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
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

  Widget _buildHeader() {
    if (_category == null) return const SizedBox.shrink();

    final headerHeight = ScreenSize.responsiveValue(
        context: context, mobile: 200.0, tablet: 250.0, desktop: 300.0);

    return Stack(
      children: [
        // Background Image or Gradient
        Container(
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

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)]),
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: AppThemes.spacingXL,
          left: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL),
          right: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_category!.name,
                  style: AppTextStyles.displaySmall.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              if (_category!.description != null &&
                  _category!.description!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: AppThemes.spacingS),
                  child: Text(_category!.description!,
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: Colors.white.withOpacity(0.9)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              SizedBox(height: AppThemes.spacingM),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingM,
                        vertical: AppThemes.spacingXS),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: AppThemes.spacingXS),
                        Text('${_category!.courseCount} courses',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                  if (_category!.price != null && _category!.price! > 0) ...[
                    SizedBox(width: AppThemes.spacingM),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppThemes.spacingM,
                          vertical: AppThemes.spacingXS),
                      decoration: BoxDecoration(
                          color: AppColors.telegramBlue,
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusFull)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money,
                              size: 16, color: Colors.white),
                          Text(_category!.priceDisplay,
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + AppThemes.spacingM,
          left: AppThemes.spacingL,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
            child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop()),
          ),
        ),

        // Refresh Indicator
        if (_isRefreshing)
          Positioned(
            top: MediaQuery.of(context).padding.top + AppThemes.spacingM,
            right: AppThemes.spacingL,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white))),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!.withOpacity(0.3),
      highlightColor: Colors.grey[100]!.withOpacity(0.6),
      period: const Duration(milliseconds: 1500),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.telegramBlue.withOpacity(0.5),
              AppColors.telegramPurple.withOpacity(0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: ScreenSize.responsiveValue(
                context: context, mobile: 200, tablet: 250, desktop: 300),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderShimmer(),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingL),
              child: Column(
                children: [
                  // Banner Shimmer
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.getCard(context).withOpacity(0.4),
                              AppColors.getCard(context).withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title Shimmer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            width: 100,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getCard(context).withOpacity(0.4),
                                  AppColors.getCard(context).withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            width: 40,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getCard(context).withOpacity(0.4),
                                  AppColors.getCard(context).withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: AppThemes.spacingL),
                  child: _buildCourseCardShimmer(index: index),
                ),
                childCount: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCardShimmer({required int index}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon shimmer
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withOpacity(0.3),
                highlightColor: Colors.grey[100]!.withOpacity(0.6),
                period: const Duration(milliseconds: 1500),
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Content shimmer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withOpacity(0.3),
                      highlightColor: Colors.grey[100]!.withOpacity(0.6),
                      period: const Duration(milliseconds: 1500),
                      child: Container(
                        width: double.infinity,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withOpacity(0.3),
                      highlightColor: Colors.grey[100]!.withOpacity(0.6),
                      period: const Duration(milliseconds: 1500),
                      child: Container(
                        width: 150,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withOpacity(0.3),
                          highlightColor: Colors.grey[100]!.withOpacity(0.6),
                          period: const Duration(milliseconds: 1500),
                          child: Container(
                            width: 80,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withOpacity(0.3),
                          highlightColor: Colors.grey[100]!.withOpacity(0.6),
                          period: const Duration(milliseconds: 1500),
                          child: Container(
                            width: 70,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron shimmer
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withOpacity(0.3),
                highlightColor: Colors.grey[100]!.withOpacity(0.6),
                period: const Duration(milliseconds: 1500),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
        duration: AppThemes.animationDurationMedium, delay: (index * 50).ms);
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Show skeleton loader immediately on first load
    if (_isLoading) return _buildSkeletonLoader();

    if (_category == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => context.pop()),
        ),
        body: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.telegramRed.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.telegramRed.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Category not found',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOffline
                          ? 'No cached data available. Please check your connection.'
                          : 'The category you\'re looking for doesn\'t exist.',
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

    final courseProvider = Provider.of<CourseProvider>(context);
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);
    final isLoadingCourses =
        courseProvider.isLoadingCategory(widget.categoryId);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.getBackground(context).withOpacity(0.95),
              AppColors.getBackground(context),
            ],
          ),
        ),
        child: SmartRefresher(
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
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.telegramBlue))),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildAccessBanner()),
              SliverPadding(
                padding: EdgeInsets.all(ScreenSize.responsiveValue(
                    context: context,
                    mobile: AppThemes.spacingL,
                    tablet: AppThemes.spacingXL,
                    desktop: AppThemes.spacingXXL)),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Courses',
                              style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w700)),
                          if (!isLoadingCourses && courses.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppThemes.spacingM,
                                  vertical: AppThemes.spacingXS),
                              decoration: BoxDecoration(
                                  color: AppColors.blueFaded,
                                  borderRadius: BorderRadius.circular(
                                      AppThemes.borderRadiusFull),
                                  border: Border.all(
                                      color: AppColors.telegramBlue
                                          .withOpacity(0.3),
                                      width: 1)),
                              child: Text('${courses.length}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.telegramBlue,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
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
                        desktop: AppThemes.spacingXXL)),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Show shimmer while loading and no courses
                      if (isLoadingCourses && courses.isEmpty) {
                        return _buildCourseCardShimmer(index: index);
                      }
                      // Show actual courses
                      if (index < courses.length) {
                        final course = courses[index];
                        return CourseCard(
                          course: course,
                          categoryId: widget.categoryId,
                          onTap: () => context.push('/course/${course.id}',
                              extra: {
                                'course': course,
                                'category': _category,
                                'hasAccess': _hasAccess
                              }),
                          index: index,
                        );
                      }
                      return null;
                    },
                    childCount: isLoadingCourses && courses.isEmpty
                        ? 5
                        : courses.isEmpty
                            ? 1
                            : courses.length,
                  ),
                ),
              ),
              if (!isLoadingCourses && courses.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: EmptyState(
                      icon: Icons.menu_book_rounded,
                      title: 'No Courses Yet',
                      message: _isOffline
                          ? 'No cached courses available. Connect to load courses.'
                          : 'Courses will appear here when available.',
                      type: EmptyStateType.noData,
                      actionText: 'Retry',
                      onAction: _manualRefresh,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: AppThemes.spacingXXL)),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _refreshController.dispose();
    super.dispose();
  }
}
