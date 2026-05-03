import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'chapter_content_screen.dart';
import 'exam_session_screen.dart';

enum _CourseDetailTab { chapters, exams }

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.category,
  });

  final CourseItem course;
  final CategoryItem category;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  _CourseDetailTab _tab = _CourseDetailTab.chapters;
  late Future<List<ChapterItem>> _chaptersFuture;
  late Future<List<ExamItem>> _examsFuture;

  @override
  void initState() {
    super.initState();
    final api = context.read<TvApiService>();
    _chaptersFuture = api.getChaptersByCourse(widget.course.id);
    _examsFuture = api.getAvailableExams(courseId: widget.course.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(title: Text(widget.course.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF112241),
                    Color(0xFF193458),
                  ],
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.name,
                          style: const TextStyle(
                            color: Color(0xFF8FC8FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.course.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.course.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.course.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD6E1F6),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _InfoPill(label: '${widget.course.chapterCount} chapters'),
                      if (widget.course.access?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _InfoPill(label: widget.course.access!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TopTab(
                  title: 'Chapters',
                  selected: _tab == _CourseDetailTab.chapters,
                  autofocus: true,
                  onPressed: () => setState(() => _tab = _CourseDetailTab.chapters),
                ),
                const SizedBox(width: 12),
                _TopTab(
                  title: 'Exams',
                  selected: _tab == _CourseDetailTab.exams,
                  onPressed: () => setState(() => _tab = _CourseDetailTab.exams),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _tab == _CourseDetailTab.chapters
                  ? _buildChapters()
                  : _buildExams(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapters() {
    return FutureBuilder<List<ChapterItem>>(
      future: _chaptersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage('Could not load chapters.\n${snapshot.error}');
        }
        final chapters = snapshot.data ?? const <ChapterItem>[];
        if (chapters.isEmpty) {
          return const _StateMessage('No chapters are available for this course yet.');
        }
        return ListView.separated(
          itemCount: chapters.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return TvFocusCard(
              autofocus: index == 0,
              onPressed: chapter.accessible
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChapterContentScreen(chapter: chapter),
                        ),
                      );
                    }
                  : () {},
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: chapter.accessible
                          ? const Color(0xFF1D4A80)
                          : const Color(0xFF4A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      chapter.accessible ? Icons.play_lesson_rounded : Icons.lock_rounded,
                      color: Colors.white,
                      size: 30,
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          chapter.accessible
                              ? 'Open chapter content'
                              : chapter.releaseDate != null
                                  ? 'Locked until ${_formatDate(chapter.releaseDate!)}'
                                  : 'Locked content',
                          style: const TextStyle(
                            color: Color(0xFFB8C6E3),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _InfoPill(
                    label: chapter.accessible ? 'Ready' : 'Locked',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExams() {
    return FutureBuilder<List<ExamItem>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage('Could not load exams.\n${snapshot.error}');
        }
        final exams = snapshot.data ?? const <ExamItem>[];
        if (exams.isEmpty) {
          return const _StateMessage('No exams are available for this course yet.');
        }
        return ListView.separated(
          itemCount: exams.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final exam = exams[index];
            return TvFocusCard(
              autofocus: index == 0,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExamSessionScreen(exam: exam),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17385D),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (exam.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            exam.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8C6E3),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _InfoPill(label: '${exam.questionCount} questions'),
                      const SizedBox(height: 10),
                      _InfoPill(label: '${exam.durationMinutes} min'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
  });

  final String title;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: TvFocusCard(
        autofocus: autofocus,
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
