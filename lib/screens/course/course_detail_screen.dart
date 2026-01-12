import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/helpers.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late int _selectedTab = 0;
  bool _isLoading = true;
  Course? _course;
  String _categoryName = '';
  int _categoryId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      Course? foundCourse;

      await categoryProvider.loadCategories();

      for (final category in categoryProvider.categories) {
        await courseProvider.loadCoursesByCategory(category.id);
        final courses = courseProvider.getCoursesByCategory(category.id);

        for (final course in courses) {
          if (course.id == widget.courseId) {
            foundCourse = course;
            _categoryId = category.id;
            _categoryName = category.name;
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

      await Future.wait([
        chapterProvider.loadChaptersByCourse(widget.courseId),
        examProvider.loadExamsByCourse(widget.courseId),
      ]);
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

  void _handleChapterTap(Chapter chapter) {
    final context = this.context;
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );

    final hasAccess = subscriptionProvider.hasActiveSubscriptionForCategory(
      _course!.categoryId,
    );

    if (chapter.isFree || hasAccess) {
      context.push('/chapter/${chapter.id}', extra: chapter);
    } else {
      _showPaymentDialogForCategory(_course!.categoryId);
    }
  }

  void _showPaymentDialogForCategory(int categoryId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final router = GoRouter.of(context);

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
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    final chapters = chapterProvider.getChaptersByCourse(widget.courseId);
    final exams = examProvider.getExamsByCourse(widget.courseId);

    bool hasCategoryAccess = false;
    if (_course != null) {
      hasCategoryAccess = subscriptionProvider.hasActiveSubscriptionForCategory(
        _course!.categoryId,
      );
    }

    if (_isLoading) {
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
        body: TabBarView(
          children: [
            if (chapterProvider.isLoading)
              const LoadingIndicator()
            else
              RefreshIndicator(
                onRefresh: () =>
                    chapterProvider.loadChaptersByCourse(widget.courseId),
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
                              onTap: () => _handleChapterTap(chapter),
                              courseId: widget.courseId,
                              categoryName: _categoryName,
                              categoryId: _categoryId,
                            ),
                          );
                        },
                      ),
              ),
            if (examProvider.isLoading)
              const LoadingIndicator()
            else
              RefreshIndicator(
                onRefresh: () =>
                    examProvider.loadExamsByCourse(widget.courseId),
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
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );

                                if (exam.canTakeExam) {
                                  context.push('/exam/${exam.id}', extra: exam);
                                } else if (exam.requiresPayment) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Payment Required'),
                                      content: Text(
                                        'You need to purchase "${exam.categoryName}" to take this exam.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            context.push(
                                              '/payment',
                                              extra: {
                                                'category': {
                                                  'id': exam.categoryId,
                                                  'name': exam.categoryName,
                                                },
                                                'paymentType': authProvider.user
                                                            ?.accountStatus ==
                                                        'active'
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
                              },
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
