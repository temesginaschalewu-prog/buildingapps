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
import '../../widgets/category/category_card.dart';
import '../../widgets/common/empty_state.dart';
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
      _loadHomeScreen();
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

    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_isRefreshing) {
        _silentRefresh();
      }
    });
  }

  Future<void> _loadHomeScreen() async {
    final hasCachedCategories =
        _categoryProvider.hasLoaded && _categoryProvider.categories.isNotEmpty;

    if (hasCachedCategories) {
      debugLog('HomeScreen', '📦 Showing cached categories immediately');

      setState(() {
        _hasCachedCategories = true;
        _isFirstLoad = false;
        _isOffline = false;
      });

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        for (final category in activeCategories) {
          final status = _subscriptionProvider
              .hasActiveSubscriptionForCategory(category.id);
          _categorySubscriptionCache[category.id] = status;
        }
      }

      _refreshInBackground();
      return;
    }

    setState(() {
      _isFirstLoad = true;
    });

    try {
      debugLog('HomeScreen', '🚀 Loading fresh data...');

      await _categoryProvider.loadCategories(forceRefresh: false);
      await _subscriptionProvider.loadSubscriptions(forceRefresh: false);
      await _loadNotifications();

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

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugLog('HomeScreen', '🔄 Background refresh started');

    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);
      await _loadNotifications();

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Content updated'),
            backgroundColor: AppColors.telegramGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
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

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);
      await _loadNotifications();

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
          content: const Text('Content refreshed'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugLog('HomeScreen', 'Manual refresh error: $e');
      setState(() {
        _isOffline = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Refresh failed, using cached data'),
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
      await _loadNotifications();

      if (mounted) {
        final activeCategories = _categoryProvider.activeCategories;
        for (final category in activeCategories) {
          final status = _subscriptionProvider
              .hasActiveSubscriptionForCategory(category.id);
          _categorySubscriptionCache[category.id] = status;
        }
        setState(() {});
      }
    } catch (e) {
      // Silent fail
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

    final status =
        _subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
    _categorySubscriptionCache[categoryId] = status;
    return status;
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () async {
        try {
          await _notificationProvider.loadNotifications();
          if (mounted) {
            GoRouter.of(context).push('/notifications');
          }
        } catch (e) {
          if (mounted) {
            showSimpleSnackBar(context, 'Failed to load notifications',
                isError: true);
          }
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: _unreadNotifications > 0
              ? badges.Badge(
                  position: badges.BadgePosition.topEnd(top: -4, end: -4),
                  badgeContent: Text(
                    _unreadNotifications > 9
                        ? '9+'
                        : _unreadNotifications.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.telegramRed,
                    padding: const EdgeInsets.all(4),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: AppColors.getTextPrimary(context),
                  ),
                )
              : Icon(
                  Icons.notifications_outlined,
                  size: 22,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 22,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final activeCategories = _categoryProvider.activeCategories;
    final comingSoonCategories = _categoryProvider.comingSoonCategories;

    if (_isFirstLoad) {
      return _buildSkeletonGrid();
    }

    if (activeCategories.isEmpty && comingSoonCategories.isEmpty) {
      return NoDataState(
        dataType: 'Categories',
        onRefresh: _manualRefresh,
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ScreenSize.responsiveGridCount(
                  context: context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = activeCategories[index];
                  final hasSubscription =
                      _getCategorySubscriptionStatus(category.id);

                  return CategoryCard(
                    category: category,
                    hasSubscription: hasSubscription,
                    isCheckingSubscription: false,
                    hasCachedData: _hasCachedCategories,
                    isRefreshInProgress: _isRefreshing,
                    onTap: () {
                      if (category.isActive && mounted) {
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ScreenSize.responsiveGridCount(
                  context: context,
                  mobile: 2,
                  tablet: 3,
                  desktop: 4,
                ),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
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
        SliverToBoxAdapter(
          child: SizedBox(height: AppThemes.spacingXXL),
        ),
      ],
    );
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ScreenSize.responsiveGridCount(
                context: context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.7,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: AppColors.getBackground(context),
              foregroundColor: AppColors.getTextPrimary(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: ScreenSize.responsiveValue(
                context: context,
                mobile: 120.0,
                tablet: 140.0,
                desktop: 160.0,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.telegramBlue.withOpacity(0.05),
                        AppColors.getBackground(context),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: AppThemes.spacingL,
                    right: AppThemes.spacingL,
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: AppThemes.spacingM,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row with title and buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo and title
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: AppColors.blueGradient,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.school_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Family Academy',
                                              style: AppTextStyles.titleMedium
                                                  .copyWith(
                                                color: AppColors.getTextPrimary(
                                                    context),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _isOffline
                                                  ? 'Offline Mode'
                                                  : 'Learn. Grow. Succeed.',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: _isOffline
                                                    ? AppColors.telegramYellow
                                                    : AppColors
                                                        .getTextSecondary(
                                                            context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Buttons row
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isRefreshing)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
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
                                  _buildThemeToggleButton(),
                                  const SizedBox(width: 8),
                                  _buildNotificationButton(),
                                ],
                              ),
                            ],
                          ),

                          // Welcome message - only show if there's enough space
                          if (constraints.maxHeight > 100) ...[
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppColors.purpleGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style:
                                            AppTextStyles.titleSmall.copyWith(
                                          color:
                                              AppColors.getTextPrimary(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Continue your learning journey',
                                        style:
                                            AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.getTextSecondary(
                                              context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: AppColors.telegramBlue,
          backgroundColor: AppColors.getSurface(context),
          child: _buildContent(),
        ),
      ),
    );
  }
}
