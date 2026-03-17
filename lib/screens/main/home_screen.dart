// lib/screens/main/home_screen.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - FIXED LOADING STATE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../../providers/category_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/category/category_card.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late CategoryProvider _categoryProvider;
  late SubscriptionProvider _subscriptionProvider;

  final RefreshController _refreshController = RefreshController();
  bool _isRefreshing = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  final Map<int, bool> _categorySubscriptionCache = {};
  String _greeting = '';

  StreamSubscription? _subscriptionUpdatesSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _greetingTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugLog('HomeScreen', 'initState');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _setGreeting();
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
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    _setGreeting();
    await _loadData();
  }

  void _setGreeting() {
    final now = DateTime.now().toLocal();
    final hour = now.hour;
    if (hour < 12) {
      _greeting = AppStrings.goodMorning;
    } else if (hour < 17) {
      _greeting = AppStrings.goodAfternoon;
    } else {
      _greeting = AppStrings.goodEvening;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;
      setState(() {
        _isOffline = !isOnline;
        _pendingCount = connectivityService.pendingActionsCount;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline = !connectivityService.isOnline;
      _pendingCount = connectivityService.pendingActionsCount;
    });
  }

  Future<void> _loadData() async {
    // Only load categories if we don't have initial data from cache
    if (!_categoryProvider.hasInitialData) {
      await _categoryProvider.loadCategories();
    }
    if (!mounted) return;
    unawaited(_loadSubscriptionStatusInBackground());
  }

  Future<void> _loadSubscriptionStatusInBackground() async {
    try {
      // Only load subscriptions if we don't have initial data from cache
      if (!_subscriptionProvider.hasInitialData) {
        await _subscriptionProvider.loadSubscriptions();
      }
      if (!mounted) return;
      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);
        if (mounted) setState(() => _categorySubscriptionCache.addAll(results));
      }
    } catch (e) {
      debugLog('HomeScreen', 'Background subscription load skipped: $e');
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    try {
      await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      if (!mounted) return;
      await _categoryProvider.loadCategories(forceRefresh: true);
      if (!mounted) return;
      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);
        if (mounted) setState(() => _categorySubscriptionCache.addAll(results));
      }
    } catch (e) {
      debugLog('HomeScreen', 'Background refresh error: $e');
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      _refreshController.refreshFailed();
      if (mounted) SnackbarService().showOffline(context, action: 'refresh');
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      await _subscriptionProvider.loadSubscriptions(
          forceRefresh: true, isManualRefresh: true);
      if (!mounted) return;
      await _categoryProvider.loadCategories(
          forceRefresh: true, isManualRefresh: true);
      if (!mounted) return;
      final activeCategories = _categoryProvider.activeCategories;
      if (activeCategories.isNotEmpty) {
        final categoryIds = activeCategories.map((c) => c.id).toList();
        final results = await _subscriptionProvider
            .checkSubscriptionsForCategories(categoryIds);
        if (mounted) {
          setState(() {
            _categorySubscriptionCache.addAll(results);
            _isOffline = false;
          });
        }
      }
      if (mounted) {
        SnackbarService().showSuccess(context, AppStrings.success);
      }
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
      if (mounted) {
        if (isNetworkError(e)) {
          setState(() => _isOffline = true);
          SnackbarService().showOffline(context, action: 'refresh');
        } else {
          SnackbarService().showError(context, AppStrings.refreshFailed);
        }
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setGreeting();
      if (!_isOffline) unawaited(_refreshInBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionUpdatesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _greetingTimer?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final activeCategories = _categoryProvider.activeCategories;
    final comingSoonCategories = _categoryProvider.comingSoonCategories;

    // Use hasInitialData to determine if we should show shimmer
    final isLoading =
        _categoryProvider.isLoading && !_categoryProvider.hasInitialData;
    final hasLoaded = _categoryProvider.hasLoaded;
    final hasInitialData = _categoryProvider.hasInitialData;
    final error = _categoryProvider.errorMessage;

    debugLog('HomeScreen',
        'BUILD - isLoading: $isLoading, hasLoaded: $hasLoaded, hasInitialData: $hasInitialData, categories: ${activeCategories.length}');

    // 1. LOADING STATE - Only on first load with no data
    if (isLoading && !hasInitialData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: _greeting,
          showOfflineIndicator: _isOffline,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppShimmer(
                type: ShimmerType.categoryCard,
                index: index,
                isOffline: _isOffline),
          ),
        ),
      );
    }

    // 2. ERROR STATE - Only when we have error AND no data
    if (error != null && !hasInitialData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar:
            CustomAppBar(title: _greeting, showOfflineIndicator: _isOffline),
        body: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: AppColors.telegramBlue,
          backgroundColor: AppColors.getSurface(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: AppEmptyState.error(
                  title: AppStrings.failedToLoad,
                  message: error,
                  onRetry: _manualRefresh,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 3. OFFLINE EMPTY STATE
    if (_isOffline && !hasInitialData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(title: _greeting, showOfflineIndicator: true),
        body: Center(
          child: AppEmptyState.offline(
            message: AppStrings.noCachedDataAvailable,
            onRetry: _manualRefresh,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    // 4. EMPTY STATE - When we have no data but we're not loading
    if (activeCategories.isEmpty && comingSoonCategories.isEmpty && hasLoaded) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar:
            CustomAppBar(title: _greeting, showOfflineIndicator: _isOffline),
        body: RefreshIndicator(
          onRefresh: _manualRefresh,
          color: AppColors.telegramBlue,
          backgroundColor: AppColors.getSurface(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: AppEmptyState.noData(
                  dataType: 'Categories',
                  customMessage: AppStrings.categoriesWillAppearHere,
                  onRefresh: _manualRefresh,
                  isRefreshing: _isRefreshing,
                  isOffline: _isOffline,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 5. ACTUAL DATA
    final columns = ResponsiveValues.gridColumns(context);
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(title: _greeting, showOfflineIndicator: _isOffline),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isOffline && _pendingCount > 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_pendingCount pending change${_pendingCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (activeCategories.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingS(context)),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                    mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                    childAspectRatio: ScreenSize.cardAspectRatio(
                        context: context, columns: columns),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = activeCategories[index];
                      final hasSubscription =
                          _getCategorySubscriptionStatus(category.id);
                      return CategoryCard(
                        category: category,
                        hasSubscription: hasSubscription,
                        onTap: () {
                          if (category.isActive && mounted) {
                            GoRouter.of(context)
                                .push('/category/${category.id}');
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
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingS(context),
                  vertical: ResponsiveValues.spacingM(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Coming Soon',
                    style: AppTextStyles.titleMedium(context).copyWith(
                      color: AppColors.telegramOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingS(context)),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                    mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                    childAspectRatio: ScreenSize.cardAspectRatio(
                        context: context, columns: columns),
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
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}
