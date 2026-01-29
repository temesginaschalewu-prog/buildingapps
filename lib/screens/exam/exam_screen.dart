import 'dart:async';

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
  final Exam? exam;

  const ExamScreen({
    super.key,
    required this.examId,
    this.exam,
  });

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
  Timer? _timer;
  Duration? _userTimeLimit;

  @override
  void initState() {
    super.initState();
    _initializeExam();
  }

  void _initializeExam() {
    if (widget.exam != null) {
      _exam = widget.exam!;
    } else {
      // Try to get exam from provider
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final exam = examProvider.getExamById(widget.examId);
      if (exam != null) {
        _exam = exam;
      } else {
        // Default exam to prevent errors
        _exam = Exam(
          id: widget.examId,
          title: 'Loading Exam...',
          examType: 'weekly',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(hours: 1)),
          duration: 60,
          userTimeLimit: null,
          passingScore: 50,
          maxAttempts: 1,
          autoSubmit: true,
          showResultsImmediately: false,
          courseName: 'Loading...',
          courseId: 0,
          categoryId: 0,
          categoryName: 'Loading...',
          attemptsTaken: 0,
          status: 'available',
          message: 'Loading...',
          canTakeExam: false,
          requiresPayment: false,
          actualDuration: 60,
          timingType: 'exam_wide',
        );
      }
    }

    // Determine which time limit to use
    _userTimeLimit = _exam.userTimeLimit != null
        ? Duration(minutes: _exam.userTimeLimit!)
        : null;

    // Start with exam-wide time limit, will switch to user limit when they start
    _remainingTime = Duration(minutes: _exam.duration);
    _loadExamQuestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If exam wasn't passed as argument, try to get it from ModalRoute
    if (widget.exam == null) {
      final routeExam = ModalRoute.of(context)?.settings.arguments;
      if (routeExam is Exam) {
        _exam = routeExam;

        // Update time limits
        _userTimeLimit = _exam.userTimeLimit != null
            ? Duration(minutes: _exam.userTimeLimit!)
            : null;
        _remainingTime = Duration(minutes: _exam.duration);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExamQuestions() async {
    final provider = Provider.of<ExamQuestionProvider>(context, listen: false);
    await provider.loadExamQuestions(_exam.id);
  }

  void _startTimer() {
    // If user time limit is set, use that instead of exam-wide time
    if (_userTimeLimit != null) {
      _remainingTime = _userTimeLimit!;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            // Time's up!
            timer.cancel();
            if (_exam.autoSubmit) {
              _autoSubmitExam();
            } else {
              _showTimeUpWarning();
            }
          }
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _showTimeUpWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: const Text(
            'The exam time has expired. Please submit your answers.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );
  }

  void _selectAnswer(String? answer) {
    setState(() {
      final questions = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      ).getQuestionsByExam(_exam.id);
      if (_currentQuestionIndex < questions.length) {
        final question = questions[_currentQuestionIndex];
        _answers[question.id] = answer;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      final questions = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      ).getQuestionsByExam(_exam.id);
      if (_currentQuestionIndex < questions.length - 1) {
        _currentQuestionIndex++;
      }
    });
  }

  void _previousQuestion() {
    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      }
    });
  }

  Future<void> _submitExam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam'),
        content: const Text(
          'Are you sure you want to submit the exam? '
          'You cannot change answers after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _doSubmitExam();
    }
  }

  Future<void> _autoSubmitExam() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content:
            const Text('The exam time has expired. Submitting your answers...'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('OK'),
          ),
        ],
      ),
    );

    await _doSubmitExam();
  }

  Future<void> _doSubmitExam() async {
    setState(() => _isLoading = true);
    _stopTimer();

    try {
      final provider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final questions = provider.getQuestionsByExam(_exam.id);

      // Prepare answers for submission
      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? '',
        };
      }).toList();

      // First start the exam if not already started
      debugLog('ExamScreen', 'Submitting exam: ${_exam.id}');

      // Get exam result ID from previous start or start new one
      int examResultId;
      try {
        final startResponse = await provider.apiService.startExam(_exam.id);
        examResultId = startResponse.data?['exam_result_id'] ?? 0;
      } catch (e) {
        // If already started, we might get an error
        // In a real app, you should track the exam result ID properly
        examResultId = DateTime.now().millisecondsSinceEpoch;
      }

      // Submit exam answers
      final submitResponse = await provider.apiService.submitExam(
        examResultId,
        answerList,
      );

      if (submitResponse.data?['success'] == true) {
        showSnackBar(context, 'Exam submitted successfully!');

        // Refresh user's exam results
        final examProvider = Provider.of<ExamProvider>(context, listen: false);
        await examProvider.loadMyExamResults();

        // Navigate back
        if (mounted) {
          GoRouter.of(context).pop();
        }
      } else {
        throw Exception(
            submitResponse.data?['message'] ?? 'Failed to submit exam');
      }
    } catch (e) {
      showSnackBar(context, 'Failed to submit exam: $e', isError: true);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeLimitDescription() {
    if (_exam.hasUserTimeLimit) {
      return '${_exam.userTimeLimit} minutes per attempt';
    } else {
      return '${_exam.duration} minutes exam-wide';
    }
  }

  String _getAutoSubmitDescription() {
    return _exam.autoSubmit
        ? 'Auto-submit when time expires'
        : 'Manual submission required';
  }

  String _getResultsDisplayDescription() {
    return _exam.showResultsImmediately
        ? 'Results shown immediately after submission'
        : 'Results available after exam ends';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final questionProvider = Provider.of<ExamQuestionProvider>(context);
    final questions = questionProvider.getQuestionsByExam(_exam.id);

    // Check if user has access to exam
    if (authProvider.user?.accountStatus != 'active') {
      return Scaffold(
        appBar: AppBar(
          title: Text(_exam.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Exam Locked',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This exam is available for active subscribers only.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showInstructions) {
      return _buildInstructionsScreen();
    }

    if (questionProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_exam.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading exam questions...'),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_exam.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No Questions Available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This exam currently has no questions.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentQuestionIndex >= questions.length) {
      _currentQuestionIndex = 0;
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final totalQuestions = questions.length;
    final answeredQuestions = _answers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _exam.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Leave Exam?'),
                      content: const Text(
                        'Are you sure you want to leave? Your progress will be saved.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Stay'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    GoRouter.of(context).pop();
                  }
                },
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_remainingTime.inHours}:${(_remainingTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  'Time left',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicators
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Question progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$answeredQuestions/$totalQuestions answered',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress bar
                LinearProgressIndicator(
                  value: (answeredQuestions / totalQuestions),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ),

          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: QuestionWidget(
                question: currentQuestion,
                selectedAnswer: _answers[currentQuestion.id],
                onAnswerSelected: _selectAnswer,
              ),
            ),
          ),

          // Navigation and Submit buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _currentQuestionIndex > 0 ? _previousQuestion : null,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 45),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _currentQuestionIndex < totalQuestions - 1
                          ? _nextQuestion
                          : null,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitExam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Submit Exam',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsScreen() {
    final totalTime = Duration(minutes: _exam.duration);

    return Scaffold(
      appBar: AppBar(
        title: Text(_exam.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 24, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please read the instructions carefully before starting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Exam Details
            const Text(
              'Exam Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildDetailItem('Exam Title:', _exam.title),
            _buildDetailItem('Exam Type:', _exam.examType.toUpperCase()),
            _buildDetailItem('Course:', _exam.courseName),
            _buildDetailItem('Time Limit:', _getTimeLimitDescription()),
            _buildDetailItem('Auto Submit:', _getAutoSubmitDescription()),
            _buildDetailItem(
                'Results Display:', _getResultsDisplayDescription()),
            _buildDetailItem('Passing Score:', '${_exam.passingScore}%'),
            _buildDetailItem('Max Attempts:', '${_exam.maxAttempts}'),
            _buildDetailItem('Your Attempts:',
                '${_exam.attemptsTaken}/${_exam.maxAttempts}'),
            const SizedBox(height: 24),

            // Timing Information
            if (_exam.hasUserTimeLimit)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Timer: ${_exam.userTimeLimit} minutes',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Timer starts when you begin and counts down independently.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Important Rules
            const Text(
              'Important Rules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildRuleItem(
              'Do not close the app or switch to another app during the exam',
              Icons.block,
            ),
            _buildRuleItem(
              _exam.hasUserTimeLimit
                  ? 'Your personal timer will continue even if you minimize the app'
                  : 'Timer will continue running even if you minimize the app',
              Icons.timer,
            ),
            _buildRuleItem(
              'Answers are saved automatically as you select them',
              Icons.save,
            ),
            _buildRuleItem(
              'You can navigate between questions using Previous/Next buttons',
              Icons.swap_horiz,
            ),
            _buildRuleItem(
              'Submit only when you are finished with all questions',
              Icons.check_circle,
            ),
            _buildRuleItem(
              'Once submitted, you cannot change your answers',
              Icons.lock,
            ),
            if (_exam.autoSubmit)
              _buildRuleItem(
                'Exam will auto-submit when time expires',
                Icons.autorenew,
              ),
            const SizedBox(height: 32),

            // Start Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showInstructions = false);
                  _startTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Start Exam Now',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => GoRouter.of(context).pop(),
                child: const Text(
                  'Cancel and Go Back',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
