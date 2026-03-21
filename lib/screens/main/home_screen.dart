// lib/screens/main/home_screen.dart
// PRODUCTION STANDARD - NO SHIMMER WHEN CACHED DATA EXISTS

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/category/category_card.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with BaseScreenMixin<HomeScreen> {
  late CategoryProvider _categoryProvider;
  late PaymentProvider _paymentProvider;
  late SubscriptionProvider _subscriptionProvider;
  final Map<int, bool> _categorySubscriptionCache = {};
  final Map<int, bool> _categoryPendingPaymentCache = {};
  String _greeting = '';

  @override
  String get screenTitle => _greeting;

  @override
  String? get screenSubtitle => 'Discover your learning path';

  // ✅ CRITICAL: isLoading should be false if we have cached data
  @override
  bool get isLoading =>
      _categoryProvider.isLoading && !_categoryProvider.hasInitialData;

  @override
  bool get hasCachedData => _categoryProvider.hasInitialData;

  @override
  dynamic get errorMessage => _categoryProvider.errorMessage;

  @override
  ShimmerType get shimmerType => ShimmerType.categoryCard;

  @override
  int get shimmerItemCount => 6;

  @override
  void initState() {
    super.initState();
    _setGreeting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoryProvider = context.read<CategoryProvider>();
    _paymentProvider = context.read<PaymentProvider>();
    _subscriptionProvider = context.read<SubscriptionProvider>();

    // ✅ Listen for category changes to update UI automatically
    _categoryProvider.addListener(_onCategoryChange);
    _paymentProvider.addListener(_onPaymentChange);

    // ✅ Ensure UI updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onCategoryChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPaymentChange() {
    _categoryPendingPaymentCache.clear();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _categoryProvider.removeListener(_onCategoryChange);
    _paymentProvider.removeListener(_onPaymentChange);
    super.dispose();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  @override
  Future<void> onRefresh() async {
    await _subscriptionProvider.loadSubscriptions(
        forceRefresh: true, isManualRefresh: true);
    await _categoryProvider.loadCategories(
        forceRefresh: true, isManualRefresh: true);

    final activeCategories = _categoryProvider.activeCategories;
    if (activeCategories.isNotEmpty) {
      final categoryIds = activeCategories.map((c) => c.id).toList();
      final results = await _subscriptionProvider
          .checkSubscriptionsForCategories(categoryIds);
      if (isMounted) {
        setState(() => _categorySubscriptionCache.addAll(results));
      }
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

  bool _getCategoryPendingPaymentStatus(int categoryId) {
    if (_categoryPendingPaymentCache.containsKey(categoryId)) {
      return _categoryPendingPaymentCache[categoryId]!;
    }

    final status = _paymentProvider
        .getPendingPayments()
        .any((payment) => payment.categoryId == categoryId);
    _categoryPendingPaymentCache[categoryId] = status;
    return status;
  }

  @override
  Widget buildContent(BuildContext context) {
    final activeCategories = _categoryProvider.activeCategories;
    final comingSoonCategories = _categoryProvider.comingSoonCategories;
    final columns = ResponsiveValues.gridColumns(context);

    final hasData =
        activeCategories.isNotEmpty || comingSoonCategories.isNotEmpty;

    // ✅ Only show empty state if:
    // 1. No data AND
    // 2. Provider has finished loading OR offline
    final shouldShowEmpty =
        !hasData && (_categoryProvider.hasLoaded || isOffline);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (isOffline && pendingCount > 0)
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
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
                child: Row(
                  children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$pendingCount pending change${pendingCount > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (shouldShowEmpty)
          SliverFillRemaining(
            child: buildEmptyWidget(
              dataType: 'categories',
              customMessage: 'Categories will appear here when available.',
              isOffline: isOffline,
            ),
          )
        else ...[
          if (activeCategories.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingS(context)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                  mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = activeCategories[index];
                    final hasSubscription =
                        _getCategorySubscriptionStatus(category.id);
                    final hasPendingPayment =
                        _getCategoryPendingPaymentStatus(category.id);
                    return CategoryCard(
                      category: category,
                      hasSubscription: hasSubscription,
                      hasPendingPayment: hasPendingPayment,
                      onTap: () {
                        if (category.isActive && mounted) {
                          context.push('/category/${category.id}');
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
                  childAspectRatio: 0.7,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(content: buildContent(context));
  }
}
