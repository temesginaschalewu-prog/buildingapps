import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/exam_provider.dart';
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
  late Course _course;
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _course = ModalRoute.of(context)!.settings.arguments as Course;
    _loadData();
  }

  Future<void> _loadData() async {
    final chapterProvider =
        Provider.of<ChapterProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    await chapterProvider.loadChaptersByCourse(_course.id);
    await examProvider.loadExamsByCourse(_course.id);
  }

  @override
  Widget build(BuildContext context) {
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);

    final chapters = chapterProvider.getChaptersByCourse(_course.id);
    final exams = examProvider.getExamsByCourse(_course.id);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_course.name),
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
            // Chapters Tab
            if (chapterProvider.isLoading)
              const LoadingIndicator()
            else
              RefreshIndicator(
                onRefresh: () =>
                    chapterProvider.loadChaptersByCourse(_course.id),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChapterCard(
                        chapter: chapter,
                        onTap: () {
                          GoRouter.of(context)
                              .push('/chapter/${chapter.id}', extra: chapter);
                        },
                      ),
                    );
                  },
                ),
              ),
            // Exams Tab
            if (examProvider.isLoading)
              const LoadingIndicator()
            else
              RefreshIndicator(
                onRefresh: () => examProvider.loadExamsByCourse(_course.id),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ExamCard(
                        exam: exam,
                        onTap: () {
                          GoRouter.of(context)
                              .push('/exam/${exam.id}', extra: exam);
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
