import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'chapter_content_screen.dart';

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key, required this.course});

  final CourseItem course;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  late Future<List<ChapterItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getChaptersByCourse(widget.course.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(title: Text(widget.course.name)),
      body: FutureBuilder<List<ChapterItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load chapters.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          final chapters = snapshot.data ?? const <ChapterItem>[];
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              return TvFocusCard(
                autofocus: index == 0,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChapterContentScreen(chapter: chapter),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: chapter.accessible
                            ? const Color(0xFF1D4A80)
                            : const Color(0xFF4A2A2A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        chapter.accessible ? Icons.lock_open : Icons.lock,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            chapter.accessible ? 'Ready to open' : 'Locked content',
                            style: const TextStyle(
                              color: Color(0xFFB8C6E3),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: chapters.length,
          );
        },
      ),
    );
  }
}
