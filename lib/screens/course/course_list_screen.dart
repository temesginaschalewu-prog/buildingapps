import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../widgets/course/course_card.dart';
import '../../widgets/common/loading_indicator.dart';

class CourseListScreen extends StatelessWidget {
  final int categoryId;

  const CourseListScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context);
    final courses = courseProvider.getCoursesByCategory(categoryId);

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: courseProvider.isLoading
          ? const LoadingIndicator()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CourseCard(
                    course: course,
                    onTap: () {
                      // Navigate to course detail
                    },
                  ),
                );
              },
            ),
    );
  }
}
