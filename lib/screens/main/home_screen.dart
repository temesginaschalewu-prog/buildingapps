import 'dart:async';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/category_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/device_service.dart';
import '../../widgets/category/category_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_widget.dart';
import '../../utils/helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late CategoryProvider _categoryProvider;
  late SubscriptionProvider _subscriptionProvider;
  late NotificationProvider _notificationProvider;
  late RefreshController _refreshController;

  bool _isFirstLoad = true;
  bool _hasCachedCategories = false;
  bool _isOffline = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  final Map<int, bool> _categorySubscriptionCache = {};
  StreamSubscription? _subscriptionUpdatesSubscription;
  Timer? _refreshTimer;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshController = RefreshController(initialRefresh: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
      _loadHomeScreen(); // Changed from _loadInitialData
      _setupStreamListeners();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeProviders();
  }

  void _initializeProviders() {
    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    _subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    _notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
  }

  void _setupStreamListeners() {
    _subscriptionUpdatesSubscription =
        _subscriptionProvider.subscriptionUpdates.listen((updates) {
      if (mounted) {
        debugLog('HomeScreen', '🎯 Received subscription updates: $updates');
        setState(() {
          _categorySubscriptionCache.addAll(updates);
        });
      }
    });

    // Refresh every 10 minutes in background
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_isRefreshing) {
        _silentRefresh();
      }
    });
  }

  // 🎯 NEW: Telegram-style cache-first loading
  Future<void> _loadHomeScreen() async {
    // First, check if we have ANY cached data
    final hasCachedCategories =
        _categoryProvider.hasLoaded && _categoryProvider.categories.isNotEmpty;

    if (hasCachedCategories) {
      debugLog('HomeScreen', '📦 Showing cached categories immediately');

      // Show cached data right away
      setState(() {
        _hasCachedCategories = true;
        _isFirstLoad = false;
        _isOffline = false;
      });

      // Load subscription cache
      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        for (final category in activeCategories) {
          final status = _subscriptionProvider
              .hasActiveSubscriptionForCategory(category.id);
          _categorySubscriptionCache[category.id] = status;
        }
      }

      // Then try to refresh in background
      _refreshInBackground();
      return;
    }

    // No cache, show loading but with skeleton
    setState(() {
      _isFirstLoad = true;
    });

    try {
      debugLog('HomeScreen', '🚀 Loading fresh data...');

      await _categoryProvider.loadCategories(forceRefresh: false);
      await _subscriptionProvider.loadSubscriptions(forceRefresh: false);

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);

        if (mounted) {
          setState(() {
            _categorySubscriptionCache.clear();
            _categorySubscriptionCache.addAll(results);
          });
        }
      }

      debugLog('HomeScreen', '✅ Fresh data loaded');
    } on ApiError catch (e) {
      debugLog('HomeScreen', '❌ API Error: ${e.message}');
      setState(() {
        _errorMessage = e.message;
        _isOffline = true;
      });
    } catch (e) {
      debugLog('HomeScreen', '❌ Error: $e');
      setState(() {
        _errorMessage = 'Failed to load content';
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

  // 🔄 Background refresh (no UI blocking)
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugLog('HomeScreen', '🔄 Background refresh started');

    try {
      // Force refresh providers
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);

        if (mounted) {
          setState(() {
            _categorySubscriptionCache.clear();
            _categorySubscriptionCache.addAll(results);
          });
        }
      }

      debugLog('HomeScreen', '✅ Background refresh complete');

      // Show subtle success indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content updated'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
            margin: EdgeInsets.all(AppThemes.spacingL),
          ),
        );
      }
    } catch (e) {
      debugLog('HomeScreen', 'Background refresh error: $e');
    } finally {
      _isRefreshing = false;
      _refreshController.refreshCompleted();
    }
  }

  // 🔄 Manual pull-to-refresh
  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);

        if (mounted) {
          setState(() {
            _categorySubscriptionCache.clear();
            _categorySubscriptionCache.addAll(results);
            _isOffline = false;
          });
        }
      }

      debugLog('HomeScreen', '✅ Manual refresh complete');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content refreshed'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugLog('HomeScreen', 'Manual refresh error: $e');
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

  Future<void> _silentRefresh() async {
    if (_isRefreshing) return;

    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);

      if (mounted) {
        final activeCategories = _categoryProvider.activeCategories;
        for (final category in activeCategories) {
          final status = _subscriptionProvider
              .hasActiveSubscriptionForCategory(category.id);
          _categorySubscriptionCache[category.id] = status;
        }
        setState(() {}); // Trigger rebuild with new data
      }
    } catch (e) {
      // Silent fail - keep using cache
    }
  }

  Future<void> _loadNotifications() async {
    try {
      await _notificationProvider.loadNotifications();
      if (mounted) {
        setState(() {
          _unreadNotifications = _notificationProvider.unreadCount;
        });
      }
    } catch (e) {
      debugLog('HomeScreen', 'Error loading notifications: $e');
    }
  }

  bool _getCategorySubscriptionStatus(int categoryId) {
    if (_categorySubscriptionCache.containsKey(categoryId)) {
      return _categorySubscriptionCache[categoryId]!;
    }

    // Fallback to provider
    final status =
        _subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
    _categorySubscriptionCache[categoryId] = status;
    return status;
  }

  // 🏷️ Telegram-style header
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        left: AppThemes.spacingL,
        right: AppThemes.spacingL,
        top: MediaQuery.of(context).padding.top + AppThemes.spacingM,
        bottom: AppThemes.spacingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and title
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.blueGradient,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Academy',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _isOffline ? 'Offline Mode' : 'Learn. Grow. Succeed.',
                    style: AppTextStyles.caption.copyWith(
                      color: _isOffline
                          ? AppColors.telegramYellow
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              // Refresh indicator
              if (_isRefreshing)
                Container(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.telegramBlue,
                        ),
                      ),
                    ),
                  ),
                ),

              // Theme toggle
              _buildThemeToggleButton(),

              // Notifications
              _buildNotificationButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () async {
        try {
          await _notificationProvider.loadNotifications();
          GoRouter.of(context).push('/notifications');
        } catch (e) {
          showSnackBar(context, 'Failed to load notifications', isError: true);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        margin: EdgeInsets.only(left: AppThemes.spacingXS),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _unreadNotifications > 0
              ? badges.Badge(
                  position: badges.BadgePosition.topEnd(top: -2, end: -2),
                  badgeContent: Text(
                    _unreadNotifications > 9
                        ? '9+'
                        : _unreadNotifications.toString(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.telegramRed,
                    padding: const EdgeInsets.all(3),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 18,
                    color: AppColors.getTextPrimary(context),
                  ),
                )
              : Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: AppColors.getTextPrimary(context),
                ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: themeProvider.toggleTheme,
          child: Container(
            width: 36,
            height: 36,
            margin: EdgeInsets.only(left: AppThemes.spacingXS),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 18,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🌐 Offline banner
  Widget _buildOfflineBanner() {
    if (!_isOffline && _hasCachedCategories) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(AppThemes.spacingL),
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

  // 🎨 Main content builder
  Widget _buildContent() {
    final activeCategories = _categoryProvider.activeCategories;
    final comingSoonCategories = _categoryProvider.comingSoonCategories;

    if (_isFirstLoad) {
      // Show skeleton loading instead of full-screen loader
      return _buildSkeletonGrid();
    }

    if (activeCategories.isEmpty && comingSoonCategories.isEmpty) {
      return NoDataState(
        dataType: 'Categories',
        onRefresh: _manualRefresh,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Offline banner
        SliverToBoxAdapter(
          child: _buildOfflineBanner(),
        ),

        // Active categories
        if (activeCategories.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppThemes.spacingL,
              AppThemes.spacingL,
              AppThemes.spacingL,
              AppThemes.spacingS,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Categories',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${activeCategories.length}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.telegramBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ScreenSize.responsiveGridCount(
                  context: context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                crossAxisSpacing: AppThemes.spacingL,
                mainAxisSpacing: AppThemes.spacingL,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = activeCategories[index];
                  final hasSubscription =
                      _getCategorySubscriptionStatus(category.id);

                  return CategoryCard(
                    category: category,
                    hasSubscription: hasSubscription,
                    isCheckingSubscription: false, // Always false now
                    hasCachedData: _hasCachedCategories,
                    isRefreshInProgress: _isRefreshing,
                    onTap: () {
                      if (category.isActive) {
                        GoRouter.of(context).push('/category/${category.id}');
                      }
                    },
                    index: index,
                  );
                },
                childCount: activeCategories.length,
              ),
            ),
          ),
        ],

        // Coming soon section
        if (comingSoonCategories.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.all(AppThemes.spacingL),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppThemes.spacingL),
                  Text(
                    'Coming Soon',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppThemes.spacingS),
                  Text(
                    'Exciting new content is on the way!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ScreenSize.responsiveGridCount(
                  context: context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                crossAxisSpacing: AppThemes.spacingL,
                mainAxisSpacing: AppThemes.spacingL,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = comingSoonCategories[index];
                  return CategoryCard(
                    category: category,
                    hasSubscription: false,
                    isCheckingSubscription: false,
                    onTap: null,
                    index: index + activeCategories.length,
                  );
                },
                childCount: comingSoonCategories.length,
              ),
            ),
          ),
        ],

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(height: AppThemes.spacingXXL),
        ),
      ],
    );
  }

  // 🦴 Skeleton loading grid (Telegram style)
  Widget _buildSkeletonGrid() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(AppThemes.spacingL),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 150,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: 30,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppThemes.spacingL),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ScreenSize.responsiveGridCount(
                context: context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              crossAxisSpacing: AppThemes.spacingL,
              mainAxisSpacing: AppThemes.spacingL,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => CategoryCardShimmer(index: index),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasCachedCategories) {
      _silentRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _subscriptionUpdatesSubscription?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _manualRefresh,
              color: AppColors.telegramBlue,
              backgroundColor: AppColors.getSurface(context),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }
}
