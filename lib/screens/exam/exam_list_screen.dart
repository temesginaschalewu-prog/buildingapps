import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../widgets/exam/exam_card.dart';
import '../../widgets/common/loading_indicator.dart';

class ExamListScreen extends StatelessWidget {
  final int? courseId;

  const ExamListScreen({super.key, this.courseId});

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final exams = courseId != null
        ? examProvider.getExamsByCourse(courseId!)
        : examProvider.availableExams;

    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      body: examProvider.isLoading
          ? const LoadingIndicator()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exams.length,
              itemBuilder: (context, index) {
                final exam = exams[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExamCard(
                    exam: exam,
                    onTap: () {
                      // Navigate to exam
                    },
                  ),
                );
              },
            ),
    );
  }
}
