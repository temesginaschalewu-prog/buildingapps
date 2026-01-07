import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/chapter_model.dart';
import '../../providers/video_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/question_provider.dart';
import '../../widgets/common/loading_indicator.dart';

class ChapterContentScreen extends StatefulWidget {
  final int chapterId;

  const ChapterContentScreen({super.key, required this.chapterId});

  @override
  State<ChapterContentScreen> createState() => _ChapterContentScreenState();
}

class _ChapterContentScreenState extends State<ChapterContentScreen> {
  late Chapter _chapter;
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chapter = ModalRoute.of(context)!.settings.arguments as Chapter;
    _loadData();
  }

  Future<void> _loadData() async {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final questionProvider =
        Provider.of<QuestionProvider>(context, listen: false);

    await videoProvider.loadVideosByChapter(_chapter.id);
    await noteProvider.loadNotesByChapter(_chapter.id);
    await questionProvider.loadPracticeQuestions(_chapter.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_chapter.name),
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.video_library), text: 'Videos'),
              Tab(icon: Icon(Icons.note), text: 'Notes'),
              Tab(icon: Icon(Icons.quiz), text: 'Practice'),
            ],
            onTap: (index) => setState(() => _selectedTab = index),
          ),
        ),
        body: TabBarView(
          children: [
            // Videos Tab
            Consumer<VideoProvider>(
              builder: (context, videoProvider, _) {
                final videos = videoProvider.getVideosByChapter(_chapter.id);

                return videoProvider.isLoading
                    ? const LoadingIndicator()
                    : RefreshIndicator(
                        onRefresh: () =>
                            videoProvider.loadVideosByChapter(_chapter.id),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  width: 80,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: video.hasThumbnail
                                      ? Image.network(
                                          video.thumbnailUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.play_circle_fill),
                                ),
                                title: Text(video.title),
                                subtitle: Text(
                                  video.duration != null
                                      ? '${(video.duration! / 60).floor()} min'
                                      : 'Unknown duration',
                                ),
                                trailing: Text('${video.viewCount} views'),
                                onTap: () {
                                  // Navigate to video player
                                },
                              ),
                            );
                          },
                        ),
                      );
              },
            ),
            // Notes Tab
            Consumer<NoteProvider>(
              builder: (context, noteProvider, _) {
                final notes = noteProvider.getNotesByChapter(_chapter.id);

                return noteProvider.isLoading
                    ? const LoadingIndicator()
                    : RefreshIndicator(
                        onRefresh: () =>
                            noteProvider.loadNotesByChapter(_chapter.id),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.note),
                                title: Text(note.title),
                                subtitle: Text(
                                  'Created: ${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year}',
                                ),
                                onTap: () {
                                  // Show note content
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(note.title),
                                      content: SingleChildScrollView(
                                        child: Text(note.content),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              GoRouter.of(context).pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
              },
            ),
            // Practice Questions Tab
            Consumer<QuestionProvider>(
              builder: (context, questionProvider, _) {
                final questions =
                    questionProvider.getQuestionsByChapter(_chapter.id);

                return questionProvider.isLoading
                    ? const LoadingIndicator()
                    : RefreshIndicator(
                        onRefresh: () =>
                            questionProvider.loadPracticeQuestions(_chapter.id),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: questions.length,
                          itemBuilder: (context, index) {
                            final question = questions[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Question ${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      question.questionText,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    ...question.options.asMap().entries.map(
                                      (entry) {
                                        final optionIndex = entry.key;
                                        final option = entry.value;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              final result =
                                                  await questionProvider
                                                      .checkAnswer(
                                                question.id,
                                                String.fromCharCode(
                                                    65 + optionIndex),
                                              );

                                              // Show result dialog
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: Text(
                                                    result['is_correct'] == true
                                                        ? 'Correct!'
                                                        : 'Incorrect',
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        result['explanation'] ??
                                                            'No explanation available',
                                                      ),
                                                      if (result[
                                                              'is_correct'] ==
                                                          false)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 8),
                                                          child: Text(
                                                            'Correct answer: ${question.correctOption}',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.green,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Text(option),
                                            style: OutlinedButton.styleFrom(
                                              alignment: Alignment.centerLeft,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}
