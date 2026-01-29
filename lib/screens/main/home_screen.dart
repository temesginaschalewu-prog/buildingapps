import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/category/category_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  bool _hasInitialData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataIfNeeded();
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    try {
      await notificationProvider.loadNotifications();
    } catch (e) {
      debugLog('HomeScreen', 'Error loading notifications: $e');
    }
  }

  Future<void> _loadDataIfNeeded() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // If we already have data, don't show loading
    if (categoryProvider.categories.isNotEmpty && !_hasInitialData) {
      setState(() {
        _hasInitialData = true;
      });
      return;
    }

    // Only show loading spinner if we have no data
    if (categoryProvider.categories.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await Future.wait([
        categoryProvider.loadCategories(),
        subscriptionProvider.loadSubscriptions(),
      ]);
    } catch (e) {
      debugLog('HomeScreen', 'Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasInitialData = true;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    try {
      await Future.wait([
        categoryProvider.loadCategories(),
        subscriptionProvider.loadSubscriptions(),
      ]);
    } catch (e) {
      debugLog('HomeScreen', 'Error refreshing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final activeCategories = categoryProvider.activeCategories;
    final comingSoonCategories = categoryProvider.comingSoonCategories;
    final notificationProvider = Provider.of<NotificationProvider>(context);

    // Show cached data while loading in background
    final showCachedData =
        activeCategories.isNotEmpty || comingSoonCategories.isNotEmpty;
    final isLoadingFirstTime = _isLoading && !showCachedData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Academy'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              final unreadCount = provider.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      // Refresh notifications before opening
                      context
                          .read<NotificationProvider>()
                          .loadNotifications()
                          .then((_) {
                        context.push('/notifications');
                      });
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: isLoadingFirstTime
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  if (activeCategories.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Active Categories',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  if (activeCategories.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = activeCategories[index];
                            final hasSubscription = subscriptionProvider
                                .hasActiveSubscriptionForCategory(
                              category.id,
                            );

                            return CategoryCard(
                              category: category,
                              hasSubscription: hasSubscription,
                              onTap: () {
                                if (category.isActive) {
                                  context.push(
                                    '/category/${category.id}',
                                  );
                                }
                              },
                            );
                          },
                          childCount: activeCategories.length,
                        ),
                      ),
                    ),
                  if (comingSoonCategories.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Coming Soon',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  if (comingSoonCategories.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = comingSoonCategories[index];
                            return CategoryCard(
                              category: category,
                              hasSubscription: false,
                              onTap: () {
                                if (category.isComingSoon) {
                                  showSnackBar(
                                    context,
                                    '${category.name} is coming soon!',
                                  );
                                }
                              },
                            );
                          },
                          childCount: comingSoonCategories.length,
                        ),
                      ),
                    ),
                  if (activeCategories.isEmpty && comingSoonCategories.isEmpty)
                    const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.category,
                        title: 'No Categories Available',
                        message: 'Categories will appear here when available',
                        actionText: 'Refresh',
                      ),
                    ),
                  // Show subtle loading indicator at bottom if refreshing
                  if (_isLoading && showCachedData)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
