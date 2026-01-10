import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/course_model.dart';
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
  bool _hasAccess = false;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
    // No route listener needed - we'll handle refresh differently
  }

  @override
  void dispose() {
    // Don't access GoRouter in dispose - it causes the error
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadCategory();
    await _checkAccess();
    await _loadCourses();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    await Future.wait([
      subscriptionProvider.loadSubscriptions(forceRefresh: true),
      courseProvider.loadCoursesByCategory(widget.categoryId),
      categoryProvider.loadCategories(), // Reload categories too
    ]);

    // Update category
    final category = categoryProvider.getCategoryById(widget.categoryId);

    // Update access check
    final hasAccess = subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);

    if (mounted) {
      setState(() {
        _category = category;
        _hasAccess = hasAccess;
      });
    }
  }

  Future<void> _loadCategory() async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

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

  Future<void> _checkAccess() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.loadSubscriptions();

    final hasAccess = subscriptionProvider
        .hasActiveSubscriptionForCategory(widget.categoryId);

    if (mounted) {
      setState(() {
        _hasAccess = hasAccess;
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

  void _handleCourseTap(Course course) {
    // Always allow clicking on courses - they should show even if locked
    _router.push('/course/${course.id}');
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
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);

              _router.push(
                '/payment',
                extra: {
                  'category': _category,
                  'paymentType': authProvider.user?.accountStatus == 'active'
                      ? 'repayment'
                      : 'first_time',
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
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Get ALL courses for this category (including locked ones)
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingIndicator(),
      );
    }

    if (_category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Category not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_category!.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _router.pop(),
        ),
        actions: [
          if (!_category!.isFree)
            IconButton(
              icon: const Icon(Icons.payment),
              onPressed: () {
                _router.push(
                  '/payment',
                  extra: {
                    'category': _category,
                    'paymentType': authProvider.user?.accountStatus == 'active'
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
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Access status banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _hasAccess
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _hasAccess ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasAccess ? Icons.check_circle : Icons.lock,
                            color: _hasAccess ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasAccess
                                  ? '✅ Full access to all content'
                                  : '🔒 Limited access - Free chapters only',
                              style: TextStyle(
                                color:
                                    _hasAccess ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

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
                      'Courses (${courses.length})',
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
                          onTap: () => _handleCourseTap(course),
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
