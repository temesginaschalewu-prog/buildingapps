import 'package:familyacademyclient/models/exam_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/screens/auth/device_change_screen.dart';
import 'package:familyacademyclient/screens/auth/login_screen.dart';
import 'package:familyacademyclient/screens/auth/register_screen.dart';
import 'package:familyacademyclient/screens/category/category_detail_screen.dart';
import 'package:familyacademyclient/screens/chapter/chapter_content_screen.dart';
import 'package:familyacademyclient/screens/chapter/chapter_list_screen.dart';
import 'package:familyacademyclient/screens/course/course_detail_screen.dart';
import 'package:familyacademyclient/screens/course/course_list_screen.dart';
import 'package:familyacademyclient/screens/exam/exam_list_screen.dart';
import 'package:familyacademyclient/screens/exam/exam_screen.dart';
import 'package:familyacademyclient/screens/main/chatbot_screen.dart';
import 'package:familyacademyclient/screens/main/home_screen.dart';
import 'package:familyacademyclient/screens/main/main_navigation.dart';
import 'package:familyacademyclient/screens/main/profile_screen.dart';
import 'package:familyacademyclient/screens/main/progress_screen.dart';
import 'package:familyacademyclient/screens/notifications/notification_screen.dart';
import 'package:familyacademyclient/screens/onboarding/school_selection_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_success_screen.dart';
import 'package:familyacademyclient/screens/settings/parent_link_screen.dart';
import 'package:familyacademyclient/screens/settings/subscription_screen.dart';
import 'package:familyacademyclient/screens/settings/support_screen.dart';
import 'package:familyacademyclient/screens/settings/tv_pairing_screen.dart';

class AppRouter {
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/auth/login',
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAuthenticated = authProvider.isAuthenticated;

        final isPublicRoute = [
          '/auth/login',
          '/auth/register',
          '/device-change',
        ].contains(state.uri.toString());

        if (!isAuthenticated && !isPublicRoute) {
          return '/auth/login';
        }

        if (isAuthenticated &&
            authProvider.user?.schoolId == null &&
            state.uri.toString() != '/school-selection') {
          return '/school-selection';
        }

        if (isAuthenticated &&
            authProvider.user?.schoolId != null &&
            state.uri.toString().startsWith('/auth/')) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/auth/register',
          name: 'register',
          pageBuilder: (context, state) =>
              const MaterialPage(child: RegisterScreen()),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'login',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginScreen()),
        ),
        GoRoute(
          path: '/device-change',
          name: 'device-change',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return MaterialPage(child: DeviceChangeScreen());
          },
        ),
        GoRoute(
          path: '/school-selection',
          name: 'school-selection',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SchoolSelectionScreen()),
        ),
        GoRoute(
          path: '/payment',
          name: 'payment',
          pageBuilder: (context, state) {
            return MaterialPage(
              child: PaymentScreen(extra: state.extra as Map<String, dynamic>?),
            );
          },
        ),
        GoRoute(
          path: '/payment-success',
          name: 'payment-success',
          pageBuilder: (context, state) =>
              const MaterialPage(child: PaymentSuccessScreen()),
        ),
        GoRoute(
          path: '/subscriptions',
          name: 'subscriptions',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SubscriptionScreen()),
        ),
        GoRoute(
          path: '/tv-pairing',
          name: 'tv-pairing',
          pageBuilder: (context, state) =>
              const MaterialPage(child: TvPairingScreen()),
        ),
        GoRoute(
          path: '/parent-link',
          name: 'parent-link',
          pageBuilder: (context, state) =>
              const MaterialPage(child: ParentLinkScreen()),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SupportScreen()),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) =>
              const MaterialPage(child: NotificationsScreen()),
        ),
        GoRoute(
          path: '/category/:categoryId',
          name: 'category-detail',
          pageBuilder: (context, state) {
            final categoryId =
                int.tryParse(state.pathParameters['categoryId'] ?? '0') ?? 0;
            return MaterialPage(
              key: ValueKey('category-$categoryId'),
              child: CategoryDetailScreen(categoryId: categoryId),
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId',
          name: 'course-detail',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return MaterialPage(
              key: ValueKey('course-$courseId'),
              child: CourseDetailScreen(courseId: courseId),
            );
          },
        ),
        GoRoute(
          path: '/chapter/:chapterId',
          name: 'chapter-content',
          pageBuilder: (context, state) {
            final chapterId =
                int.tryParse(state.pathParameters['chapterId'] ?? '0') ?? 0;
            return MaterialPage(
              key: ValueKey('chapter-$chapterId'),
              child: ChapterContentScreen(chapterId: chapterId),
            );
          },
        ),
        GoRoute(
          path: '/exam/:examId',
          name: 'exam',
          pageBuilder: (context, state) {
            final examId =
                int.tryParse(state.pathParameters['examId'] ?? '0') ?? 0;
            final exam = state.extra as Exam?;
            return MaterialPage(
              key: ValueKey('exam-$examId'),
              child: ExamScreen(
                examId: examId,
                exam: exam,
              ),
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId/chapters',
          name: 'chapter-list',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return MaterialPage(
              key: ValueKey('chapter-list-$courseId'),
              child: ChapterListScreen(courseId: courseId),
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId/exams',
          name: 'exam-list',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return MaterialPage(
              key: ValueKey('exam-list-$courseId'),
              child: ExamListScreen(courseId: courseId),
            );
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainNavigation(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: '/chatbot',
              name: 'chatbot',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ChatbotScreen()),
            ),
            GoRoute(
              path: '/progress',
              name: 'progress',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProgressScreen()),
            ),
            GoRoute(
              path: '/profile',
              name: 'profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '404',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
