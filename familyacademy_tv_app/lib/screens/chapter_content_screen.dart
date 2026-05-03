import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'video_player_screen.dart';

enum ContentTab { videos, notes, questions }

class ChapterContentScreen extends StatefulWidget {
  const ChapterContentScreen({super.key, required this.chapter});

  final ChapterItem chapter;

  @override
  State<ChapterContentScreen> createState() => _ChapterContentScreenState();
}

class _ChapterContentScreenState extends State<ChapterContentScreen> {
  ContentTab _tab = ContentTab.videos;
  late Future<List<VideoItem>> _videosFuture;
  late Future<List<NoteItem>> _notesFuture;
  late Future<List<QuestionItem>> _questionsFuture;
  final Map<int, String> _selectedAnswers = {};
  final Set<int> _revealedAnswers = {};
  final Set<int> _savedQuestionResults = {};
  int _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    final api = context.read<TvApiService>();
    _videosFuture = api.getVideosByChapter(widget.chapter.id);
    _notesFuture = api.getNotesByChapter(widget.chapter.id);
    _questionsFuture = api.getPracticeQuestions(widget.chapter.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(title: Text(widget.chapter.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                _TabButton(
                  title: 'Videos',
                  selected: _tab == ContentTab.videos,
                  autofocus: true,
                  onTap: () => setState(() => _tab = ContentTab.videos),
                ),
                const SizedBox(width: 12),
                _TabButton(
                  title: 'Notes',
                  selected: _tab == ContentTab.notes,
                  onTap: () => setState(() => _tab = ContentTab.notes),
                ),
                const SizedBox(width: 12),
                _TabButton(
                  title: 'Practice',
                  selected: _tab == ContentTab.questions,
                  onTap: () => setState(() => _tab = ContentTab.questions),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case ContentTab.videos:
        return FutureBuilder<List<VideoItem>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final videos = snapshot.data ?? const <VideoItem>[];
            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 1.55,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return TvFocusCard(
                  autofocus: index == 0,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
                          video: video,
                          chapterId: widget.chapter.id,
                        ),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: video.thumbnailUrl?.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: video.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => _videoFallback(video),
                              )
                            : _videoFallback(video),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x12000000), Color(0xD8111622)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Play',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      case ContentTab.notes:
        return FutureBuilder<List<NoteItem>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = snapshot.data ?? const <NoteItem>[];
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final note = notes[index];
                return TvFocusCard(
                  autofocus: index == 0,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _NoteReaderScreen(
                          note: note,
                          chapterId: widget.chapter.id,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _previewText(note),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD6E0F5),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Open note',
                        style: TextStyle(
                          color: Color(0xFF8FC8FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      case ContentTab.questions:
        return FutureBuilder<List<QuestionItem>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final questions = snapshot.data ?? const <QuestionItem>[];
            if (questions.isEmpty) {
              return const Center(
                child: Text(
                  'No practice questions yet.',
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
              );
            }
            if (_questionIndex >= questions.length) {
              _questionIndex = questions.length - 1;
            }
            final question = questions[_questionIndex];
            final revealed = _revealedAnswers.contains(question.id);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_questionIndex + 1} of ${questions.length}',
                    style: const TextStyle(
                      color: Color(0xFF8FC8FF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111D35),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question.questionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ...question.options.map((option) {
                                final letter = option.split('.').first.trim().toUpperCase();
                                final selected = _selectedAnswers[question.id] == letter;
                                final isCorrect =
                                    revealed && letter == question.correctOption.toUpperCase();
                                final isWrongSelection = revealed && selected && !isCorrect;
                                final color = isCorrect
                                    ? const Color(0xFF1E6D44)
                                    : isWrongSelection
                                        ? const Color(0xFF6A2A2A)
                                        : selected
                                            ? const Color(0xFF1D4A80)
                                            : const Color(0xFF18253E);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TvFocusCard(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAnswers[question.id] = letter;
                                      });
                                    },
                                    padding: const EdgeInsets.all(16),
                                    backgroundColor: color,
                                    borderRadius: 18,
                                    focusedBorderColor: const Color(0xFF8FC8FF),
                                    unfocusedBorderColor: selected
                                        ? const Color(0xFF8FC8FF)
                                        : Colors.white10,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        option,
                                        style: const TextStyle(
                                          color: Color(0xFFD6E0F5),
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (revealed) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Correct answer: ${question.correctOption}',
                                  style: const TextStyle(
                                    color: Color(0xFF82D6A2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (revealed && question.explanation?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  question.explanation!,
                                  style: const TextStyle(
                                    color: Color(0xFFB8C6E3),
                                    fontSize: 15,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuestionActionChip(
                        label: revealed ? 'Hide Answer' : 'Check Answer',
                        autofocus: true,
                        onPressed: () {
                          final selected = _selectedAnswers[question.id];
                          setState(() {
                            if (revealed) {
                              _revealedAnswers.remove(question.id);
                            } else {
                              _revealedAnswers.add(question.id);
                            }
                          });
                          if (selected != null &&
                              !_savedQuestionResults.contains(question.id)) {
                            _savedQuestionResults.add(question.id);
                            final isCorrect =
                                selected.toUpperCase() == question.correctOption.toUpperCase();
                            context
                                .read<TvApiService>()
                                .saveUserProgress(
                                  chapterId: widget.chapter.id,
                                  questionsAttempted: 1,
                                  questionsCorrect: isCorrect ? 1 : 0,
                                )
                                .catchError((_) {});
                          }
                        },
                      ),
                      _QuestionActionChip(
                        label: 'Reset',
                        onPressed: () {
                          setState(() {
                            _selectedAnswers.remove(question.id);
                            _revealedAnswers.remove(question.id);
                          });
                        },
                      ),
                      _QuestionActionChip(
                        label: 'Previous',
                        onPressed: _questionIndex == 0
                            ? null
                            : () {
                                setState(() => _questionIndex -= 1);
                              },
                      ),
                      _QuestionActionChip(
                        label: _questionIndex == questions.length - 1
                            ? 'Done'
                            : 'Next',
                        onPressed: _questionIndex == questions.length - 1
                            ? null
                            : () {
                                setState(() => _questionIndex += 1);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _videoFallback(VideoItem video) {
    return Container(
      color: const Color(0xFF16304F),
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_fill_rounded,
        color: Colors.white,
        size: 72,
      ),
    );
  }

  String _stripHtml(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _previewText(NoteItem note) {
    final plain = _stripHtml(note.content);
    final hasTable = note.content.toLowerCase().contains('<table');
    final hasImage = note.content.toLowerCase().contains('<img') || _looksLikeImage(note.filePath);
    if (hasTable || hasImage) {
      final richParts = <String>[
        if (hasTable) 'Table',
        if (hasImage) 'Image',
      ].join(' + ');
      if (plain.isEmpty) {
        return '$richParts content';
      }
      return '$richParts content • $plain';
    }
    return plain;
  }

  bool _looksLikeImage(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}

class _NoteReaderScreen extends StatelessWidget {
  const _NoteReaderScreen({
    required this.note,
    required this.chapterId,
  });

  final NoteItem note;
  final int chapterId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<TvApiService>();
    api.saveUserProgress(chapterId: chapterId, notesViewed: true).catchError((_) {});

    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(title: Text(note.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF111D35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_looksLikeImage(note.filePath)) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: note.filePath!,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                HtmlWidget(
                  note.content,
                  textStyle: const TextStyle(
                    color: Color(0xFFD6E0F5),
                    fontSize: 20,
                    height: 1.7,
                  ),
                  customStylesBuilder: (element) {
                    switch (element.localName) {
                      case 'table':
                        return {
                          'width': '100%',
                          'border-collapse': 'collapse',
                          'background-color': '#0D172C',
                          'border': '1px solid rgba(255,255,255,0.24)',
                          'margin-bottom': '16px',
                        };
                      case 'th':
                        return {
                          'background-color': '#1A2743',
                          'color': '#FFFFFF',
                          'padding': '10px',
                          'border': '1px solid rgba(255,255,255,0.16)',
                        };
                      case 'td':
                        return {
                          'color': '#D6E0F5',
                          'padding': '10px',
                          'border': '1px solid rgba(255,255,255,0.12)',
                        };
                      case 'img':
                        return {
                          'max-width': '100%',
                          'height': 'auto',
                          'display': 'block',
                          'margin-bottom': '16px',
                        };
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _looksLikeImage(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}

class _QuestionActionChip extends StatelessWidget {
  const _QuestionActionChip({
    required this.label,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TvFocusCard(
        autofocus: autofocus,
        onPressed: onPressed ?? () {},
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Opacity(
          opacity: onPressed == null ? 0.45 : 1,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final String title;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: TvFocusCard(
        autofocus: autofocus,
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
