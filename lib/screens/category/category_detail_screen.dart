import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';
import 'package:shimmer/shimmer.dart';
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

  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
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

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
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
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: ResponsiveValues.spacingS(context),
            offset: Offset(0, ResponsiveValues.spacingXS(context)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
            ),
            alignment: Alignment.center,
            child: ResponsiveText(
              label,
              style: AppTextStyles.labelLarge(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
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
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      child: Material(
        color: color.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingS(context),
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            ),
            child: ResponsiveText(
              label,
              style: AppTextStyles.labelMedium(context).copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalPlaceholder() {
    if (_category == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramBlue.withValues(alpha: 0.8),
            AppColors.telegramPurple.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ResponsiveColumn(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveValues.avatarSizeLarge(context),
              height: ResponsiveValues.avatarSizeLarge(context),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: ResponsiveText(
                  _category!.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              _category!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

    // Try to load from cache first
    await _loadFromCache();

    if (_category != null && _hasCachedData) {
      // Show cached data immediately, then refresh in background
      setState(() {
        _isLoading = false;
      });

      if (!_isOffline) {
        _refreshInBackground();
      }
    } else {
      // No cache, show shimmer while loading fresh data
      setState(() {
        _isLoading = true;
      });

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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      return;
    }

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.loadCategories(forceRefresh: true);
      }

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
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() {
        _isOffline = true;
        _isRefreshing = false;
      });
      _refreshController.refreshFailed();
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
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
      showTopSnackBar(context, 'Category updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _checkAccessStatus({bool forceCheck = false}) async {
    if (_category == null) return;
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

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

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    if (_category == null) return;
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    await courseProvider.loadCoursesByCategory(widget.categoryId,
        forceRefresh: forceRefresh && !_isOffline, hasAccess: _hasAccess);
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

    final bool hasExpiredSubscription = subscriptions
        .any((sub) => sub.categoryId == _category!.id && sub.isExpired);

    final String paymentType =
        hasExpiredSubscription ? 'repayment' : 'first_time';

    context.push('/payment',
        extra: {'category': _category, 'paymentType': paymentType});
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
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: ResponsiveValues.spacingXXL(context),
        height: ResponsiveValues.spacingXS(context),
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withValues(alpha: 0.3),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
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
    return ResponsiveColumn(
      children: [
        ResponsiveRow(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: ResponsiveIcon(
                icon,
                size: ResponsiveValues.iconSizeL(context),
                color: iconColor,
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.l),
            Expanded(
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    title,
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    message,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ResponsiveSizedBox(height: AppSpacing.xl),
        ResponsiveRow(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                ),
                child: ResponsiveText(
                  'Cancel',
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: AppColors.blueGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPendingPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
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
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
                border: Border.all(
                  color: AppColors.statusPending.withValues(alpha: 0.3),
                ),
              ),
              padding: ResponsiveValues.dialogPadding(context),
              child: ResponsiveColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                      color: AppColors.statusPending.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ResponsiveIcon(
                      Icons.schedule_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.statusPending,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'Payment Pending',
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.s),
                  ResponsiveText(
                    'You have a pending payment for ${_category?.name}. Please wait for admin verification (1-3 working days).',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: _buildGradientButton(
                      label: 'OK',
                      onPressed: () => Navigator.pop(context),
                      gradient: AppColors.blueGradient,
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
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            ResponsiveSizedBox(height: AppSpacing.xl),
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
        message: 'You have access to all content in this category',
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
        onAction: _handlePaymentAction,
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
      onAction: _handlePaymentAction,
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
        horizontal: ResponsiveValues.sectionPadding(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(ResponsiveValues.sectionPadding(context)),
            decoration: BoxDecoration(
              color: backgroundColor ?? color.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
              border: Border.all(
                color: borderColor ?? color.withValues(alpha: 0.3),
              ),
            ),
            child: ResponsiveRow(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: ResponsiveIcon(
                    icon,
                    size: ResponsiveValues.iconSizeL(context),
                    color: color,
                  ),
                ),
                ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        title,
                        style: AppTextStyles.titleSmall(context).copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      ResponsiveSizedBox(height: AppSpacing.xs),
                      ResponsiveText(
                        message,
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actionText != null && onAction != null) ...[
                  ResponsiveSizedBox(width: AppSpacing.m),
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
        // Background Image or Gradient
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

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: ResponsiveValues.spacingXL(context),
          left: ResponsiveValues.spacingL(context),
          right: ResponsiveValues.spacingL(context),
          child: ResponsiveColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                _category!.name,
                style: AppTextStyles.displaySmall(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_category!.description != null &&
                  _category!.description!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: ResponsiveValues.spacingS(context),
                  ),
                  child: ResponsiveText(
                    _category!.description!,
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ResponsiveSizedBox(height: AppSpacing.m),
              ResponsiveRow(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingM(context),
                      vertical: ResponsiveValues.spacingXS(context),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context),
                      ),
                    ),
                    child: ResponsiveRow(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            size: 16, color: Colors.white),
                        ResponsiveSizedBox(width: AppSpacing.xs),
                        ResponsiveText(
                          '${_category!.courseCount} courses',
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_category!.price != null && _category!.price! > 0) ...[
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.telegramBlue,
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context),
                        ),
                      ),
                      child: ResponsiveRow(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money,
                              size: 16, color: Colors.white),
                          ResponsiveText(
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
            ],
          ),
        ),

        // Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top +
              ResponsiveValues.spacingM(context),
          left: ResponsiveValues.spacingL(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
        ),

        // Refresh Indicator
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
                shape: BoxShape.circle,
              ),
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

  Widget _buildHeaderShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.telegramBlue.withValues(alpha: 0.5),
              AppColors.telegramPurple.withValues(alpha: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    final columns = ResponsiveValues.gridColumns(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: ScreenSize.responsiveDouble(
              context: context,
              mobile: 200,
              tablet: 250,
              desktop: 300,
            ),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderShimmer(),
            ),
            leading: Container(
              margin: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: ResponsiveColumn(
                children: [
                  // Banner Shimmer
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        height: ResponsiveValues.spacingXXL(context) * 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.getCard(context).withValues(alpha: 0.4),
                              AppColors.getCard(context).withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  // Title Shimmer
                  ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusSmall(context),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            width: ResponsiveValues.spacingXXXL(context) * 2,
                            height: ResponsiveValues.spacingXL(context),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getCard(context)
                                      .withValues(alpha: 0.4),
                                  AppColors.getCard(context)
                                      .withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            width: ResponsiveValues.spacingXXL(context),
                            height: ResponsiveValues.spacingXL(context),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.getCard(context)
                                      .withValues(alpha: 0.4),
                                  AppColors.getCard(context)
                                      .withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
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
                    bottom: ResponsiveValues.spacingL(context),
                  ),
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
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ResponsiveRow(
            children: [
              // Icon shimmer
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context),
                    ),
                  ),
                ),
              ),
              ResponsiveSizedBox(width: AppSpacing.l),

              // Content shimmer
              Expanded(
                child: ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: double.infinity,
                        height: ResponsiveValues.spacingXL(context),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.m),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: ResponsiveValues.spacingXXXL(context) * 3,
                        height: ResponsiveValues.spacingL(context),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.l),
                    ResponsiveRow(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            width: ResponsiveValues.spacingXXL(context) * 2,
                            height: ResponsiveValues.spacingXL(context),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context),
                              ),
                            ),
                          ),
                        ),
                        ResponsiveSizedBox(width: AppSpacing.m),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            width: ResponsiveValues.spacingXXL(context) * 2,
                            height: ResponsiveValues.spacingXL(context),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context),
                              ),
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
                baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                child: Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
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
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  int _getChildCount(List courses, bool isLoadingCourses, bool isLoading) {
    // If we have courses, show all of them
    if (courses.isNotEmpty) {
      return courses.length;
    }

    // If we're loading and have no courses, show 5 shimmer items
    if (isLoading || isLoadingCourses) {
      return 5;
    }

    // If we're done loading and have no courses, show 1 item (the empty state)
    return 1;
  }

  Widget _buildMobileLayout() {
    if (_isLoading && !_hasCachedData) {
      return _buildSkeletonLoader(); // Show shimmer immediately if no cache
    }

    if (_category == null) {
      // Only show this if we have no cache AND no data after loading attempt
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXXLarge(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: ResponsiveValues.dialogPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusXXLarge(context)),
                  border: Border.all(
                    color: AppColors.telegramRed.withValues(alpha: 0.2),
                  ),
                ),
                child: ResponsiveColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResponsiveIcon(
                      Icons.error_outline_rounded,
                      size: ResponsiveValues.iconSizeXXL(context),
                      color: AppColors.telegramRed.withValues(alpha: 0.5),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.l),
                    ResponsiveText(
                      'Category not found',
                      style: AppTextStyles.titleLarge(context).copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.s),
                    ResponsiveText(
                      _isOffline && !_hasCachedData
                          ? 'No cached data available. Please check your connection.'
                          : 'The category you\'re looking for doesn\'t exist.',
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    _buildGradientButton(
                      label: 'Retry',
                      onPressed: _manualRefresh,
                      gradient: AppColors.blueGradient,
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
              AppColors.getBackground(context).withValues(alpha: 0.95),
              AppColors.getBackground(context),
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
                  child: ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ResponsiveText(
                        'Courses',
                        style: AppTextStyles.titleLarge(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isLoadingCourses && courses.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingM(context),
                            vertical: ResponsiveValues.spacingXS(context),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blueFaded,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
                            border: Border.all(
                              color:
                                  AppColors.telegramBlue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ResponsiveText(
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
                      // If we're still loading initial data (first load) and have no courses, show shimmer
                      if (_isLoading && courses.isEmpty) {
                        return _buildCourseCardShimmer(index: index);
                      }

                      // If we're loading more (background refresh) but have courses, show actual courses
                      if (isLoadingCourses && courses.isNotEmpty) {
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

                      // Show empty state only when not loading and no courses
                      if (!_isLoading &&
                          !isLoadingCourses &&
                          courses.isEmpty &&
                          index == 0) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingXXL(context)),
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
                        );
                      }

                      return null;
                    },
                    childCount:
                        _getChildCount(courses, isLoadingCourses, _isLoading),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ResponsiveSizedBox(height: AppSpacing.xxl),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  @override
  void dispose() {
    _subscriptionListener?.cancel();
    _refreshController.dispose();
    super.dispose();
  }
}
