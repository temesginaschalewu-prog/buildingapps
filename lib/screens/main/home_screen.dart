import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/settings_provider.dart';
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
  late SettingsProvider _settingsProvider;
  late SubscriptionProvider _subscriptionProvider;
  String _greeting = '';

  @override
  String get screenTitle => _greeting;

  @override
  String? get screenSubtitle => _settingsProvider.getHomeScreenSubtitle();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoryProvider = context.read<CategoryProvider>();
    _paymentProvider = context.read<PaymentProvider>();
    _settingsProvider = Provider.of<SettingsProvider>(context);
    _subscriptionProvider = context.read<SubscriptionProvider>();
    _setGreeting();

    // ✅ Listen for category changes to update UI automatically
    _categoryProvider.addListener(_onCategoryChange);
    _paymentProvider.addListener(_onPaymentChange);
    _subscriptionProvider.addListener(_onSubscriptionChange);

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
    if (mounted) {
      setState(() {});
    }
  }

  void _onSubscriptionChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _categoryProvider.removeListener(_onCategoryChange);
    _paymentProvider.removeListener(_onPaymentChange);
    _subscriptionProvider.removeListener(_onSubscriptionChange);
    super.dispose();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = _settingsProvider.getHomeGreetingMorning();
    } else if (hour < 17) {
      _greeting = _settingsProvider.getHomeGreetingAfternoon();
    } else {
      _greeting = _settingsProvider.getHomeGreetingEvening();
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
      await _subscriptionProvider.checkSubscriptionsForCategories(categoryIds);
      if (isMounted) setState(() {});
    }
  }

  bool _getCategorySubscriptionStatus(int categoryId) {
    final categoryProviderStatus =
        _categoryProvider.getCategorySubscriptionStatus(categoryId);
    if (categoryProviderStatus) {
      return true;
    }
    return _subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
  }

  bool _getCategoryPendingPaymentStatus(int categoryId) {
    if (_getCategorySubscriptionStatus(categoryId)) {
      return false;
    }
    return _paymentProvider
        .getPendingPayments()
        .any((payment) => payment.categoryId == categoryId);
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
    final shouldShowEmpty = !hasData &&
        (_categoryProvider.hasLoaded || isOffline) &&
        !_categoryProvider.isLoading;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (shouldShowEmpty)
          SliverFillRemaining(
              child: buildEmptyWidget(
                dataType: 'categories',
                customMessage: _settingsProvider.getHomeEmptyCategoriesMessage(),
                isOffline: isOffline,
              ),
            )
        else ...[
          if (activeCategories.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveValues.homeGridHorizontalPadding(context)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                  mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                  childAspectRatio:
                      ResponsiveValues.homeCategoryGridAspectRatio(context),
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
                          context.push(
                            '/category/${category.id}',
                            extra: category,
                          );
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
                horizontal: ResponsiveValues.homeGridHorizontalPadding(context),
                vertical: ResponsiveValues.spacingM(context),
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settingsProvider.getHomeComingSoonTitle(),
                      style: AppTextStyles.titleMedium(context).copyWith(
                        color: AppColors.telegramOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      _settingsProvider.getHomeComingSoonSubtitle(),
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal:
                      ResponsiveValues.homeGridHorizontalPadding(context)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: ResponsiveValues.gridSpacing(context),
                  mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
                  childAspectRatio:
                      ResponsiveValues.homeCategoryGridAspectRatio(context),
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
