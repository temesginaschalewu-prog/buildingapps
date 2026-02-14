import 'dart:async';
import 'package:familyacademyclient/models/exam_question_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showInstructions = true;
  Duration _remainingTime = Duration.zero;
  Timer? _timer;
  Duration? _userTimeLimit;
  bool _hasAccess = false;
  bool _checkingAccess = true;
  bool _hasLoadedQuestions = false;

  // Results mode
  ExamResult? _submittedResult;
  Map<int, Map<String, dynamic>> _answerDetails = {};
  bool _showResults = false;
  bool _hasReachedMaxAttempts = false;

  // Offline-first flags
  bool _hasCachedProgress = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initializeExam();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.exam == null) {
      final routeExam = ModalRoute.of(context)?.settings.arguments;
      if (routeExam is Exam) {
        _exam = routeExam;
        _initializeExamSettings();
        _checkExamAccess();
      }
    }
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

    // Check if max attempts reached
    _hasReachedMaxAttempts = _exam.attemptsTaken >= _exam.maxAttempts &&
        _exam.status == 'max_attempts_reached';

    if (!_hasReachedMaxAttempts) {
      _loadCachedProgress();
    }
  }

  Future<void> _loadCachedProgress() async {
    try {
      final questionProvider = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      );
      final progressData = await questionProvider.deviceService
          .getCacheItem<Map<String, dynamic>>(
        'exam_progress_${_exam.id}',
        isUserSpecific: true,
      );

      if (progressData != null && mounted && !_hasReachedMaxAttempts) {
        setState(() {
          _currentQuestionIndex = progressData['current_index'] ?? 0;
          final answers = progressData['answers'] ?? {};
          if (answers is Map) {
            _answers = Map<int, String?>.from(answers.map(
              (k, v) => MapEntry(int.parse(k.toString()), v?.toString()),
            ));
          }
          final remainingSeconds =
              progressData['remaining_time'] ?? _remainingTime.inSeconds;
          _remainingTime = Duration(seconds: remainingSeconds);
          _hasCachedProgress = true;
        });

        debugLog('ExamScreen', '✅ Loaded cached progress');
      }
    } catch (e) {
      debugLog('ExamScreen', 'Cache load error: $e');
    }
  }

  Future<void> _checkExamAccess() async {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
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

      // Check if already have a result for this exam
      final examProvider = Provider.of<ExamProvider>(context, listen: false);
      final existingResult = examProvider.myExamResults.firstWhere(
        (result) => result.examId == _exam.id && result.status == 'completed',
        orElse: () => null as ExamResult,
      );

      if (existingResult != null && _exam.attemptsTaken >= _exam.maxAttempts) {
        _hasReachedMaxAttempts = true;
        _submittedResult = existingResult;
        _showResults = existingResult.showResultsImmediately;

        // Parse answer details if available
        if (existingResult.answerDetails != null) {
          for (var detail in existingResult.answerDetails!) {
            if (detail is Map<String, dynamic>) {
              _answerDetails[detail['question_id']] = detail;
            }
          }
        }
      }
    } catch (e) {
      debugLog('ExamScreen', 'Access check error: $e');
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
        } catch (_) {
          cachedExam = null;
        }
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
          courseId: widget.courseId,
          forceRefresh: false,
        );
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
      debugLog('ExamScreen', 'Load exam error: $e');
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
      await provider.loadExamQuestions(_exam.id, forceRefresh: false);
    } catch (e) {
      debugLog('ExamScreen', 'Load questions error: $e');
      setState(() {
        _isOffline = true;
      });
    }
  }

  void _startTimer() {
    if (_hasReachedMaxAttempts) return;

    _stopTimer();

    if (_userTimeLimit != null) {
      _remainingTime = _userTimeLimit!;
    } else {
      _remainingTime = Duration(minutes: _exam.duration);
    }

    debugLog('ExamScreen', 'Starting timer with $_remainingTime');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);

            if (_remainingTime.inSeconds % 30 == 0) {
              _saveProgressToCache();
            }
          } else {
            debugLog('ExamScreen', 'Timer expired');
            timer.cancel();
            _handleTimerExpiration();
          }
        });
      }
    });
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_off_rounded,
                  color: AppColors.telegramRed,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Time\'s Up!',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'The exam time has expired. Please submit your answers.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => GoRouter.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('OK', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        GoRouter.of(context).pop();
                        _submitExam();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Submit', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProgressToCache() async {
    if (_hasReachedMaxAttempts) return;

    try {
      final provider = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      );

      final progressData = {
        'exam_id': _exam.id,
        'current_index': _currentQuestionIndex,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'remaining_time': _remainingTime.inSeconds,
        'last_saved': DateTime.now().toIso8601String(),
      };

      await provider.deviceService.saveCacheItem(
        'exam_progress_${_exam.id}',
        progressData,
        ttl: Duration(hours: 24),
        isUserSpecific: true,
      );

      debugLog('ExamScreen', '✅ Progress saved to cache');
    } catch (e) {
      debugLog('ExamScreen', '❌ Error saving progress: $e');
    }
  }

  void _selectAnswer(String? answer) {
    if (!mounted || _hasReachedMaxAttempts) return;

    setState(() {
      final provider = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      );
      final questions = provider.getQuestionsByExam(_exam.id);

      if (_currentQuestionIndex < questions.length) {
        final question = questions[_currentQuestionIndex];
        _answers[question.id] = answer;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveProgressToCache();
    });
  }

  void _nextQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      final provider = Provider.of<ExamQuestionProvider>(
        context,
        listen: false,
      );
      final questions = provider.getQuestionsByExam(_exam.id);
      if (_currentQuestionIndex < questions.length - 1) {
        _currentQuestionIndex++;
      }
    });
  }

  void _previousQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      if (_currentQuestionIndex > 0) {
        _currentQuestionIndex--;
      }
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

    // Validate all questions are answered
    if (!_validateAllQuestionsAnswered()) {
      showSnackBar(
        context,
        'Please answer all questions before submitting',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: AppColors.telegramBlue,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Submit Exam',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Are you sure you want to submit the exam? You cannot change answers after submission.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => GoRouter.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => GoRouter.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Submit', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _doSubmitExam();
    }
  }

  Future<void> _autoSubmitExam() async {
    if (_isSubmitting || _hasReachedMaxAttempts) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Submitting Exam...',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await _doSubmitExam();

    if (mounted) {
      GoRouter.of(context).pop();
    }
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
          'selected_option': _answers[question.id] ?? '',
        };
      }).toList();

      debugLog('ExamScreen', 'Submitting exam: ${_exam.id}');

      final startResponse = await provider.apiService.startExam(_exam.id);

      int examResultId = 0;

      if (startResponse.data is Map<String, dynamic>) {
        final data = startResponse.data as Map<String, dynamic>;

        if (data.containsKey('exam_result_id')) {
          examResultId = data['exam_result_id'] as int;
        } else if (data.containsKey('data') && data['data'] is Map) {
          final nestedData = data['data'] as Map<String, dynamic>;
          if (nestedData.containsKey('exam_result_id')) {
            examResultId = nestedData['exam_result_id'] as int;
          }
        }
      }

      if (examResultId == 0) {
        debugLog('ExamScreen',
            '❌ Failed to get exam_result_id from response: ${startResponse.data}');
        throw ApiError(message: 'Failed to start exam session');
      }

      debugLog('ExamScreen', '✅ Got exam_result_id: $examResultId');

      final submitResponse = await provider.apiService.submitExam(
        examResultId,
        answerList,
      );

      if (submitResponse.success) {
        // Parse answer details from response if available
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

          // Create exam result object
          _submittedResult = ExamResult(
            id: examResultId,
            examId: _exam.id,
            userId: 0, // Will be populated from provider
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

        await provider.deviceService.removeCacheItem(
          'exam_progress_${_exam.id}',
          isUserSpecific: true,
        );

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
          showSnackBar(context, e.userFriendlyMessage, isError: true);
        }
      }
    } catch (e) {
      debugLog('ExamScreen', 'Submit error: $e');
      if (mounted) {
        showSnackBar(context, 'Failed to submit exam. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleUnauthorizedError() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.logout();
      if (mounted) {
        GoRouter.of(context).go('/auth/login');
      }
    });
  }

  @override
  void dispose() {
    _stopTimer();

    try {
      Future.microtask(() async {
        try {
          if (!_hasReachedMaxAttempts) {
            await _saveProgressToCache();
          }
        } catch (e) {
          debugLog('ExamScreen', 'Error saving progress in dispose: $e');
        }
      });
    } catch (e) {
      debugLog('ExamScreen', 'Error in dispose microtask: $e');
    }

    super.dispose();
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline && !_hasCachedProgress) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      padding: EdgeInsets.all(AppThemes.spacingM),
      decoration: BoxDecoration(
        color: _isOffline
            ? AppColors.telegramYellow.withOpacity(0.1)
            : AppColors.telegramBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: _isOffline
              ? AppColors.telegramYellow.withOpacity(0.3)
              : AppColors.telegramBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOffline
                ? Icons.signal_wifi_off_rounded
                : Icons.cloud_done_rounded,
            color:
                _isOffline ? AppColors.telegramYellow : AppColors.telegramBlue,
            size: 20,
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              _isOffline
                  ? 'Offline mode - answers saved locally'
                  : 'Progress saved - will sync when online',
              style: AppTextStyles.bodySmall.copyWith(
                color: _isOffline
                    ? AppColors.telegramYellow
                    : AppColors.telegramBlue,
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildResultsScreen(BuildContext context) {
    final provider = Provider.of<ExamQuestionProvider>(context);
    final questions = provider.getQuestionsByExam(_exam.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Exam Results',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppThemes.spacingXL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue,
                    AppColors.telegramBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusLarge),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Score',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingM),
                  Text(
                    '${_submittedResult?.score.toStringAsFixed(1) ?? '0'}%',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingS),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingL,
                      vertical: AppThemes.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: (_submittedResult?.passed ?? false)
                          ? AppColors.telegramGreen
                          : AppColors.telegramRed,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                    ),
                    child: Text(
                      (_submittedResult?.passed ?? false) ? 'PASSED' : 'FAILED',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreStat(
                        'Correct',
                        '${_submittedResult?.correctAnswers ?? 0}',
                        AppColors.telegramGreen,
                      ),
                      _buildScoreStat(
                        'Total',
                        '${_submittedResult?.totalQuestions ?? 0}',
                        Colors.white,
                      ),
                      _buildScoreStat(
                        'Time',
                        _formatTime(_submittedResult?.timeTaken ?? 0),
                        Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: AppThemes.spacingXL),

            // Answers review
            Text(
              'Answer Review',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppThemes.spacingL),

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
                margin: EdgeInsets.only(bottom: AppThemes.spacingL),
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge),
                  border: Border.all(
                    color: isCorrect
                        ? AppColors.telegramGreen
                        : AppColors.telegramRed,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppThemes.spacingS),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? AppColors.telegramGreen.withOpacity(0.1)
                                : AppColors.telegramRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect
                                ? AppColors.telegramGreen
                                : AppColors.telegramRed,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: AppThemes.spacingM),
                        Expanded(
                          child: Text(
                            'Question ${index + 1}',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingM,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.telegramBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull),
                          ),
                          child: Text(
                            '${question.marks} mark${question.marks > 1 ? 's' : ''}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppThemes.spacingM),
                    Text(
                      question.questionText,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppThemes.spacingL),

                    // User's answer
                    _buildAnswerRow(
                      'Your answer:',
                      _getOptionLetter(question, userAnswer),
                      isCorrect,
                    ),

                    // Correct answer (if wrong)
                    if (!isCorrect) ...[
                      SizedBox(height: AppThemes.spacingM),
                      _buildAnswerRow(
                        'Correct answer:',
                        _getOptionLetter(question, correctAnswer),
                        true,
                        showIcon: false,
                      ),
                    ],

                    // Explanation
                    if (explanation.isNotEmpty) ...[
                      SizedBox(height: AppThemes.spacingL),
                      Container(
                        padding: EdgeInsets.all(AppThemes.spacingM),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(context),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explanation:',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              explanation,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            SizedBox(height: AppThemes.spacingXXL),

            // Done button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => GoRouter.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(
                    double.infinity,
                    AppThemes.buttonHeightLarge,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusLarge),
                  ),
                ),
                child: Text(
                  'Done',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerRow(String label, String answer, bool isCorrect,
      {bool showIcon = true}) {
    return Row(
      children: [
        if (showIcon)
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isCorrect ? AppColors.telegramGreen : AppColors.telegramRed,
          ),
        if (showIcon) SizedBox(width: AppThemes.spacingS),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium,
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                TextSpan(
                  text: ' $answer',
                  style: TextStyle(
                    color: isCorrect
                        ? AppColors.telegramGreen
                        : AppColors.telegramRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final questionProvider = Provider.of<ExamQuestionProvider>(context);

    // Show results screen if exam is completed
    if (_showResults && _submittedResult != null) {
      return _buildResultsScreen(context);
    }

    // Show max attempts reached screen
    if (_hasReachedMaxAttempts && _submittedResult == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppThemes.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 80,
                  color: AppColors.telegramRed,
                ),
                SizedBox(height: AppThemes.spacingXL),
                Text(
                  'Maximum Attempts Reached',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppThemes.spacingL),
                Text(
                  'You have used all ${_exam.maxAttempts} attempt(s) for this exam.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppThemes.spacingXL),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      200,
                      AppThemes.buttonHeightLarge,
                    ),
                  ),
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 64,
                color: AppColors.getTextSecondary(context),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Authentication Required',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Please login to take this exam',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingXL),
              ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/auth/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemes.spacingXL,
                    vertical: AppThemes.spacingM,
                  ),
                ),
                child: Text('Login', style: AppTextStyles.buttonMedium),
              ),
            ],
          ),
        ),
      );
    }

    if (_checkingAccess) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: LoadingIndicator(
          message: 'Checking access...',
          type: LoadingType.circular,
          color: AppColors.telegramBlue,
        ),
      );
    }

    if (!_hasAccess && _exam.requiresPayment) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(
              ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(AppThemes.spacingXL),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 64,
                    color: AppColors.telegramBlue,
                  ),
                ),
                SizedBox(height: AppThemes.spacingXL),
                Text(
                  'Payment Required',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppThemes.spacingL),
                Text(
                  'You need to purchase "${_exam.categoryName}" to access this exam.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
                SizedBox(height: AppThemes.spacingXXL),
                ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      ScreenSize.responsiveValue(
                        context: context,
                        mobile: 200,
                        tablet: 240,
                        desktop: 280,
                      ),
                      AppThemes.buttonHeightLarge,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusLarge),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppThemes.spacingM,
                      horizontal: AppThemes.spacingXL,
                    ),
                    child: Text(
                      'Purchase Access',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (authProvider.currentUser?.accountStatus != 'active') {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: AppColors.telegramYellow,
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Account Inactive',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Your account is not active. Please contact support.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_showInstructions) {
      return _buildInstructionsScreen(context);
    }

    if (questionProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: LoadingIndicator(
          message: 'Loading exam questions...',
          color: AppColors.telegramBlue,
        ),
      );
    }

    final questions = questionProvider.getQuestionsByExam(_exam.id);
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            _exam.title,
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(
              ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: AppColors.getTextSecondary(context).withOpacity(0.3),
                ),
                SizedBox(height: AppThemes.spacingL),
                Text(
                  'No Questions Found',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: AppThemes.spacingM),
                Text(
                  'Could not load exam questions. Please try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                SizedBox(height: AppThemes.spacingXL),
                ElevatedButton(
                  onPressed: _loadExamQuestions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingXL,
                      vertical: AppThemes.spacingM,
                    ),
                  ),
                  child: Text('Retry', style: AppTextStyles.buttonMedium),
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

    return _buildExamInterface(context, questions);
  }

  Widget _buildInstructionsScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          _exam.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: EdgeInsets.all(AppThemes.spacingL),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusLarge),
                border: Border.all(
                  color: AppColors.telegramBlue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_rounded,
                      color: AppColors.telegramBlue,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructions',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please read carefully before starting',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppThemes.spacingXL),

            // Exam details section
            Text(
              'Exam Details',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppThemes.spacingL),

            _buildDetailItem(
              icon: Icons.description_rounded,
              label: 'Title:',
              value: _exam.title,
            ),
            _buildDetailItem(
              icon: Icons.category_rounded,
              label: 'Type:',
              value: _exam.examType.toUpperCase(),
            ),
            _buildDetailItem(
              icon: Icons.book_rounded,
              label: 'Course:',
              value: _exam.courseName,
            ),
            _buildDetailItem(
              icon: Icons.timer_rounded,
              label: 'Time Limit:',
              value: _getTimeLimitDescription(),
            ),
            _buildDetailItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Auto Submit:',
              value: _getAutoSubmitDescription(),
            ),
            _buildDetailItem(
              icon: Icons.visibility_rounded,
              label: 'Results:',
              value: _getResultsDisplayDescription(),
            ),
            _buildDetailItem(
              icon: Icons.score_rounded,
              label: 'Passing Score:',
              value: '${_exam.passingScore}%',
            ),
            _buildDetailItem(
              icon: Icons.repeat_rounded,
              label: 'Max Attempts:',
              value: '${_exam.maxAttempts}',
            ),
            _buildDetailItem(
              icon: Icons.history_rounded,
              label: 'Your Attempts:',
              value: '${_exam.attemptsTaken}/${_exam.maxAttempts}',
            ),

            SizedBox(height: AppThemes.spacingXXL),

            // Start button (disabled if max attempts reached)
            if (!_hasReachedMaxAttempts)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _showInstructions = false);
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(
                      double.infinity,
                      ScreenSize.responsiveValue(
                        context: context,
                        mobile: AppThemes.buttonHeightLarge,
                        tablet: AppThemes.buttonHeightLarge,
                        desktop: AppThemes.buttonHeightLarge,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusLarge),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 24),
                      SizedBox(width: AppThemes.spacingM),
                      Text(
                        'Start Exam Now',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: AppThemes.spacingL),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => GoRouter.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.getTextSecondary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  padding: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.telegramBlue,
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
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
        title: Text(
          _exam.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: AppThemes.elevationNone,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusLarge),
                      ),
                      backgroundColor: AppColors.getCard(context),
                      child: Padding(
                        padding: EdgeInsets.all(AppThemes.spacingXL),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppThemes.spacingL),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.telegramYellow.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.exit_to_app_rounded,
                                color: AppColors.telegramYellow,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: AppThemes.spacingL),
                            Text(
                              'Leave Exam?',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: AppThemes.spacingM),
                            Text(
                              'Your progress will be saved. You can resume later.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppThemes.spacingXL),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        GoRouter.of(context).pop(false),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppColors.getTextSecondary(context),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppThemes.borderRadiusMedium),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          vertical: AppThemes.spacingM),
                                    ),
                                    child: Text('Stay',
                                        style: AppTextStyles.buttonMedium),
                                  ),
                                ),
                                SizedBox(width: AppThemes.spacingM),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        GoRouter.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.telegramYellow,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppThemes.borderRadiusMedium),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          vertical: AppThemes.spacingM),
                                    ),
                                    child: Text('Leave',
                                        style: AppTextStyles.buttonMedium),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
          // Timer
          Container(
            margin: EdgeInsets.only(right: AppThemes.spacingM),
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingM,
              vertical: AppThemes.spacingXS,
            ),
            decoration: BoxDecoration(
              color: timeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
              border: Border.all(color: timeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 16,
                  color: timeColor,
                ),
                SizedBox(width: 4),
                Text(
                  _getTimeString(),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: timeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (_hasCachedProgress || _isOffline) _buildOfflineBanner(),

          // Progress bar
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
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
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingM,
                        vertical: AppThemes.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.telegramBlue.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull),
                      ),
                      child: Text(
                        '$answeredQuestions/$totalQuestions answered',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.telegramBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppThemes.spacingS),
                LinearProgressIndicator(
                  value: answeredQuestions / totalQuestions,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  minHeight: 4,
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusFull),
                ),
              ],
            ),
          ),

          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(
                ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
              ),
              child: QuestionWidget(
                question: currentQuestion,
                selectedAnswer: _answers[currentQuestion.id],
                onAnswerSelected: _selectAnswer,
              ),
            ),
          ),

          // Bottom navigation
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                // Previous/Next buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentQuestionIndex > 0
                            ? _previousQuestion
                            : null,
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 16,
                        ),
                        label: Text('Previous'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          side: BorderSide(
                            color: AppColors.getTextSecondary(context)
                                .withOpacity(0.5),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppThemes.spacingM,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentQuestionIndex < totalQuestions - 1
                            ? _nextQuestion
                            : null,
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        label: Text('Next'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          side: BorderSide(
                            color: AppColors.getTextSecondary(context)
                                .withOpacity(0.5),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppThemes.spacingM,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppThemes.spacingM),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitExam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.telegramBlue,
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        double.infinity,
                        ScreenSize.responsiveValue(
                          context: context,
                          mobile: AppThemes.buttonHeightLarge,
                          tablet: AppThemes.buttonHeightLarge,
                          desktop: AppThemes.buttonHeightLarge,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: AppThemes.spacingS),
                              Text(
                                'Submit Exam',
                                style: AppTextStyles.buttonMedium.copyWith(
                                  color: Colors.white,
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
}
