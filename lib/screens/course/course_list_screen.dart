import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/helpers.dart';

class CourseListScreen extends StatelessWidget {
  final int categoryId;

  const CourseListScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    final courses = courseProvider.getCoursesByCategory(categoryId);
    final hasAccess =
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    debugLog('CourseListScreen',
        'Category: $categoryId, Courses: ${courses.length}, Has Access: $hasAccess');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => courseProvider.loadCoursesByCategory(categoryId),
          ),
        ],
      ),
      body: courseProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () => courseProvider.loadCoursesByCategory(categoryId),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CourseCard(
                      course: course,
                      categoryId: categoryId,
                      onTap: () {
                        // Navigate to course detail
                        // This should be handled by the parent screen
                        debugLog('CourseListScreen',
                            'Course tapped: ${course.name}');
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
