import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/category/category_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    if (!categoryProvider.isLoading && _isInitialLoad) {
      await categoryProvider.loadCategories();
      setState(() => _isInitialLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final user = authProvider.user;

    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final crossAxisCount = screenWidth < 400 ? 1 : 2;
    final childAspectRatio = screenWidth < 400 ? 1.8 : 1.2;

    if (_isInitialLoad && categoryProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Academy')),
        body: const LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Academy'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  context.push('/notifications');
                },
              ),
              if (notificationProvider.unreadNotifications.isNotEmpty)
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
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      notificationProvider.unreadNotifications.length
                          .toString(),
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
      body: RefreshIndicator(
        onRefresh: () async {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          await categoryProvider.loadCategories();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user?.username ?? 'Student'}!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontSize: isSmallScreen ? 22 : 24,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.accountStatus == 'active'
                              ? 'Active Subscriber'
                              : 'Free Account',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (categoryProvider.activeCategories.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Active Categories',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: isSmallScreen ? 18 : 20,
                                ),
                      ),
                    ),
                  ),
                if (categoryProvider.activeCategories.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: isSmallScreen ? 12 : 16,
                        mainAxisSpacing: isSmallScreen ? 12 : 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category =
                              categoryProvider.activeCategories[index];
                          return CategoryCard(
                            category: category,
                            onTap: () {
                              context.push('/category/${category.id}');
                            },
                          );
                        },
                        childCount: categoryProvider.activeCategories.length,
                      ),
                    ),
                  ),
                if (categoryProvider.comingSoonCategories.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Coming Soon',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: isSmallScreen ? 18 : 20,
                                ),
                      ),
                    ),
                  ),
                if (categoryProvider.comingSoonCategories.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: isSmallScreen ? 12 : 16,
                        mainAxisSpacing: isSmallScreen ? 12 : 16,
                        childAspectRatio: childAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category =
                              categoryProvider.comingSoonCategories[index];
                          return CategoryCard(
                            category: category,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('This category is coming soon!'),
                                ),
                              );
                            },
                          );
                        },
                        childCount:
                            categoryProvider.comingSoonCategories.length,
                      ),
                    ),
                  ),
                if (categoryProvider.activeCategories.isEmpty &&
                    categoryProvider.comingSoonCategories.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.category,
                      title: 'No Categories Available',
                      message: 'Categories will appear here when available',
                    ),
                  ),
                // Add some bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
