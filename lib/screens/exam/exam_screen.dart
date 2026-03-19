// lib/screens/exam/exam_screen.dart
// COMPLETE PRODUCTION-READY FILE - FIXED PENDING COUNT & QUEUE ACTIONS

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/exam_question_model.dart';
import '../../models/exam_model.dart';
import '../../models/exam_result_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/exam_question_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/exam/question_widget.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/constants.dart';

/// PRODUCTION-READY EXAM SCREEN
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
  bool _isSubmitting = false;
  bool _showInstructions = true;
  Duration _remainingTime = Duration.zero;
  Timer? _timer;
  Duration? _userTimeLimit;
  bool _hasAccess = false;
  bool _checkingAccess = true;
  bool _hasLoadedQuestions = false;
  bool _isOffline = false;
  int _pendingCount = 0;

  ExamResult? _submittedResult;
  final Map<int, Map<String, dynamic>> _answerDetails = {};
  bool _showResults = false;
  bool _hasReachedMaxAttempts = false;

  String? _currentUserId;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeExam();
    _setupConnectivityListener();
    _updatePendingCount();
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

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          final queueManager = context.read<OfflineQueueManager>();
          _pendingCount = queueManager.pendingCount;
        });
      }
    });
  }

  Future<void> _updatePendingCount() async {
    final queueManager = context.read<OfflineQueueManager>();
    if (mounted) {
      setState(() => _pendingCount = queueManager.pendingCount);
    }
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = context.read<AuthProvider>();
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

    if (!_hasReachedMaxAttempts) {
      _loadCachedProgress();
    }
  }

  Future<void> _loadCachedProgress() async {
    if (_currentUserId == null) return;

    try {
      final questionProvider = context.read<ExamQuestionProvider>();
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
        });
      }
    } catch (e) {
      debugLog('ExamScreen', 'Error loading cached progress: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    setState(() {
      _isOffline = !connectivityService.isOnline;
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    });
  }

  Future<void> _checkExamAccess() async {
    await _checkConnectivity();
    if (!mounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
      return;
    }

    try {
      if (_exam.requiresPayment) {
        if (!_isOffline) {
          _hasAccess = await subscriptionProvider
              .checkHasActiveSubscriptionForCategory(_exam.categoryId);
        } else {
          _hasAccess = subscriptionProvider
              .hasActiveSubscriptionForCategory(_exam.categoryId);
        }
      } else {
        _hasAccess = true;
      }

      final examProvider = context.read<ExamProvider>();
      final ExamResult? existingResult =
          examProvider.myExamResults.firstWhereOrNull(
        (result) => result.examId == _exam.id && result.status == 'completed',
      );

      if (_exam.attemptsTaken >= _exam.maxAttempts) {
        _hasReachedMaxAttempts = true;
        _submittedResult = existingResult;
        if (existingResult != null && existingResult.answerDetails != null) {
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
        await _loadExamQuestions();
        if (!mounted) return;
        _hasLoadedQuestions = true;
      }
    }
  }

  Future<void> _loadExamFromProvider() async {
    final examProvider = context.read<ExamProvider>();

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
        await _checkExamAccess();
        if (!mounted) return;
      } else {
        if (widget.courseId != null) {
          await examProvider.loadExamsByCourse(widget.courseId!,
              forceRefresh: true);
        }

        if (!mounted) return;

        final loadedExam = examProvider.getExamById(widget.examId);
        if (loadedExam != null && mounted) {
          setState(() {
            _exam = loadedExam;
            _initializeExamSettings();
          });
          await _checkExamAccess();
          if (!mounted) return;
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
    final provider = context.read<ExamQuestionProvider>();
    try {
      await provider.loadExamQuestions(_exam.id);
      if (!mounted) return;
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
            if (_remainingTime.inSeconds % 30 == 0) {
              _saveProgressToCache();
            }
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
    AppDialog.warning(
      context: context,
      title: AppStrings.timeUp,
      message: AppStrings.examTimeExpired,
      confirmText: AppStrings.submit,
    ).then((confirmed) {
      if (confirmed == true) _submitExam();
    });
  }

  Future<void> _saveProgressToCache() async {
    if (_hasReachedMaxAttempts || _currentUserId == null) return;

    try {
      final provider = context.read<ExamQuestionProvider>();
      final progressData = {
        'exam_id': _exam.id,
        'current_index': _currentQuestionIndex,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'remaining_time': _remainingTime.inSeconds,
        'last_saved': DateTime.now().toIso8601String(),
      };

      provider.deviceService.saveCacheItem(
        'exam_progress_${_exam.id}_$_currentUserId',
        progressData,
        ttl: const Duration(hours: 24),
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('ExamScreen', 'Error saving progress: $e');
    }
  }

  void _selectAnswer(String? answer) {
    if (!mounted || _hasReachedMaxAttempts) return;

    setState(() {
      final provider = context.read<ExamQuestionProvider>();
      final questions = provider.getQuestionsByExam(_exam.id);

      if (_currentQuestionIndex < questions.length) {
        final question = questions[_currentQuestionIndex];
        _answers[question.id] = answer;
        provider.saveAnswerOffline(_exam.id, question.id, answer ?? '');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgressToCache());
  }

  void _nextQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      final provider = context.read<ExamQuestionProvider>();
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
    final provider = context.read<ExamQuestionProvider>();
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
      SnackbarService().showError(context, AppStrings.pleaseAnswerAllQuestions);
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      final confirmed = await AppDialog.confirm(
        context: context,
        title: AppStrings.submitExamOffline,
        message: AppStrings.examWillBeSavedOffline,
        confirmText: AppStrings.saveOffline,
      );

      if (confirmed == true) {
        await _queueExamOffline();
        if (!mounted) return;
      }
      return;
    }

    final confirmed = await AppDialog.confirm(
      context: context,
      title: AppStrings.submitExam,
      message: AppStrings.cannotChangeAnswersAfterSubmission,
      confirmText: AppStrings.submit,
    );

    if (confirmed == true) await _doSubmitExam();
    if (!mounted) return;
  }

  Future<void> _queueExamOffline() async {
    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ExamQuestionProvider>();
      final questions = provider.getQuestionsByExam(_exam.id);

      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? ''
        };
      }).toList();

      final queueManager = context.read<OfflineQueueManager>();
      queueManager.addItem(
        type: AppConstants.queueActionSubmitExam, // ✅ FIXED: Using constant
        data: {
          'exam_id': _exam.id,
          'answers': answerList,
          'userId': _currentUserId,
        },
      );

      provider.deviceService.saveCacheItem(
        'offline_exam_submission_${_exam.id}_$_currentUserId',
        {
          'exam_id': _exam.id,
          'answers': answerList,
          'timestamp': DateTime.now().toIso8601String(),
        },
        ttl: const Duration(days: 7),
        isUserSpecific: true,
      );

      await provider.deviceService.removeCacheItem(
        'exam_progress_${_exam.id}_$_currentUserId',
        isUserSpecific: true,
      );

      SnackbarService().showQueued(context, action: AppStrings.examSubmission);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      SnackbarService().showError(context, AppStrings.failedToSaveExamOffline);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _autoSubmitExam() async {
    if (_isSubmitting || _hasReachedMaxAttempts) return;

    AppDialog.showLoading(context, message: AppStrings.submittingExam);
    await _doSubmitExam();
    if (!mounted) return;
    AppDialog.hideLoading(context);
  }

  Future<void> _doSubmitExam() async {
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    _stopTimer();

    try {
      final provider = context.read<ExamQuestionProvider>();
      final questions = provider.getQuestionsByExam(_exam.id);

      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? ''
        };
      }).toList();

      final startResponse = await provider.apiService.startExam(_exam.id);
      if (!mounted) return;

      int examResultId = 0;
      if (startResponse.data is Map<String, dynamic>) {
        final data = startResponse.data as Map<String, dynamic>;
        examResultId = data['exam_result_id'] ??
            (data['data'] is Map ? data['data']['exam_result_id'] : 0);
      }

      if (examResultId == 0) {
        throw ApiError(message: AppStrings.failedToStartExam);
      }

      final submitResponse =
          await provider.apiService.submitExam(examResultId, answerList);
      if (!mounted) return;

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
            isUserSpecific: true,
          );
        }

        final examProvider = context.read<ExamProvider>();
        await examProvider.loadMyExamResults(forceRefresh: true);
        if (!mounted) return;

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
          SnackbarService().showError(context, e.userFriendlyMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarService().showError(context, AppStrings.failedToSubmitExam);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleUnauthorizedError() {
    final authProvider = context.read<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.logout();
      if (!mounted) return;
      if (mounted) GoRouter.of(context).go('/auth/login');
    });
  }

  @override
  void dispose() {
    _stopTimer();
    _connectivitySubscription?.cancel();
    if (!_hasReachedMaxAttempts && _currentUserId != null) {
      Future.microtask(() async {
        try {
          await _saveProgressToCache();
          if (!mounted) return;
        } catch (e) {}
      });
    }
    super.dispose();
  }

  String _getTimeLimitDescription() {
    return _exam.hasUserTimeLimit
        ? '${_exam.userTimeLimit} ${AppStrings.minutesPerAttempt}'
        : '${_exam.duration} ${AppStrings.minutesExamWide}';
  }

  String _getAutoSubmitDescription() {
    return _exam.autoSubmit
        ? AppStrings.autoSubmitWhenTimeExpires
        : AppStrings.manualSubmissionRequired;
  }

  String _getResultsDisplayDescription() {
    return _exam.showResultsImmediately
        ? AppStrings.resultsShownImmediately
        : AppStrings.resultsAvailableAfterExam;
  }

  Widget _buildResultsScreen(BuildContext context) {
    final provider = context.read<ExamQuestionProvider>();
    final questions = provider.getQuestionsByExam(_exam.id);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(AppStrings.examResults,
            style: AppTextStyles.appBarTitle(context)),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveValues.screenPadding(context),
        child: Column(
          children: [
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  children: [
                    Text(AppStrings.yourScore,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(color: Colors.white)),
                    SizedBox(height: ResponsiveValues.spacingM(context)),
                    Text(
                      '${_submittedResult?.score.toStringAsFixed(1) ?? '0'}%',
                      style: AppTextStyles.displayLarge(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1),
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingL(context),
                        vertical: ResponsiveValues.spacingS(context),
                      ),
                      decoration: BoxDecoration(
                        color: (_submittedResult?.passed ?? false)
                            ? AppColors.telegramGreen
                            : AppColors.telegramRed,
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context)),
                      ),
                      child: Text(
                        (_submittedResult?.passed ?? false)
                            ? AppStrings.passed
                            : AppStrings.failed,
                        style: AppTextStyles.labelLarge(context).copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildScoreStat(
                            AppStrings.correct,
                            '${_submittedResult?.correctAnswers ?? 0}',
                            AppColors.telegramGreen),
                        _buildScoreStat(
                            AppStrings.total,
                            '${_submittedResult?.totalQuestions ?? 0}',
                            Colors.white),
                        _buildScoreStat(
                            AppStrings.time,
                            _formatTime(_submittedResult?.timeTaken ?? 0),
                            Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Text(
              AppStrings.answerReview,
              style: AppTextStyles.titleLarge(context)
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            ...List.generate(questions.length, (index) {
              final question = questions[index];
              final answerDetail = _answerDetails[question.id];
              final isCorrect = answerDetail?['is_correct'] ?? false;
              final userAnswer = answerDetail?['selected_option'] ??
                  _answers[question.id] ??
                  AppStrings.notAnswered;
              final correctAnswer =
                  answerDetail?['correct_option'] ?? question.correctOption;
              final explanation = answerDetail?['explanation'] ??
                  question.explanation ??
                  AppStrings.noExplanation;

              return Container(
                margin:
                    EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
                child: AppCard.exam(
                  statusColor: isCorrect
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed,
                  child: Padding(
                    padding: ResponsiveValues.cardPadding(context),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  ResponsiveValues.spacingS(context)),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? AppColors.greenFaded
                                    : AppColors.redFaded,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isCorrect
                                        ? AppColors.telegramGreen
                                        : AppColors.telegramRed),
                              ),
                              child: Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect
                                    ? AppColors.telegramGreen
                                    : AppColors.telegramRed,
                                size: ResponsiveValues.iconSizeS(context),
                              ),
                            ),
                            SizedBox(width: ResponsiveValues.spacingM(context)),
                            Expanded(
                              child: Text(
                                '${AppStrings.question} ${index + 1}',
                                style: AppTextStyles.titleSmall(context)
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveValues.spacingM(context),
                                vertical: ResponsiveValues.spacingXXS(context),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blueFaded,
                                borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusFull(context)),
                                border: Border.all(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${question.marks} ${question.marks > 1 ? AppStrings.marks : AppStrings.mark}',
                                style: AppTextStyles.caption(context).copyWith(
                                    color: AppColors.telegramBlue,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          question.questionText,
                          style: AppTextStyles.bodyLarge(context).copyWith(
                              fontWeight: FontWeight.w500, height: 1.5),
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        _buildAnswerRow(AppStrings.yourAnswer,
                            _getOptionLetter(question, userAnswer), isCorrect),
                        if (!isCorrect) ...[
                          SizedBox(height: ResponsiveValues.spacingM(context)),
                          _buildAnswerRow(AppStrings.correctAnswer,
                              _getOptionLetter(question, correctAnswer), true,
                              showIcon: false),
                        ],
                        if (explanation.isNotEmpty) ...[
                          SizedBox(height: ResponsiveValues.spacingL(context)),
                          AppCard.glass(
                            child: Padding(
                              padding: ResponsiveValues.cardPadding(context),
                              child: Column(
                                children: [
                                  Text(
                                    AppStrings.explanation,
                                    style: AppTextStyles.labelMedium(context)
                                        .copyWith(
                                      color: isCorrect
                                          ? AppColors.telegramGreen
                                          : AppColors.telegramBlue,
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          ResponsiveValues.spacingXS(context)),
                                  Text(
                                    explanation,
                                    style: AppTextStyles.bodyMedium(context)
                                        .copyWith(
                                            color: AppColors.getTextSecondary(
                                                context)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            AppButton.primary(
              label: AppStrings.done,
              onPressed: () => GoRouter.of(context).pop(),
              expanded: true,
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
          style: AppTextStyles.titleLarge(context)
              .copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: AppTextStyles.caption(context).copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildAnswerRow(String label, String answer, bool isCorrect,
      {bool showIcon = true}) {
    return Row(
      children: [
        if (showIcon)
          Container(
            padding: EdgeInsets.all(ResponsiveValues.spacingXXS(context)),
            child: Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              size: ResponsiveValues.iconSizeXS(context),
              color:
                  isCorrect ? AppColors.telegramGreen : AppColors.telegramRed,
            ),
          ),
        if (showIcon) SizedBox(width: ResponsiveValues.spacingS(context)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium(context),
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
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getOptionLetter(ExamQuestion question, String? answer) {
    if (answer == null || answer.isEmpty) return AppStrings.notAnswered;
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

  Widget _buildInstructionsScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(_exam.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.appBarTitle(context)),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveValues.screenPadding(context),
        child: Column(
          children: [
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingM(context)),
                      decoration: BoxDecoration(
                          color: AppColors.blueFaded, shape: BoxShape.circle),
                      child: const Icon(Icons.info_rounded,
                          color: AppColors.telegramBlue, size: 24),
                    ),
                    SizedBox(width: ResponsiveValues.spacingL(context)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            AppStrings.instructions,
                            style: AppTextStyles.titleSmall(context).copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: ResponsiveValues.spacingXS(context)),
                          Text(
                            AppStrings.pleaseReadCarefully,
                            style: AppTextStyles.bodySmall(context).copyWith(
                                color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Text(
              AppStrings.examDetails,
              style: AppTextStyles.titleLarge(context)
                  .copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildDetailItem(
                icon: Icons.description_rounded,
                label: '${AppStrings.title}:',
                value: _exam.title),
            _buildDetailItem(
                icon: Icons.category_rounded,
                label: '${AppStrings.type}:',
                value: _exam.examType.toUpperCase()),
            _buildDetailItem(
                icon: Icons.book_rounded,
                label: '${AppStrings.course}:',
                value: _exam.courseName),
            _buildDetailItem(
                icon: Icons.timer_rounded,
                label: '${AppStrings.timeLimit}:',
                value: _getTimeLimitDescription()),
            _buildDetailItem(
                icon: Icons.auto_awesome_rounded,
                label: '${AppStrings.autoSubmit}:',
                value: _getAutoSubmitDescription()),
            _buildDetailItem(
                icon: Icons.visibility_rounded,
                label: '${AppStrings.results}:',
                value: _getResultsDisplayDescription()),
            _buildDetailItem(
                icon: Icons.score_rounded,
                label: '${AppStrings.passingScore}:',
                value: '${_exam.passingScore}%'),
            _buildDetailItem(
                icon: Icons.repeat_rounded,
                label: '${AppStrings.maxAttempts}:',
                value: '${_exam.maxAttempts}'),
            _buildDetailItem(
                icon: Icons.history_rounded,
                label: '${AppStrings.yourAttempts}:',
                value: '${_exam.attemptsTaken}/${_exam.maxAttempts}'),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            if (!_hasReachedMaxAttempts)
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: _isOffline
                      ? AppStrings.startOfflineMode
                      : AppStrings.startExamNow,
                  onPressed: () {
                    setState(() => _showInstructions = false);
                    _startTimer();
                  },
                  expanded: true,
                ),
              ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.outline(
                label: AppStrings.cancel,
                onPressed: () => GoRouter.of(context).pop(),
                expanded: true,
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
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingM(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
                color: AppColors.blueFaded, shape: BoxShape.circle),
            child: Icon(icon,
                size: ResponsiveValues.iconSizeXS(context),
                color: AppColors.telegramBlue),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text(label,
                        style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context)))),
                Expanded(
                    flex: 3,
                    child: Text(value,
                        style: AppTextStyles.bodyMedium(context)
                            .copyWith(fontWeight: FontWeight.w600))),
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
            style: AppTextStyles.appBarTitle(context)),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
          icon: Icons.arrow_back_rounded,
          onPressed: _isSubmitting
              ? null
              : () async {
                  final confirm = await AppDialog.confirm(
                    context: context,
                    title: AppStrings.leaveExam,
                    message: AppStrings.progressWillBeSaved,
                    confirmText: AppStrings.leave,
                    cancelText: AppStrings.stay,
                  );
                  if (confirm == true && mounted) {
                    await _saveProgressToCache();
                    if (!mounted) return;
                    GoRouter.of(context).pop();
                  }
                },
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: ResponsiveValues.spacingM(context)),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingM(context),
              vertical: ResponsiveValues.spacingXS(context),
            ),
            decoration: BoxDecoration(
              color: timeColor.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusFull(context)),
              border: Border.all(color: timeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded,
                    size: ResponsiveValues.iconSizeXS(context),
                    color: timeColor),
                SizedBox(width: ResponsiveValues.spacingXS(context)),
                Text(
                  _getTimeString(),
                  style: AppTextStyles.labelMedium(context)
                      .copyWith(color: timeColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppStrings.question} ${_currentQuestionIndex + 1} ${AppStrings.of} $totalQuestions',
                        style: AppTextStyles.bodyMedium(context),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blueFaded,
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                          border: Border.all(
                              color: AppColors.telegramBlue
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$answeredQuestions/$totalQuestions ${AppStrings.answered}',
                          style: AppTextStyles.labelSmall(context).copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingS(context)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context)),
                    child: Stack(
                      children: [
                        Container(
                          height: ResponsiveValues.progressBarHeight(context),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(context)
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context)),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: answeredQuestions / totalQuestions,
                          child: Container(
                            height: ResponsiveValues.progressBarHeight(context),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppColors.blueGradient),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.5),
                                    blurRadius:
                                        ResponsiveValues.spacingXS(context))
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
          Expanded(
            child: SingleChildScrollView(
              padding: ResponsiveValues.screenPadding(context),
              child: QuestionWidget(
                question: currentQuestion,
                selectedAnswer: _answers[currentQuestion.id],
                onAnswerSelected: _selectAnswer,
              ),
            ),
          ),
          AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.glass(
                          label: AppStrings.previous,
                          icon: Icons.arrow_back_ios_rounded,
                          onPressed: _currentQuestionIndex > 0
                              ? _previousQuestion
                              : null,
                          expanded: true,
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: AppButton.glass(
                          label: AppStrings.next,
                          icon: Icons.arrow_forward_ios_rounded,
                          onPressed: _currentQuestionIndex < totalQuestions - 1
                              ? _nextQuestion
                              : null,
                          expanded: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      label: _isOffline
                          ? AppStrings.saveOffline
                          : AppStrings.submitExam,
                      onPressed: _isSubmitting ? null : _submitExam,
                      isLoading: _isSubmitting,
                      expanded: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final questionProvider = context.read<ExamQuestionProvider>();

    if (_showResults && _submittedResult != null) {
      return _buildResultsScreen(context);
    }

    if (_hasReachedMaxAttempts && _submittedResult == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
            child: AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingL(context)),
                      decoration: BoxDecoration(
                          color: AppColors.redFaded, shape: BoxShape.circle),
                      child: const Icon(Icons.block_rounded,
                          size: 48, color: AppColors.telegramRed),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    Text(
                      AppStrings.maximumAttemptsReached,
                      style: AppTextStyles.headlineMedium(context).copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveValues.spacingM(context)),
                    Text(
                      '${AppStrings.youHaveUsedAll} ${_exam.maxAttempts} ${AppStrings.attemptsForThisExam}',
                      style: AppTextStyles.bodyLarge(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    AppButton.primary(
                      label: AppStrings.goBack,
                      onPressed: () => GoRouter.of(context).pop(),
                      expanded: true,
                    ),
                  ],
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
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
            child: AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingL(context)),
                      decoration: BoxDecoration(
                          color: AppColors.blueFaded, shape: BoxShape.circle),
                      child: const Icon(Icons.lock_rounded,
                          size: 48, color: AppColors.telegramBlue),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    Text(
                      AppStrings.authenticationRequired,
                      style: AppTextStyles.headlineMedium(context).copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    SizedBox(height: ResponsiveValues.spacingM(context)),
                    Text(
                      AppStrings.pleaseLoginToTakeExam,
                      style: AppTextStyles.bodyLarge(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    AppButton.primary(
                      label: AppStrings.login,
                      onPressed: () => GoRouter.of(context).go('/auth/login'),
                      expanded: true,
                    ),
                  ],
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
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppShimmer(type: ShimmerType.circle),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.loading,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_hasAccess && _exam.requiresPayment) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(
                ResponsiveValues.screenPadding(context) as double),
            child: AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingL(context)),
                      decoration: BoxDecoration(
                          color: AppColors.blueFaded, shape: BoxShape.circle),
                      child: const Icon(Icons.lock_rounded,
                          size: 48, color: AppColors.telegramBlue),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    Text(
                      AppStrings.paymentRequired,
                      style: AppTextStyles.headlineMedium(context).copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: -0.5),
                    ),
                    SizedBox(height: ResponsiveValues.spacingM(context)),
                    Text(
                      '${AppStrings.youNeedToPurchase} "${_exam.categoryName}" ${AppStrings.toAccessThisExam}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.6),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    AppButton.primary(
                      label: AppStrings.purchaseAccess,
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
                      expanded: true,
                    ),
                  ],
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
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppShimmer(type: ShimmerType.circle),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.loading,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final questions = questionProvider.getQuestionsByExam(_exam.id);
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(_exam.title,
              style: AppTextStyles.appBarTitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: AppEmptyState.noData(
            dataType: AppStrings.questions,
            customMessage: _isOffline
                ? AppStrings.noCachedQuestionsAvailable
                : AppStrings.couldNotLoadExamQuestions,
            onRefresh: _loadExamQuestions,
            isOffline: _isOffline,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    if (_currentQuestionIndex >= questions.length) _currentQuestionIndex = 0;
    return _buildExamInterface(context, questions);
  }
}
