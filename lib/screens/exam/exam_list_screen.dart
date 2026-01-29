import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';

class ExamListScreen extends StatelessWidget {
  final int? courseId;

  const ExamListScreen({super.key, this.courseId});

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final exams = courseId != null
        ? examProvider.getExamsByCourse(courseId!)
        : examProvider.availableExams;

    debugLog('ExamListScreen', 'Building with courseId: $courseId');
    debugLog('ExamListScreen', 'Total exams: ${exams.length}');
    debugLog('ExamListScreen', 'Provider isLoading: ${examProvider.isLoading}');

    for (var exam in exams) {
      debugLog('ExamListScreen',
          'Exam: ${exam.title}, canTake: ${exam.canTakeExam}, requiresPayment: ${exam.requiresPayment}');
      debugLog('ExamListScreen',
          'Timing: ${exam.hasUserTimeLimit ? 'User: ${exam.userTimeLimit}min' : 'Exam: ${exam.duration}min'}');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (courseId != null) {
                await examProvider.loadExamsByCourse(courseId!);
              } else {
                await examProvider.loadAvailableExams();
              }
            },
          ),
        ],
      ),
      body: examProvider.isLoading
          ? const LoadingIndicator()
          : exams.isEmpty
              ? EmptyState(
                  icon: Icons.assignment,
                  title: 'No Exams Available',
                  message: courseId != null
                      ? 'There are no exams for this course yet.'
                      : 'No exams are available at the moment.',
                  actionText: 'Refresh',
                  onAction: () async {
                    if (courseId != null) {
                      await examProvider.loadExamsByCourse(courseId!);
                    } else {
                      await examProvider.loadAvailableExams();
                    }
                  },
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (courseId != null) {
                      await examProvider.loadExamsByCourse(courseId!);
                    } else {
                      await examProvider.loadAvailableExams();
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ExamCard(
                          exam: exam,
                          onTap: () {
                            if (exam.canTakeExam) {
                              // Navigate to exam screen
                              Navigator.pushNamed(
                                context,
                                '/exam/${exam.id}',
                                arguments: exam,
                              );
                            } else if (exam.requiresPayment) {
                              // Show payment dialog
                              _showPaymentDialog(context, exam);
                            } else {
                              // Show access denied message
                              showSnackBar(context, exam.message,
                                  isError: true);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showPaymentDialog(BuildContext context, Exam exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Required'),
        content: Text(
          'You need to purchase "${exam.categoryName}" to access this exam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to payment screen
              Navigator.pushNamed(
                context,
                '/payment',
                arguments: {
                  'category': exam.categoryName,
                  'categoryId': exam.categoryId,
                  'paymentType': 'first_time',
                },
              );
            },
            child: const Text('Purchase'),
          ),
        ],
      ),
    );
  }
}
