import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/exam_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/progress/streak_widget.dart';
import '../../widgets/progress/progress_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;

    try {
      final streakProvider =
          Provider.of<StreakProvider>(context, listen: false);
      final examProvider = Provider.of<ExamProvider>(context, listen: false);

      await Future.wait([
        streakProvider.loadStreak(),
        examProvider.loadMyExamResults(),
      ]);
    } catch (e) {
      debugLog('ProgressScreen', 'Error loading data: $e');
    } finally {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final streakProvider = Provider.of<StreakProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);

    // Check if user has access to progress
    if (authProvider.user?.accountStatus != 'active') {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: const EmptyState(
          icon: Icons.trending_up,
          title: 'Progress Unavailable',
          message:
              'Progress tracking is available for active subscribers only.',
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: RefreshIndicator(
        onRefresh: () async {
          final streakProvider =
              Provider.of<StreakProvider>(context, listen: false);
          final examProvider =
              Provider.of<ExamProvider>(context, listen: false);

          await Future.wait([
            streakProvider.loadStreak(),
            examProvider.loadMyExamResults(),
          ]);
        },
        child: ListView(
          children: [
            // Streak Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreakWidget(streak: streakProvider.streak),
            ),

            // Overall Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Progress',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(
                        height: 200,
                        child: ProgressChart(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Exam Results Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam Results',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (examProvider.myExamResults.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.quiz, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No Exam Results',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Take exams to see your results here',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: examProvider.myExamResults.length,
                      itemBuilder: (context, index) {
                        final result = examProvider.myExamResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: result.passed
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              child: Icon(
                                result.passed ? Icons.check : Icons.close,
                                color:
                                    result.passed ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(result.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Score: ${result.formattedScore}'),
                                Text(
                                  'Date: ${result.startedAt.day}/${result.startedAt.month}/${result.startedAt.year}',
                                ),
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                result.passed ? 'Passed' : 'Failed',
                                style: TextStyle(
                                  color:
                                      result.passed ? Colors.green : Colors.red,
                                ),
                              ),
                              backgroundColor: result.passed
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
