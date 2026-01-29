import 'package:familyacademyclient/models/payment_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/course_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';

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
  bool _hasPendingPayment = false;
  String? _rejectionReason;
  bool _hasInitialData = false;
  bool _isLoadingCourses = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load category first
    await _loadCategory();

    // Check if we have cached courses
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final hasCachedCourses =
        courseProvider.hasLoadedCategory(widget.categoryId);

    // Load other data in parallel
    await Future.wait([
      _checkAccessAndPaymentStatus(),
      _loadRejectedPaymentInfo(),
    ]);

    // If we have cached courses, show them immediately
    if (hasCachedCourses) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasInitialData = true;
        });
      }
    }

    // Load courses in background (will update UI when done)
    await _loadCourses();
  }

  Future<void> _refreshData() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    // Show loading indicator for courses
    setState(() {
      _isLoadingCourses = true;
    });

    try {
      await Future.wait([
        subscriptionProvider.loadSubscriptions(forceRefresh: true),
        paymentProvider.loadPayments(),
        courseProvider.loadCoursesByCategory(widget.categoryId,
            forceRefresh: true),
        categoryProvider.loadCategories(forceRefresh: true),
      ]);

      final category = categoryProvider.getCategoryById(widget.categoryId);

      await _checkAccessAndPaymentStatus();
      await _loadRejectedPaymentInfo();

      if (mounted) {
        setState(() {
          _category = category;
          _isLoadingCourses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
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

  Future<void> _checkAccessAndPaymentStatus() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);

    await Future.wait([
      subscriptionProvider.loadSubscriptions(),
      paymentProvider.loadPayments(),
    ]);

    final hasAccess = await subscriptionProvider
        .checkHasActiveSubscriptionForCategory(widget.categoryId);

    bool hasPending = false;
    if (_category != null) {
      final pendingPayments = paymentProvider.getPendingPayments();
      hasPending = pendingPayments.any((payment) =>
          payment.categoryName.toLowerCase() == _category!.name.toLowerCase());
    }

    if (mounted) {
      setState(() {
        _hasAccess = hasAccess;
        _hasPendingPayment = hasPending;
      });
    }
  }

  Future<void> _loadRejectedPaymentInfo() async {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);

    if (_category != null) {
      final rejectedPayments = paymentProvider.getRejectedPayments();
      final recentRejected = rejectedPayments.firstWhere(
        (p) => p.categoryName.toLowerCase() == _category!.name.toLowerCase(),
        orElse: () => Payment(
          id: 0,
          paymentType: '',
          amount: 0,
          paymentMethod: '',
          status: '',
          createdAt: DateTime.now(),
          categoryName: '',
          rejectionReason: null,
        ),
      );

      if (recentRejected.rejectionReason != null) {
        setState(() {
          _rejectionReason = recentRejected.rejectionReason;
        });
      }
    }
  }

  Future<void> _loadCourses() async {
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);

    setState(() {
      _isLoadingCourses = true;
    });

    await courseProvider.loadCoursesByCategory(widget.categoryId);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasInitialData = true;
        _isLoadingCourses = false;
      });
    }
  }

  void _handleCourseTap(Course course) {
    context.push('/course/${course.id}', extra: {
      'course': course,
      'category': _category,
      'hasAccess': _hasAccess
    });
  }

  void _handlePaymentAction() {
    if (_category == null) return;

    if (_hasPendingPayment) {
      _showPendingPaymentDialog();
      return;
    }

    if (_rejectionReason != null) {
      _showRejectedPaymentDialog();
      return;
    }

    context.push(
      '/payment',
      extra: {
        'category': _category,
        'paymentType': _hasAccess ? 'repayment' : 'first_time',
      },
    );
  }

  void _showPendingPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Pending'),
        content: const Text(
          'You already have a pending payment for this category. '
          'Please wait for admin verification (1-3 working days).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRejectedPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Rejected'),
        content: Text(
          _rejectionReason != null
              ? 'Your previous payment was rejected. Reason: $_rejectionReason\n\nPlease submit a new payment with corrected information.'
              : 'Your previous payment was rejected. Please submit a new payment.',
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
            child: const Text('Submit New Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessStatus() {
    if (_category?.isFree ?? false) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Free category - All content accessible',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasAccess) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Full access to all content',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_hasPendingPayment) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.pending, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Pending Verification',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait 1-3 working days for admin verification',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_rejectionReason != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Rejected',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $_rejectionReason',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase required for full access',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Free chapters are accessible. Purchase to unlock all content.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPaymentButton() {
    if (_category?.isFree ?? false) return const SizedBox.shrink();
    if (_hasAccess) return const SizedBox.shrink();
    if (_hasPendingPayment) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Get Full Access',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock all ${_category?.name ?? "category"} content with a subscription',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handlePaymentAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Purchase Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    final courseProvider = Provider.of<CourseProvider>(context);
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);

    // Show cached data immediately, even if loading
    final showCachedData = courses.isNotEmpty || _hasInitialData;

    if (!showCachedData && _isLoading) {
      return const SliverFillRemaining(
        child: LoadingIndicator(),
      );
    }

    if (courses.isEmpty && _hasInitialData && !_isLoadingCourses) {
      return const SliverFillRemaining(
        child: EmptyState(
          icon: Icons.book,
          title: 'No Courses Available',
          message: 'Courses will appear here when available',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final course = courses[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CourseCard(
                course: course,
                categoryId: widget.categoryId,
                onTap: () => _handleCourseTap(course),
              ),
            );
          },
          childCount: courses.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);
    final courses = courseProvider.getCoursesByCategory(widget.categoryId);

    // Determine if we should show loading
    final showCachedData = courses.isNotEmpty || _hasInitialData;
    final isLoadingFirstTime = _isLoading && !showCachedData;

    if (isLoadingFirstTime) {
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
                    _buildAccessStatus(),
                    const SizedBox(height: 16),
                    _buildPaymentButton(),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Courses (${courses.length})',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_isLoadingCourses)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildCourseList(),
            // Show subtle loading indicator at bottom if refreshing
            if (_isLoadingCourses && showCachedData)
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
