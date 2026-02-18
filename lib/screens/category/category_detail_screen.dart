import 'dart:async';
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
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';
import 'package:shimmer/shimmer.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final Category? category;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    this.category,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  String? _rejectionReason;

  // Offline-first flags
  bool _hasCachedData = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  bool _isFirstLoad = true;

  final RefreshController _refreshController = RefreshController();
  StreamSubscription? _subscriptionListener;

  @override
  void initState() {
    super.initState();
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

  // FIXED: Local placeholder widget for category header
  Widget _buildLocalPlaceholder() {
    if (_category == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.telegramBlue.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.telegramBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _category!.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
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

  // 🎯 Telegram-style cache-first loading
  Future<void> _initializeScreen() async {
    // First, try to load from cache
    await _loadFromCache();

    if (_category != null && _hasCachedData) {
      debugLog('CategoryDetail', '📦 Showing cached category data');
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

      // Try to get cached category
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

        debugLog('CategoryDetail', '✅ Loaded category from cache');
      } else {
        // Try from provider cache
        final categoryProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );

        if (categoryProvider.categories.isNotEmpty) {
          _category = categoryProvider.getCategoryById(widget.categoryId);
          if (_category != null) {
            _hasCachedData = true;
            debugLog('CategoryDetail', '✅ Loaded category from provider cache');
          }
        }
      }
    } catch (e) {
      debugLog('CategoryDetail', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    try {
      debugLog('CategoryDetail', '🚀 Loading fresh data...');

      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.loadCategories(forceRefresh: true);
      }

      _category = categoryProvider.getCategoryById(widget.categoryId);

      if (_category == null) {
        throw Exception('Category not found');
      }

      await _checkAccessStatus();
      await _loadPaymentInfo();
      await _loadCourses();

      // Save to cache
      await _saveToCache();

      debugLog('CategoryDetail', '✅ Fresh data loaded');
    } catch (e) {
      debugLog('CategoryDetail', '❌ Error loading fresh data: $e');
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

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugLog('CategoryDetail', '🔄 Background refresh started');

    try {
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      await categoryProvider.loadCategories(forceRefresh: true);

      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) {
        _category = freshCategory;
      }

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadCourses(forceRefresh: true);
      await _saveToCache();

      debugLog('CategoryDetail', '✅ Background refresh complete');
    } catch (e) {
      debugLog('CategoryDetail', 'Background refresh error: $e');
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
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );

      await categoryProvider.loadCategories(forceRefresh: true);

      final freshCategory = categoryProvider.getCategoryById(widget.categoryId);
      if (freshCategory != null) {
        _category = freshCategory;
      }

      await _checkAccessStatus(forceCheck: true);
      await _loadPaymentInfo(forceRefresh: true);
      await _loadCourses(forceRefresh: true);
      await _saveToCache();

      setState(() {
        _isOffline = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category updated'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugLog('CategoryDetail', 'Manual refresh error: $e');
      setState(() {
        _isOffline = true;
      });
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
          .checkHasActiveSubscriptionForCategory(widget.categoryId);
    } else {
      _hasAccess = subscriptionProvider
          .hasActiveSubscriptionForCategory(widget.categoryId);
    }
  }

  Future<void> _updateAccessStatus() async {
    if (_category == null) return;

    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final newAccess = subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);

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
      debugLog('CategoryDetail', 'Error loading payment info: $e');
    }
  }

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    if (_category == null) return;

    final courseProvider = Provider.of<CourseProvider>(
      context,
      listen: false,
    );

    await courseProvider.loadCoursesByCategory(
      widget.categoryId,
      forceRefresh: forceRefresh,
      hasAccess: _hasAccess,
    );
  }

  Future<void> _saveToCache() async {
    if (_category == null) return;

    try {
      final deviceService = Provider.of<DeviceService>(
        context,
        listen: false,
      );

      final cacheData = {
        'category': _category!.toJson(),
        'has_access': _hasAccess,
        'has_pending_payment': _hasPendingPayment,
        'rejection_reason': _rejectionReason,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await deviceService.saveCacheItem(
        'category_${widget.categoryId}',
        cacheData,
        ttl: Duration(hours: 1),
        isUserSpecific: true,
      );

      debugLog('CategoryDetail', '✅ Saved category to cache');
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

    context.push(
      '/payment',
      extra: {
        'category': _category,
        'paymentType': _hasAccess ? 'repayment' : 'first_time',
      },
    );
  }

  void _showPendingPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.getCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
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
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Payment Pending',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'You have a pending payment for ${_category?.name}. '
                'Please wait for admin verification (1-3 working days).',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                  ),
                  child: Text('OK', style: AppTextStyles.buttonMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectedPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.getCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.telegramRed,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Payment Rejected',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.telegramRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                _rejectionReason != null
                    ? 'Your previous payment was rejected.\nReason: $_rejectionReason\n\nPlease submit a new payment with corrected information.'
                    : 'Your previous payment was rejected.\nPlease submit a new payment.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handlePaymentAction();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Pay Now', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Access status banner (Telegram style)
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
        message: 'You have access to all content in this category',
      );
    }

    if (_hasPendingPayment) {
      return _buildStatusBanner(
        icon: Icons.schedule_rounded,
        color: AppColors.statusPending,
        title: 'Payment Pending',
        message: 'Please wait for admin verification (1-3 working days)',
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
      );
    }

    return _buildStatusBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: 'Limited Access',
      message: 'Free chapters only. Purchase to unlock all content.',
      actionText: 'Purchase',
      onAction: _handlePaymentAction,
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

  // FIXED: Category header with local placeholder
  Widget _buildHeader() {
    if (_category == null) return SizedBox.shrink();

    final headerHeight = ScreenSize.responsiveValue(
      context: context,
      mobile: 200.0,
      tablet: 250.0,
      desktop: 300.0,
    );

    return Stack(
      children: [
        // Background image - FIXED: Use local placeholder if no image
        Container(
          height: headerHeight,
          width: double.infinity,
          child:
              (_category!.imageUrl != null && _category!.imageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: _category!.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildLocalPlaceholder(),
                    )
                  : _buildLocalPlaceholder(),
        ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
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
            desktop: AppThemes.spacingXXL,
          ),
          right: ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category name
              Text(
                _category!.name,
                style: AppTextStyles.displaySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingS),

              // Description
              if (_category!.description != null &&
                  _category!.description!.isNotEmpty)
                Text(
                  _category!.description!,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: AppThemes.spacingM),

              // Stats row
              Row(
                children: [
                  // Course count
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingM,
                      vertical: AppThemes.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: AppThemes.spacingXS),
                        Text(
                          '${_category!.courseCount} courses',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),

                  // Price if applicable
                  if (_category!.price != null && _category!.price! > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingM,
                        vertical: AppThemes.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.telegramBlue,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.white,
                          ),
                          Text(
                            _category!.priceDisplay,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + AppThemes.spacingM,
          left: AppThemes.spacingL,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),

        // Refresh indicator (when refreshing)
        if (_isRefreshing)
          Positioned(
            top: MediaQuery.of(context).padding.top + AppThemes.spacingM,
            right: AppThemes.spacingL,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
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
      ),
      body: Column(
        children: [
          // Header shimmer
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: ScreenSize.responsiveValue(
                context: context,
                mobile: 200,
                tablet: 250,
                desktop: 300,
              ),
              color: Colors.white,
            ),
          ),

          // Content shimmer
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              )),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppThemes.spacingL),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusLarge),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🦴 Course card shimmer
  Widget _buildCourseCardShimmer({required int index}) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppThemes.spacingL),
      child: Container(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        )),
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Status indicator shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
              ),
            ),
            SizedBox(width: AppThemes.spacingL),
            // Content shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: double.infinity,
                      height: 20,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingS),
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 150,
                      height: 16,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingM),
                  Row(
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 80,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: AppThemes.spacingM),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 60,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right arrow shimmer
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton loader on first load with no cache
    if (_isFirstLoad && !_hasCachedData) {
      return _buildSkeletonLoader();
    }

    // Show error if no category
    if (_category == null) {
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
            title: 'Category not found',
            message: _isOffline
                ? 'No cached data available. Please check your connection.'
                : 'The category you\'re looking for doesn\'t exist.',
            type: EmptyStateType.error,
            actionText: 'Retry',
            onAction: _manualRefresh,
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
      appBar: AppBar(
        title: Text(
          _category!.name,
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
            // Header with category image - FIXED: Now uses local placeholder
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Access banner
            SliverToBoxAdapter(
              child: _buildAccessBanner(),
            ),

            // Courses section
            SliverPadding(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              )),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Courses',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!isLoadingCourses && courses.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingM,
                              vertical: AppThemes.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.telegramBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                            ),
                            child: Text(
                              '${courses.length}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.telegramBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Course list with shimmer loading
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isLoadingCourses && courses.isEmpty) {
                      return _buildCourseCardShimmer(index: index);
                    }

                    if (index < courses.length) {
                      final course = courses[index];
                      return CourseCard(
                        course: course,
                        categoryId: widget.categoryId,
                        onTap: () {
                          context.push('/course/${course.id}', extra: {
                            'course': course,
                            'category': _category,
                            'hasAccess': _hasAccess,
                          });
                        },
                        index: index,
                      );
                    }
                    return null;
                  },
                  childCount:
                      isLoadingCourses && courses.isEmpty ? 5 : courses.length,
                ),
              ),
            ),

            // Empty state
            if (!isLoadingCourses && courses.isEmpty)
              SliverFillRemaining(
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

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: AppThemes.spacingXXL),
            ),
          ],
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
