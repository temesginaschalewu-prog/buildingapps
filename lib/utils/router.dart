import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/screens/auth/device_change_screen.dart';
import 'package:familyacademyclient/screens/auth/login_screen.dart';
import 'package:familyacademyclient/screens/auth/register_screen.dart';
import 'package:familyacademyclient/screens/category/category_detail_screen.dart';
import 'package:familyacademyclient/screens/chapter/chapter_content_screen.dart';
import 'package:familyacademyclient/screens/course/course_detail_screen.dart';
import 'package:familyacademyclient/screens/exam/exam_screen.dart';
import 'package:familyacademyclient/screens/main/main_navigation.dart';
import 'package:familyacademyclient/screens/onboarding/school_selection_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_success_screen.dart';
import 'package:familyacademyclient/screens/settings/parent_link_screen.dart';
import 'package:familyacademyclient/screens/settings/subscription_screen.dart';
import 'package:familyacademyclient/screens/settings/support_screen.dart';
import 'package:familyacademyclient/screens/settings/tv_pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AppRouter {
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // If user is not authenticated and trying to access protected routes
        final isAuthRoute = state.uri.toString().startsWith('/auth');
        final isOnboardingRoute =
            state.uri.toString().startsWith('/school-selection');
        final isProtectedRoute = !isAuthRoute && !isOnboardingRoute;

        if (!authProvider.isAuthenticated && isProtectedRoute) {
          return '/auth/login';
        }

        // If user is authenticated but hasn't selected school
        if (authProvider.isAuthenticated &&
            authProvider.user?.schoolId == null &&
            state.uri.toString() != '/school-selection') {
          return '/school-selection';
        }

        return null;
      },
      routes: [
        // Auth Routes
        GoRoute(
          path: '/auth/register',
          name: 'register',
          pageBuilder: (context, state) => const MaterialPage(
            child: RegisterScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'login',
          pageBuilder: (context, state) => const MaterialPage(
            child: LoginScreen(),
          ),
        ),
        GoRoute(
          path: '/device-change',
          name: 'device-change',
          pageBuilder: (context, state) => const MaterialPage(
            child: DeviceChangeScreen(),
          ),
        ),

        // Onboarding Routes
        GoRoute(
          path: '/school-selection',
          name: 'school-selection',
          pageBuilder: (context, state) => const MaterialPage(
            child: SchoolSelectionScreen(),
          ),
        ),

        // Payment Routes
        GoRoute(
          path: '/payment',
          name: 'payment',
          pageBuilder: (context, state) => MaterialPage(
            child: PaymentScreen(),
          ),
        ),

        GoRoute(
          path: '/payment-success',
          name: 'payment-success',
          builder: (context, state) => const PaymentSuccessScreen(),
        ),

        // Settings Routes
        GoRoute(
          path: '/subscriptions',
          name: 'subscriptions',
          pageBuilder: (context, state) => const MaterialPage(
            child: SubscriptionScreen(),
          ),
        ),
        GoRoute(
          path: '/tv-pairing',
          name: 'tv-pairing',
          pageBuilder: (context, state) => const MaterialPage(
            child: TvPairingScreen(),
          ),
        ),
        GoRoute(
          path: '/parent-link',
          name: 'parent-link',
          pageBuilder: (context, state) => const MaterialPage(
            child: ParentLinkScreen(),
          ),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          pageBuilder: (context, state) => const MaterialPage(
            child: SupportScreen(),
          ),
        ),

        // Main Navigation with nested routes
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) => const MaterialPage(
            child: MainNavigation(),
          ),
          routes: [
            // Category detail route
            GoRoute(
              path: 'category/:categoryId',
              name: 'category-detail',
              pageBuilder: (context, state) {
                final categoryId =
                    int.tryParse(state.pathParameters['categoryId'] ?? '0') ??
                        0;
                return MaterialPage(
                  child: CategoryDetailScreen(categoryId: categoryId),
                );
              },
            ),

            // Course detail route
            GoRoute(
              path: 'course/:courseId',
              name: 'course-detail',
              pageBuilder: (context, state) {
                final courseId =
                    int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
                return MaterialPage(
                  child: CourseDetailScreen(courseId: courseId),
                );
              },
            ),

            // Chapter content route
            GoRoute(
              path: 'chapter/:chapterId',
              name: 'chapter-content',
              pageBuilder: (context, state) {
                final chapterId =
                    int.tryParse(state.pathParameters['chapterId'] ?? '0') ?? 0;
                return MaterialPage(
                  child: ChapterContentScreen(chapterId: chapterId),
                );
              },
            ),

            // Exam route
            GoRoute(
              path: 'exam/:examId',
              name: 'exam',
              pageBuilder: (context, state) {
                final examId =
                    int.tryParse(state.pathParameters['examId'] ?? '0') ?? 0;
                return MaterialPage(
                  child: ExamScreen(examId: examId),
                );
              },
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
