import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/category_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/category/category_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/app_bar.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  bool _isRefreshing = false;
  String _refreshSubtitle = '';
  final Map<int, bool> _categorySubscriptionCache = {};
  StreamSubscription? _subscriptionUpdatesSubscription;
  Timer? _refreshTimer;
  String _greeting = '';
  String _ethiopianTime = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshController = RefreshController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
      _setGreeting();
      _setEthiopianTime();
      _loadHomeScreen();
      _setupStreamListeners();

      Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) _setEthiopianTime();
      });
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

  Widget _buildSkeletonGrid() {
    final columns = ResponsiveValues.gridColumns(context);

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // App bar is NOT shimmered - shows immediately
        SliverToBoxAdapter(
          child: CustomAppBar(
            title: _greeting,
            subtitle:
                _refreshSubtitle.isNotEmpty ? _refreshSubtitle : _ethiopianTime,
          ),
        ),
        SliverPadding(
          padding: ResponsiveValues.screenPadding(context),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassContainer(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingM(context),
                      vertical: ResponsiveValues.spacingXS(context),
                    ),
                    child: Row(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            width: ResponsiveValues.iconSizeS(context),
                            height: ResponsiveValues.iconSizeS(context),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            width: 100,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildGlassContainer(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingM(context),
                      vertical: ResponsiveValues.spacingXS(context),
                    ),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: 30,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingS(context),
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: ResponsiveValues.gridSpacing(context),
              mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
              childAspectRatio: ScreenSize.cardAspectRatio(
                context: context,
                columns: columns,
              ),
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

  void _setGreeting() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      _greeting = 'Good Afternoon';
    } else if (hour >= 17 && hour < 20) {
      _greeting = 'Good Evening';
    } else {
      _greeting = 'Good Night';
    }
  }

  void _setEthiopianTime() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    setState(() {
      _ethiopianTime = '$hour:$minute EAT';
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
        setState(() => _categorySubscriptionCache.addAll(updates));
      }
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_isRefreshing) _silentRefresh();
    });
  }

  Future<void> _loadHomeScreen() async {
    final hasCachedCategories =
        _categoryProvider.hasLoaded && _categoryProvider.categories.isNotEmpty;

    if (hasCachedCategories) {
      setState(() {
        _hasCachedCategories = true;
        _isFirstLoad = false;
      });

      final activeCategories = _categoryProvider.activeCategories;
      for (final category in activeCategories) {
        final status =
            _subscriptionProvider.hasActiveSubscriptionForCategory(category.id);
        _categorySubscriptionCache[category.id] = status;
      }

      await _refreshInBackground();
      return;
    }

    setState(() => _isFirstLoad = true);

    try {
      await _categoryProvider.loadCategories();
      await _subscriptionProvider.loadSubscriptions();
      await _loadNotifications();

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);
        if (mounted) setState(() => _categorySubscriptionCache.addAll(results));
      }
    } on ApiError {
      setState(() {});
    } catch (e) {
      setState(() {});
    } finally {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      await _categoryProvider.loadCategories(forceRefresh: true);
      await _loadNotifications();

      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);
        if (mounted) setState(() => _categorySubscriptionCache.addAll(results));
      }
    } finally {
      _isRefreshing = false;
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
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
            _categorySubscriptionCache.addAll(results);
          });
        }
      }

      _setEthiopianTime();
      showTopSnackBar(context, 'Content refreshed');
    } catch (e) {
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
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
    } catch (e) {}
  }

  Future<void> _loadNotifications() async {
    try {
      await _notificationProvider.loadNotifications();
    } catch (e) {}
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

  Widget _buildContent() {
    final activeCategories = _categoryProvider.activeCategories;
    final comingSoonCategories = _categoryProvider.comingSoonCategories;

    if (_isFirstLoad) return _buildSkeletonGrid();

    if (activeCategories.isEmpty && comingSoonCategories.isEmpty) {
      return NoDataState(dataType: 'Categories', onRefresh: _manualRefresh);
    }

    final columns = ResponsiveValues.gridColumns(context);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CustomAppBar(
            title: _greeting,
            subtitle:
                _refreshSubtitle.isNotEmpty ? _refreshSubtitle : _ethiopianTime,
          ),
        ),
        if (activeCategories.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveValues.spacingL(context),
              ResponsiveValues.spacingL(context),
              ResponsiveValues.spacingL(context),
              ResponsiveValues.spacingS(context),
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassContainer(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: ResponsiveValues.iconSizeS(context),
                            color: AppColors.telegramBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Your Categories',
                            style: AppTextStyles.titleSmall(context).copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildGlassContainer(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      child: Text(
                        '${activeCategories.length}',
                        style: AppTextStyles.labelLarge(context).copyWith(
                          color: AppColors.telegramPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingS(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                childAspectRatio: ScreenSize.cardAspectRatio(
                  context: context,
                  columns: columns,
                ),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = activeCategories[index];
                  final hasSubscription =
                      _getCategorySubscriptionStatus(category.id);

                  return CategoryCard(
                    category: category,
                    hasSubscription: hasSubscription,
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
            padding: ResponsiveValues.screenPadding(context),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassContainer(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: ResponsiveValues.iconSizeS(context),
                            color: AppColors.telegramOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Coming Soon',
                            style: AppTextStyles.titleSmall(context).copyWith(
                              color: AppColors.telegramOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exciting new content is on the way!',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingS(context),
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                childAspectRatio: ScreenSize.cardAspectRatio(
                  context: context,
                  columns: columns,
                ),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = comingSoonCategories[index];
                  return CategoryCard(
                    category: category,
                    hasSubscription: false,
                    index: index + activeCategories.length,
                  );
                },
                childCount: comingSoonCategories.length,
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: ResponsiveValues.spacingXXL(context)),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setGreeting();
      _setEthiopianTime();
      if (_hasCachedCategories) _silentRefresh();
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

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: _buildContent(),
      ),
    );
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
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}
