import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';

class ExamSessionScreen extends StatefulWidget {
  const ExamSessionScreen({super.key, required this.exam});

  final ExamItem exam;

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int? _examResultId;
  List<ExamQuestionItem> _questions = const [];
  final Map<int, String> _answers = {};
  int _currentIndex = 0;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<TvApiService>();
      final startData = await api.startExam(widget.exam.id);
      final examResultId = (startData['exam_result_id'] as num?)?.toInt();
      final startedQuestions = ((startData['questions'] as List?) ?? const [])
          .map((item) => ExamQuestionItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final fallbackQuestions = startedQuestions.isNotEmpty
          ? startedQuestions
          : await api.getExamQuestions(widget.exam.id);

      if (!mounted) return;
      setState(() {
        _examResultId = examResultId;
        _questions = fallbackQuestions;
        final minutes = widget.exam.durationMinutes <= 0 ? 30 : widget.exam.durationMinutes;
        _remaining = Duration(minutes: minutes);
        _loading = false;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        } else {
          timer.cancel();
        }
      });
      if (_remaining.inSeconds <= 0) {
        _submitExam(auto: true);
      }
    });
  }

  Future<void> _submitExam({bool auto = false}) async {
    if (_submitting || _questions.isEmpty) return;
    if (_answers.length != _questions.length && !auto) {
      setState(() => _error = 'Please answer all questions before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    _timer?.cancel();

    try {
      final api = context.read<TvApiService>();
      var examResultId = _examResultId ?? 0;
      if (examResultId == 0) {
        final startData = await api.startExam(widget.exam.id);
        examResultId = (startData['exam_result_id'] as num?)?.toInt() ?? 0;
      }
      if (examResultId == 0) {
        throw Exception('Could not start exam session.');
      }

      final answers = _questions
          .map(
            (question) => {
              'question_id': question.id,
              'selected_option': _answers[question.id] ?? '',
            },
          )
          .toList();
      final result = await api.submitExam(examResultId, answers);
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _submitting = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09111F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_result != null) {
      final score = (_result!['score'] as num?)?.toDouble() ?? 0;
      final correct = (_result!['correct_answers'] as num?)?.toInt() ?? 0;
      final total = (_result!['total_questions'] as num?)?.toInt() ?? _questions.length;
      return Scaffold(
        backgroundColor: const Color(0xFF09111F),
        appBar: AppBar(title: Text(widget.exam.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF111D35),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Exam Completed',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${score.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFF8FC8FF), fontSize: 42, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$correct correct out of $total',
                    style: const TextStyle(color: Color(0xFFD6E1F6), fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF09111F),
        appBar: AppBar(title: Text(widget.exam.title)),
        body: Center(
          child: Text(
            _error ?? 'No questions are available for this exam.',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      appBar: AppBar(
        title: Text(widget.exam.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                _formatDuration(_remaining),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${_currentIndex + 1} of ${_questions.length}',
              style: const TextStyle(color: Color(0xFF8FC8FF), fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              question.questionText,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.4),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: question.options.length,
                separatorBuilder: (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final option = question.options[index];
                  final selected = _answers[question.id] == option.key;
                  return TvFocusCard(
                    autofocus: index == 0,
                    onPressed: () {
                      setState(() {
                        _answers[question.id] = option.key;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF1D4A80) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF8FC8FF) : const Color(0xFF1A2943),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              option.key,
                              style: TextStyle(
                                color: selected ? const Color(0xFF09111F) : Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.value,
                              style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFFB8B8), fontSize: 15),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TvFocusCard(
                    onPressed: _currentIndex == 0
                        ? () {}
                        : () => setState(() => _currentIndex -= 1),
                    child: const Center(
                      child: Text(
                        'Previous',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 180,
                  child: TvFocusCard(
                    onPressed: _currentIndex >= _questions.length - 1
                        ? () {}
                        : () => setState(() => _currentIndex += 1),
                    child: const Center(
                      child: Text(
                        'Next',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TvFocusCard(
                    onPressed: _submitting ? () {} : _submitExam,
                    child: Center(
                      child: Text(
                        _submitting ? 'Submitting...' : 'Submit Exam',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }
}
