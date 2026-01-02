import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
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
    final user = authProvider.user;

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
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Navigate to notifications
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
      body: RefreshIndicator(
        onRefresh: () async {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          await categoryProvider.loadCategories();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.username ?? 'Student'}!',
                      style: Theme.of(context).textTheme.headlineMedium,
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Active Categories',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            if (categoryProvider.activeCategories.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = categoryProvider.activeCategories[index];
                      return CategoryCard(
                        category: category,
                        onTap: () {
                          context.push(
                            '/category/${category.id}',
                          );
                        },
                      );
                    },
                    childCount: categoryProvider.activeCategories.length,
                  ),
                ),
              ),
            if (categoryProvider.comingSoonCategories.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Coming Soon',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            if (categoryProvider.comingSoonCategories.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
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
                              content: Text('This category is coming soon!'),
                            ),
                          );
                        },
                      );
                    },
                    childCount: categoryProvider.comingSoonCategories.length,
                  ),
                ),
              ),
            if (categoryProvider.activeCategories.isEmpty &&
                categoryProvider.comingSoonCategories.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.category,
                  title: 'No Categories Available',
                  message: 'Categories will appear here when available',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
