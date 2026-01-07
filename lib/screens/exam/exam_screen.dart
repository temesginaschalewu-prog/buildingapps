import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../providers/exam_question_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/exam/question_widget.dart';
import '../../utils/helpers.dart';

class ExamScreen extends StatefulWidget {
  final int examId;

  const ExamScreen({super.key, required this.examId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late Exam _exam;
  int _currentQuestionIndex = 0;
  Map<int, String?> _answers = {};
  bool _isLoading = false;
  bool _showInstructions = true;
  Duration _remainingTime = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exam = ModalRoute.of(context)!.settings.arguments as Exam;
    _remainingTime = _exam.remainingTime;
    _loadExamQuestions();
    _startTimer();
  }

  Future<void> _loadExamQuestions() async {
    final provider = Provider.of<ExamQuestionProvider>(context, listen: false);
    await provider.loadExamQuestions(_exam.id);
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
            _startTimer();
          }
        });
      }
    });
  }

  void _selectAnswer(String? answer) {
    setState(() {
      final questions =
          Provider.of<ExamQuestionProvider>(context, listen: false)
              .getQuestionsByExam(_exam.id);
      final question = questions[_currentQuestionIndex];
      _answers[question.id] = answer;
    });
  }

  void _nextQuestion() {
    final questions = Provider.of<ExamQuestionProvider>(context, listen: false)
        .getQuestionsByExam(_exam.id);

    if (_currentQuestionIndex < questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _submitExam() async {
    final confirmed = await showConfirmDialog(
      context,
      'Submit Exam',
      'Are you sure you want to submit the exam? You cannot change answers after submission.',
      () async {
        _doSubmitExam();
      },
    );
  }

// Update the _doSubmitExam method in lib/screens/exam/exam_screen.dart

  Future<void> _doSubmitExam() async {
    setState(() => _isLoading = true);

    final provider = Provider.of<ExamQuestionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final questions = provider.getQuestionsByExam(_exam.id);

    // Prepare answers for submission
    final answerList = questions.map((question) {
      return {
        'question_id': question.id,
        'selected_option': _answers[question.id] ?? '',
      };
    }).toList();

    try {
      // First start the exam if not already started
      debugLog('ExamScreen', 'Starting exam: ${_exam.id}');
      final startResponse = await provider.apiService.startExam(_exam.id);
      final examResultId = startResponse.data?['exam_result_id'];

      if (examResultId == null) {
        throw Exception('Failed to start exam');
      }

      debugLog('ExamScreen', 'Exam started with result ID: $examResultId');

      // Submit exam answers
      debugLog('ExamScreen', 'Submitting exam answers...');
      final submitResponse =
          await provider.apiService.submitExam(examResultId, answerList);

      if (submitResponse.data?['success'] == true) {
        showSnackBar(context, 'Exam submitted successfully!');

        // Refresh user's exam results
        final examProvider = Provider.of<ExamProvider>(context, listen: false);
        await examProvider.loadMyExamResults();

        // Navigate back
        GoRouter.of(context).pop();
      } else {
        throw Exception(
            submitResponse.data?['message'] ?? 'Failed to submit exam');
      }
    } catch (e) {
      showSnackBar(context, 'Failed to submit exam: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final questionProvider = Provider.of<ExamQuestionProvider>(context);
    final questions = questionProvider.getQuestionsByExam(_exam.id);

    // Check if user has access to exam
    if (authProvider.user?.accountStatus != 'active') {
      return Scaffold(
        appBar: AppBar(title: Text(_exam.title)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Exam Locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('This exam is available for active subscribers only.'),
            ],
          ),
        ),
      );
    }

    if (_showInstructions) {
      return _buildInstructionsScreen();
    }

    if (questionProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_exam.title)),
        body: const Center(
          child: Text('No questions available for this exam.'),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final totalQuestions = questions.length;
    final answeredQuestions = _answers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_exam.title),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_remainingTime.inHours}:${(_remainingTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Time remaining',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (answeredQuestions / totalQuestions),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),

          // Question Counter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$answeredQuestions/$totalQuestions answered',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: QuestionWidget(
                question: currentQuestion,
                selectedAnswer: _answers[currentQuestion.id],
                onAnswerSelected: _selectAnswer,
              ),
            ),
          ),

          // Navigation Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _previousQuestion,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  onPressed: _nextQuestion,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),

          // Submit Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitExam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Exam',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsScreen() {
    return Scaffold(
      appBar: AppBar(title: Text(_exam.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Instructions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Please read the following instructions carefully:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInstructionItem(
                'Total Questions:', '${_exam.duration} minutes'),
            _buildInstructionItem('Time Limit:', '${_exam.duration} minutes'),
            _buildInstructionItem('Passing Score:', '${_exam.passingScore}%'),
            _buildInstructionItem('Max Attempts:', '${_exam.maxAttempts}'),
            const SizedBox(height: 24),
            const Text(
              'Important Rules:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildRuleItem('1. Do not close the app during the exam'),
            _buildRuleItem('2. Timer will continue even if app is minimized'),
            _buildRuleItem('3. Answers are saved automatically'),
            _buildRuleItem('4. You can navigate between questions'),
            _buildRuleItem('5. Submit only when you are finished'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showInstructions = false);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Exam',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
