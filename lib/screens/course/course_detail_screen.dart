import 'dart:async';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/chapter_model.dart';
import '../../models/exam_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/helpers.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  final Course? course;
  final Category? category;
  final bool? hasAccess;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.course,
    this.category,
    this.hasAccess,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late int _selectedTab = 0;
  bool _isLoading = true;
  Course? _course;
  String _categoryName = '';
  int _categoryId = 0;
  Category? _category;
  bool _hasAccess = false;
  bool _hasPendingPayment = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCourseDataFromCache();
    _loadData();

    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        _checkAccessStatus();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Try to get course from cache first
  void _loadCourseDataFromCache() {
    final courseProvider = Provider.of<CourseProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    // Check if course is passed directly
    if (widget.course != null) {
      _course = widget.course;
      _categoryId = widget.course!.categoryId;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Try to find course in cache
    Course? foundCourse;

    for (final category in categoryProvider.categories) {
      final courses = courseProvider.getCoursesByCategory(category.id);
      for (final course in courses) {
        if (course.id == widget.courseId) {
          foundCourse = course;
          _categoryId = category.id;
          _categoryName = category.name;
          _category = category;
          break;
        }
      }
      if (foundCourse != null) break;
    }

    if (foundCourse != null) {
      _course = foundCourse;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    final chapterProvider = Provider.of<ChapterProvider>(
      context,
      listen: false,
    );
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    try {
      // If course not found in cache, try to load it
      if (_course == null) {
        Course? foundCourse;

        // Try loading categories if not already loaded
        if (categoryProvider.categories.isEmpty) {
          await categoryProvider.loadCategories();
        }

        for (final category in categoryProvider.categories) {
          // Load courses for this category
          if (courseProvider.getCoursesByCategory(category.id).isEmpty) {
            await courseProvider.loadCoursesByCategory(category.id);
          }

          final courses = courseProvider.getCoursesByCategory(category.id);

          for (final course in courses) {
            if (course.id == widget.courseId) {
              foundCourse = course;
              _categoryId = category.id;
              _categoryName = category.name;
              _category = category;
              break;
            }
          }

          if (foundCourse != null) break;
        }

        if (foundCourse == null) {
          debugLog('CourseDetailScreen', 'Course ${widget.courseId} not found');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        _course = foundCourse;
      }

      if (widget.category != null) {
        _category = widget.category;
        _categoryId = widget.category!.id;
        _categoryName = widget.category!.name;
      } else if (_category == null) {
        final category = categoryProvider.getCategoryById(_categoryId);
        _category = category;
        _categoryName = category?.name ?? 'Category';
      }

      if (widget.hasAccess != null) {
        _hasAccess = widget.hasAccess!;
      } else {
        await _checkAccessStatus();
      }

      // Load chapters and exams in background
      // Don't wait for them to complete
      unawaited(chapterProvider.loadChaptersByCourse(widget.courseId));
      unawaited(examProvider.loadAvailableExams(courseId: widget.courseId));
    } catch (e) {
      debugLog('CourseDetailScreen', 'Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAccessStatus() async {
    if (_category == null) return;

    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );

    // Check cache first
    _hasAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(_categoryId);

    // Refresh in background if needed
    unawaited(subscriptionProvider.loadSubscriptions());
    unawaited(paymentProvider.loadPayments());
  }

  void _handleChapterTap(Chapter chapter) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final paymentProvider = Provider.of<PaymentProvider>(
      context,
      listen: false,
    );

    if (chapter.isFree || _hasAccess) {
      context.push('/chapter/${chapter.id}', extra: {
        'chapter': chapter,
        'course': _course,
        'category': _category,
        'hasAccess': _hasAccess
      });
    } else if (_hasPendingPayment) {
      _showPendingPaymentDialog();
    } else {
      _showPaymentDialogForCategory(_categoryId);
    }
  }

  void _showPaymentDialogForCategory(int categoryId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final category = categoryProvider.getCategoryById(categoryId);

    if (category == null) {
      showSnackBar(context, 'Category not found', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Text(
          'You need to purchase "${category.name}" to access this content.',
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
                  'category': category,
                  'paymentType': subscriptionProvider
                          .hasActiveSubscriptionForCategory(categoryId)
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

  Widget _buildAccessBanner() {
    if (_hasAccess) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Full access - All content unlocked',
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
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Row(
          children: [
            Icon(Icons.pending, color: Colors.orange, size: 20),
            SizedBox(width: 8),
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
                  SizedBox(height: 4),
                  Text(
                    'Please wait for admin verification',
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
    } else if (_category?.isFree ?? false) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.blue, size: 20),
            SizedBox(width: 8),
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
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Limited access - Free chapters only',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showPaymentDialogForCategory(_categoryId),
              child: const Text('Purchase'),
            ),
          ],
        ),
      );
    }
  }

  void _handleExamTap(Exam exam) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );

    if (exam.canTakeExam) {
      context.push('/exam/${exam.id}', extra: exam);
    } else if (exam.requiresPayment) {
      final category = categoryProvider.getCategoryById(exam.categoryId);

      if (category == null) {
        showSnackBar(context, 'Category not found', isError: true);
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Required'),
          content: Text(
            'You need to purchase "${exam.categoryName}" to take this exam.',
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
                    'category': category,
                    'paymentType': subscriptionProvider
                            .hasActiveSubscriptionForCategory(exam.categoryId)
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
  }

  @override
  Widget build(BuildContext context) {
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);

    final chapters = chapterProvider.getChaptersByCourse(widget.courseId);
    final exams = examProvider.getExamsByCourse(widget.courseId);

    // Show course info immediately if we have it, even while loading
    if (_isLoading && _course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const LoadingIndicator(),
      );
    }

    if (_course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course Not Found')),
        body: const Center(
          child: Text('Course not found or no longer available.'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_course!.name),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Chapters'),
              Tab(text: 'Exams'),
            ],
            onTap: (index) => setState(() => _selectedTab = index),
          ),
        ),
        body: Column(
          children: [
            _buildAccessBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  // Chapters Tab
                  _buildChaptersTab(chapterProvider, chapters),

                  // Exams Tab
                  _buildExamsTab(examProvider, exams),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersTab(
      ChapterProvider chapterProvider, List<Chapter> chapters) {
    return chapterProvider.isLoading && chapters.isEmpty
        ? const LoadingIndicator()
        : RefreshIndicator(
            onRefresh: () async {
              await chapterProvider.loadChaptersByCourse(widget.courseId);
              await _checkAccessStatus();
            },
            child: chapters.isEmpty
                ? const Center(
                    child: Text(
                      'No chapters available for this course.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ChapterCard(
                          chapter: chapter,
                          courseId: widget.courseId,
                          categoryId: _categoryId,
                          categoryName: _categoryName,
                          onTap: () => _handleChapterTap(chapter),
                        ),
                      );
                    },
                  ),
          );
  }

  Widget _buildExamsTab(ExamProvider examProvider, List<Exam> exams) {
    return examProvider.isLoading && exams.isEmpty
        ? const LoadingIndicator()
        : RefreshIndicator(
            onRefresh: () async {
              await examProvider.loadAvailableExams(courseId: widget.courseId);
              await _checkAccessStatus();
            },
            child: exams.isEmpty
                ? const Center(
                    child: Text('No exams available for this course.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ExamCard(
                          exam: exam,
                          onTap: () => _handleExamTap(exam),
                        ),
                      );
                    },
                  ),
          );
  }
}
