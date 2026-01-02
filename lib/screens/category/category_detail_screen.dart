import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;

  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Category? _category;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategory();
    _loadCourses();
  }

  Future<void> _loadCategory() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // If categories haven't been loaded yet, load them
    if (categoryProvider.categories.isEmpty) {
      await categoryProvider.loadCategories();
    }

    final category = categoryProvider.getCategoryById(widget.categoryId);

    if (mounted) {
      setState(() {
        _category = category;
      });
    }
  }

  Future<void> _loadCourses() async {
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    await courseProvider.loadCoursesByCategory(widget.categoryId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAccess() async {
    if (_category == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // If category is free, allow access
    if (_category!.isFree) return;

    // If user is active, check subscription
    if (authProvider.user?.accountStatus == 'active') {
      final hasSubscription = subscriptionProvider
          .hasActiveSubscriptionForCategory(widget.categoryId);
      if (!hasSubscription) {
        _showPaymentDialog();
      }
    } else {
      _showPaymentDialog();
    }
  }

  void _showPaymentDialog() {
    if (_category == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Text(
          'You need to purchase "${_category!.name}" to access its content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                '/payment',
                extra: {
                  'category': _category,
                  'paymentType': 'first_time',
                },
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);

    final hasAccess = _category?.isFree ??
        false ||
            (authProvider.user?.accountStatus == 'active' &&
                authProvider.user?.isActive == true);

    if (_category == null || _isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_category!.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_category!.isFree)
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () {
                context.push(
                  '/payment',
                  extra: {
                    'category': _category,
                    'paymentType': authProvider.user?.isActive == true
                        ? 'repayment'
                        : 'first_time',
                  },
                );
              },
              tooltip: 'Purchase/Renew',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await courseProvider.loadCoursesByCategory(widget.categoryId);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_category!.description != null &&
                        _category!.description!.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _category!.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Courses',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (courses.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final course = courses[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CourseCard(
                          course: course,
                          onTap: hasAccess
                              ? () {
                                  context.push(
                                    '/course/${course.id}',
                                    extra: course,
                                  );
                                }
                              : _checkAccess,
                        ),
                      );
                    },
                    childCount: courses.length,
                  ),
                ),
              ),
            if (courses.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.book,
                  title: 'No Courses Available',
                  message: 'Courses will appear here when available',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
