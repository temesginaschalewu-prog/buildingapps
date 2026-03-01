import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/exam_question_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/exam_question_provider.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/exam_result_model.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/exam/question_widget.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';

class ExamScreen extends StatefulWidget {
  final int examId;
  final Exam? exam;
  final int? courseId;

  const ExamScreen({
    super.key,
    required this.examId,
    this.exam,
    this.courseId,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with TickerProviderStateMixin {
  late Exam _exam;
  int _currentQuestionIndex = 0;
  Map<int, String?> _answers = {};
  final bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showInstructions = true;
  Duration _remainingTime = Duration.zero;
  Timer? _timer;
  Duration? _userTimeLimit;
  bool _hasAccess = false;
  bool _checkingAccess = true;
  bool _hasLoadedQuestions = false;

  ExamResult? _submittedResult;
  final Map<int, Map<String, dynamic>> _answerDetails = {};
  bool _showResults = false;
  bool _hasReachedMaxAttempts = false;

  bool _hasCachedProgress = false;
  bool _isOffline = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeExam();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getCurrentUserId();

    if (widget.exam == null) {
      final routeExam = ModalRoute.of(context)?.settings.arguments;
      if (routeExam is Exam) {
        _exam = routeExam;
        _initializeExamSettings();
        _checkExamAccess();
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  void _initializeExam() {
    if (widget.exam != null) {
      _exam = widget.exam!;
      _initializeExamSettings();
      _checkExamAccess();
    } else {
      _loadExamFromProvider();
    }
  }

  void _initializeExamSettings() {
    _userTimeLimit = _exam.userTimeLimit != null
        ? Duration(minutes: _exam.userTimeLimit!)
        : null;
    _remainingTime = Duration(minutes: _exam.duration);
    _hasReachedMaxAttempts = _exam.attemptsTaken >= _exam.maxAttempts &&
        _exam.status == 'max_attempts_reached';

    if (!_hasReachedMaxAttempts) _loadCachedProgress();
  }

  Future<void> _loadCachedProgress() async {
    if (_currentUserId == null) return;

    try {
      final questionProvider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final progressData = await questionProvider.deviceService
          .getCacheItem<Map<String, dynamic>>(
        'exam_progress_${_exam.id}_$_currentUserId',
        isUserSpecific: true,
      );

      if (progressData != null && mounted && !_hasReachedMaxAttempts) {
        setState(() {
          _currentQuestionIndex = progressData['current_index'] ?? 0;
          final answers = progressData['answers'] ?? {};
          if (answers is Map) {
            _answers = Map<int, String?>.from(answers.map(
                (k, v) => MapEntry(int.parse(k.toString()), v?.toString())));
          }
          final remainingSeconds =
              progressData['remaining_time'] ?? _remainingTime.inSeconds;
          _remainingTime = Duration(seconds: remainingSeconds);
          _hasCachedProgress = true;
        });
      }
    } catch (e) {}
  }

  Future<void> _checkExamAccess() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
      return;
    }

    try {
      if (_exam.requiresPayment) {
        _hasAccess = await subscriptionProvider
            .checkHasActiveSubscriptionForCategory(_exam.categoryId);
      } else {
        _hasAccess = true;
      }

      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final existingResult = examProvider.myExamResults.firstWhere(
        (result) => result.examId == _exam.id && result.status == 'completed',
        orElse: () => null as ExamResult,
      );

      if (_exam.attemptsTaken >= _exam.maxAttempts) {
        _hasReachedMaxAttempts = true;
        _submittedResult = existingResult;
        if (existingResult.answerDetails != null) {
          for (var detail in existingResult.answerDetails!) {
            if (detail is Map<String, dynamic>) {
              _answerDetails[detail['question_id']] = detail;
            }
          }
        }
      }
    } catch (e) {
      _hasAccess = false;
      _isOffline = true;
    }

    if (mounted) {
      setState(() => _checkingAccess = false);
      if (_hasAccess && !_hasLoadedQuestions && !_hasReachedMaxAttempts) {
        _loadExamQuestions();
        _hasLoadedQuestions = true;
      }
    }
  }

  Future<void> _loadExamFromProvider() async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    try {
      Exam? cachedExam;
      if (widget.courseId != null) {
        final cachedExams = examProvider.getExamsByCourse(widget.courseId!);
        try {
          cachedExam = cachedExams.firstWhere((e) => e.id == widget.examId);
        } catch (_) {}
      } else {
        cachedExam = examProvider.getExamById(widget.examId);
      }

      if (cachedExam != null) {
        setState(() {
          _exam = cachedExam!;
          _initializeExamSettings();
        });
        _checkExamAccess();
      } else {
        await examProvider.loadAvailableExams(
            courseId: widget.courseId);
        final loadedExam = examProvider.getExamById(widget.examId);
        if (loadedExam != null && mounted) {
          setState(() {
            _exam = loadedExam;
            _initializeExamSettings();
          });
          _checkExamAccess();
        } else {
          setState(() {
            _checkingAccess = false;
            _hasAccess = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _loadExamQuestions() async {
    final provider = Provider.of<ExamQuestionProvider>(context, listen: false);
    try {
      await provider.loadExamQuestions(_exam.id);
    } catch (e) {
      setState(() => _isOffline = true);
    }
  }

  void _startTimer() {
    if (_hasReachedMaxAttempts) return;

    _stopTimer();
    _remainingTime = _userTimeLimit ?? Duration(minutes: _exam.duration);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
            if (_remainingTime.inSeconds % 30 == 0) _saveProgressToCache();
          } else {
            timer.cancel();
            _handleTimerExpiration();
          }
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleTimerExpiration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_exam.autoSubmit) {
        _autoSubmitExam();
      } else {
        _showTimeUpWarning();
      }
    });
  }

  void _showTimeUpWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGlassDialog(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.telegramRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded,
                  color: AppColors.telegramRed, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Time\'s Up!',
                style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('The exam time has expired. Please submit your answers.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => GoRouter.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('OK',
                        style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGradientButton(
                    label: 'Submit',
                    onPressed: () {
                      GoRouter.of(context).pop();
                      _submitExam();
                    },
                    gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProgressToCache() async {
    if (_hasReachedMaxAttempts || _currentUserId == null) return;

    try {
      final provider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final progressData = {
        'exam_id': _exam.id,
        'current_index': _currentQuestionIndex,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'remaining_time': _remainingTime.inSeconds,
        'last_saved': DateTime.now().toIso8601String(),
      };

      await provider.deviceService.saveCacheItem(
        'exam_progress_${_exam.id}_$_currentUserId',
        progressData,
        ttl: const Duration(hours: 24),
        isUserSpecific: true,
      );
    } catch (e) {}
  }

  void _selectAnswer(String? answer) {
    if (!mounted || _hasReachedMaxAttempts) return;

    setState(() {
      final provider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final questions = provider.getQuestionsByExam(_exam.id);

      if (_currentQuestionIndex < questions.length) {
        final question = questions[_currentQuestionIndex];
        _answers[question.id] = answer;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgressToCache());
  }

  void _nextQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      final provider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final questions = provider.getQuestionsByExam(_exam.id);
      if (_currentQuestionIndex < questions.length - 1) _currentQuestionIndex++;
    });
  }

  void _previousQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      if (_currentQuestionIndex > 0) _currentQuestionIndex--;
    });
  }

  bool _validateAllQuestionsAnswered() {
    final provider = Provider.of<ExamQuestionProvider>(context, listen: false);
    final questions = provider.getQuestionsByExam(_exam.id);
    for (var question in questions) {
      if (_answers[question.id] == null || _answers[question.id]!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submitExam() async {
    if (_isSubmitting || _hasReachedMaxAttempts) return;

    if (!_validateAllQuestionsAnswered()) {
      showTopSnackBar(context, 'Please answer all questions before submitting',
          isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildGlassDialog(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppColors.telegramBlue, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Submit Exam',
                style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
                'Are you sure you want to submit the exam? You cannot change answers after submission.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => GoRouter.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Cancel',
                        style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGradientButton(
                    label: 'Submit',
                    onPressed: () => GoRouter.of(context).pop(true),
                    gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) await _doSubmitExam();
  }

  Future<void> _autoSubmitExam() async {
    if (_isSubmitting || _hasReachedMaxAttempts) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGlassDialog(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.telegramBlue))),
            const SizedBox(height: 16),
            Text('Submitting Exam...',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.getTextPrimary(context))),
          ],
        ),
      ),
    );

    await _doSubmitExam();
    if (mounted) GoRouter.of(context).pop();
  }

  Future<void> _doSubmitExam() async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    _stopTimer();

    try {
      final provider =
          Provider.of<ExamQuestionProvider>(context, listen: false);
      final questions = provider.getQuestionsByExam(_exam.id);

      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? ''
        };
      }).toList();

      final startResponse = await provider.apiService.startExam(_exam.id);

      int examResultId = 0;
      if (startResponse.data is Map<String, dynamic>) {
        final data = startResponse.data as Map<String, dynamic>;
        examResultId = data['exam_result_id'] ??
            (data['data'] is Map ? data['data']['exam_result_id'] : 0);
      }

      if (examResultId == 0) {
        throw ApiError(message: 'Failed to start exam session');
      }

      final submitResponse =
          await provider.apiService.submitExam(examResultId, answerList);

      if (submitResponse.success) {
        if (submitResponse.data is Map<String, dynamic>) {
          final resultData = submitResponse.data as Map<String, dynamic>;
          if (resultData.containsKey('details')) {
            final details = resultData['details'] as List;
            for (var detail in details) {
              if (detail is Map<String, dynamic>) {
                _answerDetails[detail['question_id']] = detail;
              }
            }
          }

          _submittedResult = ExamResult(
            id: examResultId,
            examId: _exam.id,
            userId: 0,
            score: (resultData['score'] as num?)?.toDouble() ?? 0,
            totalQuestions: resultData['total_questions'] ?? questions.length,
            correctAnswers: resultData['correct_answers'] ?? 0,
            timeTaken: resultData['time_taken'] ?? 0,
            startedAt: DateTime.now(),
            completedAt: DateTime.now(),
            status: 'completed',
            title: _exam.title,
            examType: _exam.examType,
            duration: _exam.duration,
            passingScore: _exam.passingScore,
            courseName: _exam.courseName,
            answerDetails: resultData['details'],
          );
        }

        if (_currentUserId != null) {
          await provider.deviceService.removeCacheItem(
              'exam_progress_${_exam.id}_$_currentUserId',
              isUserSpecific: true);
        }

        final examProvider = Provider.of<ExamProvider>(context, listen: false);
        await examProvider.loadMyExamResults(forceRefresh: true);

        if (mounted) {
          setState(() {
            _showResults = true;
            _hasReachedMaxAttempts = true;
          });
        }
      } else {
        throw ApiError.fromResponse(submitResponse);
      }
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorizedError();
      } else {
        if (mounted) {
          showTopSnackBar(context, e.userFriendlyMessage, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Failed to submit exam. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleUnauthorizedError() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.logout();
      if (mounted) GoRouter.of(context).go('/auth/login');
    });
  }

  @override
  void dispose() {
    _stopTimer();
    if (!_hasReachedMaxAttempts && _currentUserId != null) {
      Future.microtask(() async {
        try {
          await _saveProgressToCache();
        } catch (e) {}
      });
    }
    super.dispose();
  }

  String _getTimeLimitDescription() {
    return _exam.hasUserTimeLimit
        ? '${_exam.userTimeLimit} minutes per attempt'
        : '${_exam.duration} minutes exam-wide';
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

  Widget _buildGlassDialog(BuildContext context, {required Widget child}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.telegramBlue.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? LinearGradient(colors: gradient) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: onPressed != null
            ? Colors.transparent
            : AppColors.getSurface(context).withValues(alpha: 0.1),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: onPressed != null
                    ? Colors.white
                    : AppColors.getTextSecondary(context).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(BuildContext context) {
    final provider = Provider.of<ExamQuestionProvider>(context);
    final questions = provider.getQuestionsByExam(_exam.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Exam Results',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppThemes.spacingXL),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.3),
                        AppColors.telegramBlue.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('Your Score',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: Colors.white)),
                      const SizedBox(height: AppThemes.spacingM),
                      Text(
                          '${_submittedResult?.score.toStringAsFixed(1) ?? '0'}%',
                          style: AppTextStyles.displayLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1)),
                      const SizedBox(height: AppThemes.spacingS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingL,
                            vertical: AppThemes.spacingS),
                        decoration: BoxDecoration(
                          color: (_submittedResult?.passed ?? false)
                              ? AppColors.telegramGreen
                              : AppColors.telegramRed,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                        child: Text(
                            (_submittedResult?.passed ?? false)
                                ? 'PASSED'
                                : 'FAILED',
                            style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: AppThemes.spacingL),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildScoreStat(
                              'Correct',
                              '${_submittedResult?.correctAnswers ?? 0}',
                              AppColors.telegramGreen),
                          _buildScoreStat(
                              'Total',
                              '${_submittedResult?.totalQuestions ?? 0}',
                              Colors.white),
                          _buildScoreStat(
                              'Time',
                              _formatTime(_submittedResult?.timeTaken ?? 0),
                              Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppThemes.spacingXL),
            Text('Answer Review',
                style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const SizedBox(height: AppThemes.spacingL),
            ...List.generate(questions.length, (index) {
              final question = questions[index];
              final answerDetail = _answerDetails[question.id];
              final isCorrect = answerDetail?['is_correct'] ?? false;
              final userAnswer = answerDetail?['selected_option'] ??
                  _answers[question.id] ??
                  'Not answered';
              final correctAnswer =
                  answerDetail?['correct_option'] ?? question.correctOption;
              final explanation = answerDetail?['explanation'] ??
                  question.explanation ??
                  'No explanation provided';

              return Container(
                margin: const EdgeInsets.only(bottom: AppThemes.spacingL),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.all(AppThemes.spacingL),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.getCard(context).withValues(alpha: 0.4),
                            AppColors.getCard(context).withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isCorrect
                              ? AppColors.telegramGreen.withValues(alpha: 0.3)
                              : AppColors.telegramRed.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? AppColors.greenFaded
                                      : AppColors.redFaded,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCorrect
                                        ? AppColors.telegramGreen
                                        : AppColors.telegramRed,
                                  ),
                                ),
                                child: Icon(
                                    isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: isCorrect
                                        ? AppColors.telegramGreen
                                        : AppColors.telegramRed,
                                    size: 20),
                              ),
                              const SizedBox(width: AppThemes.spacingM),
                              Expanded(
                                  child: Text('Question ${index + 1}',
                                      style: AppTextStyles.titleSmall.copyWith(
                                          color:
                                              AppColors.getTextPrimary(context),
                                          fontWeight: FontWeight.w600))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppThemes.spacingM,
                                    vertical: 4),
                                decoration: BoxDecoration(
                                    color: AppColors.blueFaded,
                                    borderRadius: BorderRadius.circular(
                                        AppThemes.borderRadiusFull),
                                    border: Border.all(
                                        color: AppColors.telegramBlue
                                            .withValues(alpha: 0.3))),
                                child: Text(
                                    '${question.marks} mark${question.marks > 1 ? 's' : ''}',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.telegramBlue,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppThemes.spacingM),
                          Text(question.questionText,
                              style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w500,
                                  height: 1.5)),
                          const SizedBox(height: AppThemes.spacingL),
                          _buildAnswerRow(
                              'Your answer:',
                              _getOptionLetter(question, userAnswer),
                              isCorrect),
                          if (!isCorrect) ...[
                            const SizedBox(height: AppThemes.spacingM),
                            _buildAnswerRow('Correct answer:',
                                _getOptionLetter(question, correctAnswer), true,
                                showIcon: false),
                          ],
                          if (explanation.isNotEmpty) ...[
                            const SizedBox(height: AppThemes.spacingL),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  padding: const EdgeInsets.all(AppThemes.spacingM),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.getCard(context)
                                            .withValues(alpha: 0.2),
                                        AppColors.getCard(context)
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isCorrect
                                          ? AppColors.telegramGreen
                                              .withValues(alpha: 0.2)
                                          : AppColors.telegramBlue
                                              .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Explanation:',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(
                                                  color: isCorrect
                                                      ? AppColors.telegramGreen
                                                      : AppColors
                                                          .telegramBlue)),
                                      const SizedBox(height: 4),
                                      Text(explanation,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                  color: AppColors
                                                      .getTextSecondary(
                                                          context))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppThemes.spacingXXL),
            _buildGradientButton(
              label: 'Done',
              onPressed: () => GoRouter.of(context).pop(),
              gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.titleLarge
                .copyWith(color: color, fontWeight: FontWeight.w700)),
        Text(label,
            style: AppTextStyles.caption.copyWith(color: Colors.white70)),
      ],
    );
  }

  Widget _buildAnswerRow(String label, String answer, bool isCorrect,
      {bool showIcon = true}) {
    return Row(
      children: [
        if (showIcon)
          Container(
            padding: const EdgeInsets.all(2),
            child: Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isCorrect
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed),
          ),
        if (showIcon) const SizedBox(width: AppThemes.spacingS),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium,
              children: [
                TextSpan(
                    text: label,
                    style:
                        TextStyle(color: AppColors.getTextSecondary(context))),
                TextSpan(
                    text: ' $answer',
                    style: TextStyle(
                        color: isCorrect
                            ? AppColors.telegramGreen
                            : AppColors.telegramRed,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getOptionLetter(ExamQuestion question, String? answer) {
    if (answer == null || answer.isEmpty) return 'Not answered';
    final options = question.options;
    final optionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
    for (int i = 0; i < options.length; i++) {
      if (optionLetters[i] == answer.toUpperCase()) {
        return '$answer. ${options[i]}';
      }
    }
    return answer;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  String _getTimeString() {
    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes % 60;
    final seconds = _remainingTime.inSeconds % 60;
    return hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final questionProvider = Provider.of<ExamQuestionProvider>(context);

    if (_showResults && _submittedResult != null) {
      return _buildResultsScreen(context);
    }

    if (_hasReachedMaxAttempts && _submittedResult == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppThemes.spacingXL),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.telegramRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.redFaded,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.block_rounded,
                            size: 48, color: AppColors.telegramRed),
                      ),
                      const SizedBox(height: 24),
                      Text('Maximum Attempts Reached',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                          'You have used all ${_exam.maxAttempts} attempt(s) for this exam.',
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.getTextSecondary(context)),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      _buildGradientButton(
                        label: 'Go Back',
                        onPressed: () => GoRouter.of(context).pop(),
                        gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppThemes.spacingXL),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 48, color: AppColors.telegramBlue),
                      ),
                      const SizedBox(height: 24),
                      Text('Authentication Required',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text('Please login to take this exam',
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.getTextSecondary(context))),
                      const SizedBox(height: 24),
                      _buildGradientButton(
                        label: 'Login',
                        onPressed: () => GoRouter.of(context).go('/auth/login'),
                        gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_checkingAccess) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: const LoadingIndicator(
            message: 'Checking access...'),
      );
    }

    if (!_hasAccess && _exam.requiresPayment) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 48, color: AppColors.telegramBlue),
                      ),
                      const SizedBox(height: 24),
                      Text('Payment Required',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text(
                          'You need to purchase "${_exam.categoryName}" to access this exam.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.6)),
                      const SizedBox(height: 24),
                      _buildGradientButton(
                        label: 'Purchase Access',
                        onPressed: () {
                          GoRouter.of(context).pop();
                          GoRouter.of(context).push('/payment', extra: {
                            'category': _exam.categoryName,
                            'categoryId': _exam.categoryId,
                            'paymentType': 'first_time',
                            'context': 'exam',
                            'examId': _exam.id,
                            'examTitle': _exam.title,
                          });
                        },
                        gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_showInstructions) return _buildInstructionsScreen(context);

    if (questionProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: const LoadingIndicator(message: 'Loading exam questions...'),
      );
    }

    final questions = questionProvider.getQuestionsByExam(_exam.id);
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.quiz_outlined,
                            size: 48, color: AppColors.telegramBlue),
                      ),
                      const SizedBox(height: 24),
                      Text('No Questions Found',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text('Could not load exam questions. Please try again.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.getTextSecondary(context))),
                      const SizedBox(height: 24),
                      _buildGradientButton(
                        label: 'Retry',
                        onPressed: _loadExamQuestions,
                        gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_currentQuestionIndex >= questions.length) _currentQuestionIndex = 0;
    return _buildExamInterface(context, questions);
  }

  Widget _buildInstructionsScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(_exam.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.all(AppThemes.spacingL),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.15),
                        AppColors.telegramBlue.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_rounded,
                            color: AppColors.telegramBlue, size: 24),
                      ),
                      const SizedBox(width: AppThemes.spacingL),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Instructions',
                                style: AppTextStyles.titleSmall.copyWith(
                                    color: AppColors.telegramBlue,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 4),
                            Text('Please read carefully before starting',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color:
                                        AppColors.getTextSecondary(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppThemes.spacingXL),
            Text('Exam Details',
                style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const SizedBox(height: AppThemes.spacingL),
            _buildDetailItem(
                icon: Icons.description_rounded,
                label: 'Title:',
                value: _exam.title),
            _buildDetailItem(
                icon: Icons.category_rounded,
                label: 'Type:',
                value: _exam.examType.toUpperCase()),
            _buildDetailItem(
                icon: Icons.book_rounded,
                label: 'Course:',
                value: _exam.courseName),
            _buildDetailItem(
                icon: Icons.timer_rounded,
                label: 'Time Limit:',
                value: _getTimeLimitDescription()),
            _buildDetailItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Auto Submit:',
                value: _getAutoSubmitDescription()),
            _buildDetailItem(
                icon: Icons.visibility_rounded,
                label: 'Results:',
                value: _getResultsDisplayDescription()),
            _buildDetailItem(
                icon: Icons.score_rounded,
                label: 'Passing Score:',
                value: '${_exam.passingScore}%'),
            _buildDetailItem(
                icon: Icons.repeat_rounded,
                label: 'Max Attempts:',
                value: '${_exam.maxAttempts}'),
            _buildDetailItem(
                icon: Icons.history_rounded,
                label: 'Your Attempts:',
                value: '${_exam.attemptsTaken}/${_exam.maxAttempts}'),
            const SizedBox(height: AppThemes.spacingXXL),
            if (!_hasReachedMaxAttempts)
              SizedBox(
                width: double.infinity,
                child: _buildGradientButton(
                  label: 'Start Exam Now',
                  onPressed: () {
                    setState(() => _showInstructions = false);
                    _startTimer();
                  },
                  gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                ),
              ),
            const SizedBox(height: AppThemes.spacingL),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => GoRouter.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Cancel',
                    style: AppTextStyles.buttonMedium
                        .copyWith(color: AppColors.getTextSecondary(context))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
      {required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppColors.blueFaded, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: AppColors.telegramBlue)),
          const SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text(label,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context)))),
                Expanded(
                    flex: 3,
                    child: Text(value,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamInterface(
      BuildContext context, List<ExamQuestion> questions) {
    final currentQuestion = questions[_currentQuestionIndex];
    final totalQuestions = questions.length;
    final answeredQuestions = _answers.length;
    final timeColor = _remainingTime.inMinutes < 5
        ? AppColors.telegramRed
        : AppColors.telegramBlue;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(_exam.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context)),
          onPressed: _isSubmitting
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => _buildGlassDialog(
                      context,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.telegramYellow.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.exit_to_app_rounded,
                                color: AppColors.telegramYellow, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text('Leave Exam?',
                              style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 8),
                          Text(
                              'Your progress will be saved. You can resume later.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.getTextSecondary(context)),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      GoRouter.of(context).pop(false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  child: Text('Stay',
                                      style: AppTextStyles.labelLarge.copyWith(
                                          color: AppColors.getTextSecondary(
                                              context))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGradientButton(
                                  label: 'Leave',
                                  onPressed: () =>
                                      GoRouter.of(context).pop(true),
                                  gradient: const [
                                    Color(0xFFFF9500),
                                    Color(0xFFFF2D55)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirm == true && mounted) {
                    await _saveProgressToCache();
                    GoRouter.of(context).pop();
                  }
                },
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppThemes.spacingM),
            padding: const EdgeInsets.symmetric(
                horizontal: AppThemes.spacingM, vertical: AppThemes.spacingXS),
            decoration: BoxDecoration(
              color: timeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
              border: Border.all(color: timeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, size: 16, color: timeColor),
                const SizedBox(width: 4),
                Text(_getTimeString(),
                    style: AppTextStyles.labelMedium.copyWith(
                        color: timeColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                padding: const EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.getSurface(context).withValues(alpha: 0.4),
                      AppColors.getSurface(context).withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.getTextPrimary(context))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingM,
                              vertical: AppThemes.spacingXS),
                          decoration: BoxDecoration(
                              color: AppColors.blueFaded,
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                              border: Border.all(
                                  color:
                                      AppColors.telegramBlue.withValues(alpha: 0.3))),
                          child: Text(
                              '$answeredQuestions/$totalQuestions answered',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.telegramBlue,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppThemes.spacingS),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: answeredQuestions / totalQuestions,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2AABEE),
                                    Color(0xFF5856D6)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusFull),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.telegramBlue.withValues(alpha: 0.5),
                                    blurRadius: 4,
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
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL)),
              child: QuestionWidget(
                question: currentQuestion,
                selectedAnswer: _answers[currentQuestion.id],
                onAnswerSelected: _selectAnswer,
              ),
            ),
          ),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                padding: const EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.getCard(context).withValues(alpha: 0.4),
                      AppColors.getCard(context).withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        width: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildNavButton(
                            label: 'Previous',
                            icon: Icons.arrow_back_ios_rounded,
                            onPressed: _currentQuestionIndex > 0
                                ? _previousQuestion
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppThemes.spacingM),
                        Expanded(
                          child: _buildNavButton(
                            label: 'Next',
                            icon: Icons.arrow_forward_ios_rounded,
                            onPressed:
                                _currentQuestionIndex < totalQuestions - 1
                                    ? _nextQuestion
                                    : null,
                            isNext: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppThemes.spacingM),
                    SizedBox(
                      width: double.infinity,
                      child: _buildGradientButton(
                        label: 'Submit Exam',
                        onPressed: _isSubmitting ? null : _submitExam,
                        gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isNext = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: onPressed != null
                  ? LinearGradient(
                      colors: [
                        AppColors.getSurface(context).withValues(alpha: 0.2),
                        AppColors.getSurface(context).withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onPressed != null
                    ? AppColors.telegramBlue.withValues(alpha: 0.3)
                    : AppColors.getTextSecondary(context).withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isNext) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: onPressed != null
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: onPressed != null
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withValues(alpha: 0.3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 16,
                    color: onPressed != null
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withValues(alpha: 0.3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
