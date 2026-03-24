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
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/exam/question_widget.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/constants.dart';

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

class _ExamScreenState extends State<ExamScreen>
    with BaseScreenMixin<ExamScreen>, TickerProviderStateMixin {
  late Exam _exam;
  bool _examReady = false;
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
  bool _hasLoadedOnce = false;

  ExamResult? _submittedResult;
  final Map<int, Map<String, dynamic>> _answerDetails = {};
  bool _showResults = false;
  bool _hasReachedMaxAttempts = false;
  int? _activeExamResultId;

  String? _currentUserId;

  late ExamProvider _examProvider;
  late ExamQuestionProvider _questionProvider;
  late SubscriptionProvider _subscriptionProvider;
  late AuthProvider _authProvider;
  late OfflineQueueManager _queueManager;
  bool _providersBound = false;
  bool _examInitializationStarted = false;

  @override
  String get screenTitle {
    if (_showResults) return AppStrings.examResults;
    return _examReady ? _exam.title : AppStrings.exam;
  }

  @override
  String? get screenSubtitle => null;

  // ✅ Only show loading if no cached data AND loading
  @override
  bool get isLoading =>
      _checkingAccess || (_questionProvider.isLoading && !_hasLoadedQuestions);

  @override
  bool get hasCachedData => _hasLoadedQuestions;

  @override
  dynamic get errorMessage => null;

  // ✅ Shimmer type for exam screen
  @override
  ShimmerType get shimmerType => ShimmerType.rectangle;

  @override
  int get shimmerItemCount => 5;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context)),
        onPressed: _isSubmitting
            ? null
            : () async {
                if (_examReady && !_showInstructions && !_showResults) {
                  final confirm = await AppDialog.confirm(
                    context: context,
                    title: AppStrings.leaveExam,
                    message: AppStrings.progressWillBeSaved,
                    confirmText: AppStrings.leave,
                    cancelText: AppStrings.stay,
                  );
                  if (confirm == true && isMounted) {
                    await _saveProgressToCache();
                    if (!isMounted) return;
                    context.pop();
                  }
                  return;
                }

                context.pop();
              },
      );

  @override
  List<Widget>? get appBarActions {
    if (!_examReady || _showInstructions || _showResults || _hasReachedMaxAttempts) {
      return null;
    }

    final timeColor = _remainingTime.inMinutes < 5
        ? AppColors.telegramRed
        : AppColors.telegramBlue;

    return [
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
            Icon(
              Icons.timer_rounded,
              size: ResponsiveValues.iconSizeXS(context),
              color: timeColor,
            ),
            SizedBox(width: ResponsiveValues.spacingXS(context)),
            Text(
              _getTimeString(),
              style: AppTextStyles.labelMedium(context).copyWith(
                color: timeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_providersBound) {
      _examProvider = context.read<ExamProvider>();
      _questionProvider = context.read<ExamQuestionProvider>();
      _subscriptionProvider = context.read<SubscriptionProvider>();
      _authProvider = context.read<AuthProvider>();
      _queueManager = context.read<OfflineQueueManager>();
      _questionProvider.setContext(context);
      _providersBound = true;

      unawaited(_getCurrentUserId());
    }

    if (!_examInitializationStarted) {
      _examInitializationStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initializeExam();
      });
    }

      if (widget.exam == null) {
        final routeExam = ModalRoute.of(context)?.settings.arguments;
        if (routeExam is Exam) {
          _exam = routeExam;
          _examReady = true;
          _initializeExamSettings();
          _checkExamAccess();
        }
    }

    // Mark as loaded if we have data
    if (_hasLoadedQuestions) {
      _hasLoadedOnce = true;
    }
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

  @override
  Future<void> onRefresh() async {
    // No pull-to-refresh needed for exam screen
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = _authProvider.currentUser?.id.toString();
  }

  void _initializeExam() {
    if (widget.exam != null) {
      _exam = widget.exam!;
      _examReady = true;
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
      final progressData = await _questionProvider.deviceService
          .getCacheItem<Map<String, dynamic>>(
        'exam_progress_${_exam.id}_$_currentUserId',
        isUserSpecific: true,
      );

      if (progressData != null && isMounted && !_hasReachedMaxAttempts) {
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
        });
      }
    } catch (e) {
      debugLog('ExamScreen', 'Error loading cached progress: $e');
    }
  }

  Future<void> _checkExamAccess() async {
    if (!_authProvider.isAuthenticated) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
      return;
    }

    try {
      if (_exam.requiresPayment) {
        if (!isOffline) {
          _hasAccess = await _subscriptionProvider
              .checkHasActiveSubscriptionForCategory(_exam.categoryId);
        } else {
          _hasAccess = _subscriptionProvider
              .hasActiveSubscriptionForCategory(_exam.categoryId);
        }
      } else {
        _hasAccess = true;
      }

      final ExamResult? existingResult =
          _examProvider.myExamResults.firstWhereOrNull(
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
    }

    if (isMounted) {
      setState(() => _checkingAccess = false);
    }
  }

  Future<void> _loadExamFromProvider() async {
    try {
      Exam? cachedExam;
      if (widget.courseId != null) {
        final cachedExams = _examProvider.getExamsByCourse(widget.courseId!);
        try {
          cachedExam = cachedExams.firstWhere((e) => e.id == widget.examId);
        } catch (_) {}
      } else {
        cachedExam = _examProvider.getExamById(widget.examId);
      }

      if (cachedExam != null) {
        setState(() {
          _exam = cachedExam!;
          _examReady = true;
          _initializeExamSettings();
        });
        await _checkExamAccess();
        if (!isMounted) return;
      } else {
        if (widget.courseId != null) {
          await _examProvider.loadExamsByCourse(widget.courseId!,
              forceRefresh: true);
        }

        if (!isMounted) return;

        final loadedExam = _examProvider.getExamById(widget.examId);
        if (loadedExam != null && isMounted) {
          setState(() {
            _exam = loadedExam;
            _examReady = true;
            _initializeExamSettings();
          });
          await _checkExamAccess();
          if (!isMounted) return;
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
      });
    }
  }

  Future<void> _loadExamQuestions() async {
    try {
      await _questionProvider.loadExamQuestions(_exam.id);
      final loadedQuestions = _questionProvider.getQuestionsByExam(_exam.id);
      if (loadedQuestions.isNotEmpty && isMounted) {
        setState(() {
          _hasLoadedQuestions = true;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      // Error handled by provider
    }
  }

  List<ExamQuestion> _mapStartedExamQuestions(List<dynamic> rawQuestions) {
    return rawQuestions.asMap().entries.map((entry) {
      final index = entry.key;
      final raw = entry.value;
      final question = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);

      return ExamQuestion(
        id: (question['id'] as num?)?.toInt() ?? index + 1,
        examId: _exam.id,
        questionId: (question['id'] as num?)?.toInt() ?? index + 1,
        displayOrder: index + 1,
        marks: (question['marks'] as num?)?.toInt() ?? 1,
        questionText: question['question_text']?.toString() ?? '',
        optionA: question['option_a']?.toString(),
        optionB: question['option_b']?.toString(),
        optionC: question['option_c']?.toString(),
        optionD: question['option_d']?.toString(),
        optionE: question['option_e']?.toString(),
        optionF: question['option_f']?.toString(),
        difficulty: (question['difficulty']?.toString() ?? 'medium').toLowerCase(),
        hasAnswer: false,
      );
    }).toList();
  }

  Future<void> _beginExam() async {
    if (_hasReachedMaxAttempts || !_examReady) return;

    if (isOffline) {
      await _loadExamQuestions();
      if (!isMounted) return;

      final offlineQuestions = _questionProvider.getQuestionsByExam(_exam.id);
      if (offlineQuestions.isEmpty) {
        SnackbarService().showOffline(context, action: AppStrings.exam);
        return;
      }

      setState(() {
        _showInstructions = false;
        _hasLoadedQuestions = true;
        _hasLoadedOnce = true;
      });
      _startTimer();
      return;
    }

    AppDialog.showLoading(context, message: AppStrings.loading);
    try {
      final startResponse = await _questionProvider.apiService.startExam(_exam.id);
      if (!isMounted) return;

      if (!startResponse.success || startResponse.data == null) {
        throw ApiError(message: startResponse.message);
      }

      final startData = startResponse.data!;
      _activeExamResultId = (startData['exam_result_id'] as num?)?.toInt();
      final rawQuestions = startData['questions'];
      final startedQuestions =
          rawQuestions is List ? _mapStartedExamQuestions(rawQuestions) : <ExamQuestion>[];

      if (startedQuestions.isEmpty) {
        throw ApiError(message: AppStrings.couldNotLoadExamQuestions);
      }

      await _questionProvider.seedExamQuestions(_exam.id, startedQuestions);
      if (!isMounted) return;

      setState(() {
        _showInstructions = false;
        _hasLoadedQuestions = true;
        _hasLoadedOnce = true;
        if (_currentQuestionIndex >= startedQuestions.length) {
          _currentQuestionIndex = 0;
        }
      });
      _startTimer();
    } on ApiError catch (e) {
      SnackbarService().showError(context, e.userFriendlyMessage);
    } catch (e) {
      SnackbarService().showError(context, AppStrings.couldNotLoadExamQuestions);
    } finally {
      if (isMounted) {
        AppDialog.hideLoading(context);
      }
    }
  }

  void _startTimer() {
    if (_hasReachedMaxAttempts) return;

    _stopTimer();
    _remainingTime = _userTimeLimit ?? Duration(minutes: _exam.duration);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isMounted) {
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
      final progressData = {
        'exam_id': _exam.id,
        'current_index': _currentQuestionIndex,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'remaining_time': _remainingTime.inSeconds,
        'last_saved': DateTime.now().toIso8601String(),
      };

      _questionProvider.deviceService.saveCacheItem(
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
    if (!isMounted || _hasReachedMaxAttempts) return;

    setState(() {
      final questions = _questionProvider.getQuestionsByExam(_exam.id);

      if (_currentQuestionIndex < questions.length) {
        final question = questions[_currentQuestionIndex];
        _answers[question.id] = answer;
        _questionProvider.saveAnswerOffline(
            _exam.id, question.id, answer ?? '');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgressToCache());
  }

  void _nextQuestion() {
    if (_hasReachedMaxAttempts) return;

    setState(() {
      final questions = _questionProvider.getQuestionsByExam(_exam.id);
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
    final questions = _questionProvider.getQuestionsByExam(_exam.id);
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

    if (isOffline) {
      final confirmed = await AppDialog.confirm(
        context: context,
        title: AppStrings.submitExamOffline,
        message: AppStrings.examWillBeSavedOffline,
        confirmText: AppStrings.saveOffline,
      );

      if (confirmed == true) {
        await _queueExamOffline();
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
  }

  Future<void> _queueExamOffline() async {
    setState(() => _isSubmitting = true);

    try {
      final questions = _questionProvider.getQuestionsByExam(_exam.id);

      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? '',
        };
      }).toList();

      _queueManager.addItem(
        type: AppConstants.queueActionSubmitExam,
        data: {
          'exam_id': _exam.id,
          'answers': answerList,
          'userId': _currentUserId,
        },
      );

      _questionProvider.deviceService.saveCacheItem(
        'offline_exam_submission_${_exam.id}_$_currentUserId',
        {
          'exam_id': _exam.id,
          'answers': answerList,
          'timestamp': DateTime.now().toIso8601String(),
        },
        ttl: const Duration(days: 7),
        isUserSpecific: true,
      );

      await _questionProvider.deviceService.removeCacheItem(
        'exam_progress_${_exam.id}_$_currentUserId',
        isUserSpecific: true,
      );

      SnackbarService().showQueued(context, action: AppStrings.examSubmission);

      if (isMounted) {
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
    if (!isMounted) return;
    AppDialog.hideLoading(context);
  }

  Future<void> _doSubmitExam() async {
    if (!isMounted) return;

    setState(() => _isSubmitting = true);
    _stopTimer();

    try {
      final questions = _questionProvider.getQuestionsByExam(_exam.id);

      final answerList = questions.map((question) {
        return {
          'question_id': question.id,
          'selected_option': _answers[question.id] ?? '',
        };
      }).toList();

      int examResultId = _activeExamResultId ?? 0;

      if (examResultId == 0) {
        final startResponse =
            await _questionProvider.apiService.startExam(_exam.id);
        if (!isMounted) return;

        if (startResponse.data is Map<String, dynamic>) {
          final data = startResponse.data as Map<String, dynamic>;
          examResultId = data['exam_result_id'] ??
              (data['data'] is Map ? data['data']['exam_result_id'] : 0);
        }
      }

      if (examResultId == 0) {
        throw ApiError(message: AppStrings.failedToStartExam);
      }

      final submitResponse = await _questionProvider.apiService
          .submitExam(examResultId, answerList);
      if (!isMounted) return;

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
          await _questionProvider.deviceService.removeCacheItem(
            'exam_progress_${_exam.id}_$_currentUserId',
            isUserSpecific: true,
          );
        }

        await _examProvider.loadMyExamResults(forceRefresh: true);
        if (!isMounted) return;

        if (isMounted) {
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
        if (isMounted) {
          SnackbarService().showError(context, e.userFriendlyMessage);
        }
      }
    } catch (e) {
      if (isMounted) {
        SnackbarService().showError(context, AppStrings.failedToSubmitExam);
      }
    } finally {
      if (isMounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleUnauthorizedError() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _authProvider.logout();
      if (!isMounted) return;
      if (isMounted) GoRouter.of(context).go('/auth/login');
    });
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

  String _getTimeString() {
    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes % 60;
    final seconds = _remainingTime.inSeconds % 60;
    return hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildExamPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ResponsiveValues.iconSizeS(context), color: color),
          SizedBox(width: ResponsiveValues.spacingS(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.labelLarge(context).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.labelSmall(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamSummaryCard({
    required String title,
    required String subtitle,
    required List<Widget> pills,
  }) {
    return Padding(
      padding: ResponsiveValues.cardPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headlineSmall(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingXS(context)),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.45,
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Wrap(
            spacing: ResponsiveValues.spacingS(context),
            runSpacing: ResponsiveValues.spacingS(context),
            children: pills,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final questions = _questionProvider.getQuestionsByExam(_exam.id);

    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: Column(
        children: [
            _buildExamSummaryCard(
              title: AppStrings.examResults,
              subtitle: (_submittedResult?.passed ?? false)
                  ? 'You passed this attempt and can review each answer below.'
                  : 'This attempt is complete. Review the answers and explanations below.',
              pills: [
                _buildExamPill(
                  icon: Icons.analytics_rounded,
                  label: 'Score',
                  value:
                      '${_submittedResult?.score.toStringAsFixed(1) ?? '0'}%',
                  color: (_submittedResult?.passed ?? false)
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed,
                ),
                _buildExamPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: AppStrings.correct,
                  value: '${_submittedResult?.correctAnswers ?? 0}',
                  color: AppColors.telegramGreen,
                ),
                _buildExamPill(
                  icon: Icons.timer_outlined,
                  label: AppStrings.time,
                  value: _formatTime(_submittedResult?.timeTaken ?? 0),
                  color: AppColors.telegramBlue,
                ),
                _buildExamPill(
                  icon: Icons.verified_rounded,
                  label: AppStrings.status,
                  value: (_submittedResult?.passed ?? false)
                      ? AppStrings.passed
                      : AppStrings.failed,
                  color: (_submittedResult?.passed ?? false)
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed,
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildSectionEyebrow(AppStrings.answerReview),
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
                                      : AppColors.telegramRed,
                                ),
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
                                style:
                                    AppTextStyles.titleSmall(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${question.marks} ${question.marks > 1 ? AppStrings.marks : AppStrings.mark}',
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.telegramBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          question.questionText,
                          style: AppTextStyles.bodyLarge(context).copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        _buildAnswerRow(
                          AppStrings.yourAnswer,
                          _getOptionLetter(question, userAnswer),
                          isCorrect,
                        ),
                        if (!isCorrect) ...[
                          SizedBox(height: ResponsiveValues.spacingM(context)),
                          _buildAnswerRow(
                            AppStrings.correctAnswer,
                            _getOptionLetter(question, correctAnswer),
                            true,
                            showIcon: false,
                          ),
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
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
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
                  style: TextStyle(color: AppColors.getTextSecondary(context)),
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

  Widget _buildSectionEyebrow(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.overline(context).copyWith(
        color: AppColors.getTextSecondary(context),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInstructionsScreen() {
    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionEyebrow('Exam'),
                SizedBox(height: ResponsiveValues.spacingXXS(context)),
                Text(
                  _exam.title,
                  style: AppTextStyles.headlineSmall(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingXS(context)),
                Text(
                  AppStrings.pleaseReadCarefully,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildSectionEyebrow(AppStrings.examDetails),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildDetailItem(
              icon: Icons.description_rounded,
              label: '${AppStrings.title}:',
              value: _exam.title,
            ),
            _buildDetailItem(
              icon: Icons.category_rounded,
              label: '${AppStrings.type}:',
              value: _exam.examType.toUpperCase(),
            ),
            _buildDetailItem(
              icon: Icons.book_rounded,
              label: '${AppStrings.course}:',
              value: _exam.courseName,
            ),
            _buildDetailItem(
              icon: Icons.timer_rounded,
              label: '${AppStrings.timeLimit}:',
              value: _getTimeLimitDescription(),
            ),
            _buildDetailItem(
              icon: Icons.auto_awesome_rounded,
              label: '${AppStrings.autoSubmit}:',
              value: _getAutoSubmitDescription(),
            ),
            _buildDetailItem(
              icon: Icons.visibility_rounded,
              label: '${AppStrings.results}:',
              value: _getResultsDisplayDescription(),
            ),
            _buildDetailItem(
              icon: Icons.score_rounded,
              label: '${AppStrings.passingScore}:',
              value: '${_exam.passingScore}%',
            ),
            _buildDetailItem(
              icon: Icons.repeat_rounded,
              label: '${AppStrings.maxAttempts}:',
              value: '${_exam.maxAttempts}',
            ),
            _buildDetailItem(
              icon: Icons.history_rounded,
              label: '${AppStrings.yourAttempts}:',
              value: '${_exam.attemptsTaken}/${_exam.maxAttempts}',
            ),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            if (!_hasReachedMaxAttempts)
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: isOffline
                      ? AppStrings.startOfflineMode
                      : AppStrings.startExamNow,
                  onPressed: _beginExam,
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
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingM(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: ResponsiveValues.iconSizeXS(context),
              color: AppColors.telegramBlue,
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    style: AppTextStyles.bodyMedium(context).copyWith(
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

  Widget _buildExamInterface() {
    final questions = _questionProvider.getQuestionsByExam(_exam.id);
    if (questions.isEmpty) {
      return Center(
        child: buildEmptyWidget(
          dataType: AppStrings.questions,
          customMessage: isOffline
              ? AppStrings.noCachedQuestionsAvailable
              : AppStrings.couldNotLoadExamQuestions,
          isOffline: isOffline,
        ),
      );
    }
    final currentQuestion = questions[_currentQuestionIndex];
    final totalQuestions = questions.length;

    return Column(
      children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveValues.spacingM(context),
              ResponsiveValues.spacingS(context),
              ResponsiveValues.spacingM(context),
              ResponsiveValues.spacingM(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of $totalQuestions',
                  style: AppTextStyles.labelMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(ResponsiveValues.radiusFull(context)),
                  child: Stack(
                    children: [
                      Container(
                        height: ResponsiveValues.progressBarHeight(context),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(context)
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: totalQuestions == 0
                            ? 0
                            : _answers.length / totalQuestions,
                        child: Container(
                          height: ResponsiveValues.progressBarHeight(context),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      label: isOffline
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
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (!_examReady) {
      return Center(
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
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showResults && _submittedResult != null) {
      return _buildResultsScreen();
    }

    if (_hasReachedMaxAttempts && _submittedResult == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                        color: AppColors.redFaded, shape: BoxShape.circle),
                    child: const Icon(Icons.block_rounded,
                        size: 48, color: AppColors.telegramRed),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Text(
                    AppStrings.maximumAttemptsReached,
                    style: AppTextStyles.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    '${AppStrings.youHaveUsedAll} ${_exam.maxAttempts} ${AppStrings.attemptsForThisExam}',
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
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
      );
    }

    if (!_authProvider.isAuthenticated) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                        color: AppColors.blueFaded, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_rounded,
                        size: 48, color: AppColors.telegramBlue),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Text(
                    AppStrings.authenticationRequired,
                    style: AppTextStyles.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    AppStrings.pleaseLoginToTakeExam,
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
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
      );
    }

    if (_checkingAccess) {
      return Center(
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
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasAccess && _exam.requiresPayment) {
      return Center(
        child: Padding(
          padding:
              EdgeInsets.all(ResponsiveValues.screenPadding(context) as double),
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                        color: AppColors.blueFaded, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_rounded,
                        size: 48, color: AppColors.telegramBlue),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Text(
                    AppStrings.paymentRequired,
                    style: AppTextStyles.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    '${AppStrings.youNeedToPurchase} "${_exam.categoryName}" ${AppStrings.toAccessThisExam}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  AppButton.primary(
                    label: AppStrings.purchaseAccess,
                    onPressed: () {
                      final hasExpiredSubscription = context
                          .read<SubscriptionProvider>()
                          .expiredSubscriptions
                          .any((sub) => sub.categoryId == _exam.categoryId);
                      GoRouter.of(context).pop();
                      GoRouter.of(context).push('/payment', extra: {
                        'category': _exam.categoryName,
                        'categoryId': _exam.categoryId,
                        'paymentType':
                            hasExpiredSubscription ? 'repayment' : 'first_time',
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
      );
    }

    if (_showInstructions) return _buildInstructionsScreen();

    if (_questionProvider.isLoading && !_hasLoadedOnce) {
      return Center(
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
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final questions = _questionProvider.getQuestionsByExam(_exam.id);
    if (questions.isEmpty) {
      return Center(
        child: buildEmptyWidget(
          dataType: AppStrings.questions,
          customMessage: isOffline
              ? AppStrings.noCachedQuestionsAvailable
              : AppStrings.couldNotLoadExamQuestions,
          isOffline: isOffline,
        ),
      );
    }

    if (_currentQuestionIndex >= questions.length) _currentQuestionIndex = 0;
    return _buildExamInterface();
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showRefreshIndicator: false,
    );
  }
}
