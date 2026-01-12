import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/chapter_model.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/helpers.dart';

class ChapterListScreen extends StatefulWidget {
  final int courseId;

  const ChapterListScreen({super.key, required this.courseId});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  late int _categoryId;
  late String _categoryName;

  @override
  void initState() {
    super.initState();
    _loadCourseInfo();
  }

  Future<void> _loadCourseInfo() async {
    try {
      final courseProvider =
          Provider.of<CourseProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      final course = courseProvider.getCourseById(widget.courseId);
      if (course != null) {
        _categoryId = course.categoryId;
        final category = categoryProvider.getCategoryById(_categoryId);
        _categoryName = category?.name ?? 'Category';
      }
    } catch (e) {
      debugLog('ChapterListScreen', 'Error loading course info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final chapters = chapterProvider.getChaptersByCourse(widget.courseId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapters'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: chapterProvider.isLoading
          ? const LoadingIndicator()
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
                    onTap: () {},
                  ),
                );
              },
            ),
    );
  }
}
