import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chapter_provider.dart';
import '../../widgets/chapter/chapter_card.dart';
import '../../widgets/common/loading_indicator.dart';

class ChapterListScreen extends StatelessWidget {
  final int courseId;

  const ChapterListScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final chapters = chapterProvider.getChaptersByCourse(courseId);

    return Scaffold(
      appBar: AppBar(title: const Text('Chapters')),
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
                    onTap: () {
                      // Navigate to chapter content
                    },
                  ),
                );
              },
            ),
    );
  }
}
