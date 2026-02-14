import 'package:familyacademyclient/models/exam_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/screens/splash/splash_screen.dart';
import 'package:familyacademyclient/screens/auth/device_change_screen.dart';
import 'package:familyacademyclient/screens/auth/login_screen.dart';
import 'package:familyacademyclient/screens/auth/register_screen.dart';
import 'package:familyacademyclient/screens/category/category_detail_screen.dart';
import 'package:familyacademyclient/screens/chapter/chapter_content_screen.dart';
import 'package:familyacademyclient/screens/course/course_detail_screen.dart';
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
import '../utils/helpers.dart';

class AppRouter {
  late final GoRouter router;
  bool _isLoginInProgress = false;
  bool _isDeviceChangeInProgress = false;

  // CRITICAL: Store device change data temporarily
  Map<String, dynamic>? _pendingDeviceChangeData;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) async {
        final location = state.uri.toString();
        debugLog('AppRouter', '📍 Route check: $location');

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // CRITICAL FIX: If device change is required and we have data, redirect with data
        if (authProvider.requiresDeviceChange && !_isDeviceChangeInProgress) {
          debugLog('AppRouter',
              '⚠️ Device change required - checking for pending data');

          // Try to get the last login result from auth provider
          final lastLoginResult = authProvider.lastLoginResult;

          if (lastLoginResult != null && lastLoginResult['data'] != null) {
            _pendingDeviceChangeData = {
              'username': lastLoginResult['username'],
              'password': lastLoginResult['password'],
              'deviceId': lastLoginResult['deviceId'],
              'fcmToken': lastLoginResult['fcmToken'],
              'currentDeviceId': lastLoginResult['data']['currentDeviceId'],
              'newDeviceId': lastLoginResult['data']['newDeviceId'],
              'changeCount': lastLoginResult['data']['changeCount'] ?? 0,
              'maxChanges': lastLoginResult['data']['maxChanges'] ?? 2,
              'remainingChanges':
                  lastLoginResult['data']['remainingChanges'] ?? 2,
              'canChangeDevice':
                  lastLoginResult['data']['canChangeDevice'] ?? true,
            };

            debugLog('AppRouter',
                '📦 Using pending device change data: $_pendingDeviceChangeData');
          }

          _isDeviceChangeInProgress = true;
          if (location != '/device-change') {
            return '/device-change';
          }
        }

        // If we're on device change screen, always allow access
        if (location.startsWith('/device-change')) {
          debugLog('AppRouter', '✅ Device change route - allowing access');
          return null;
        }

        // Reset device change flag when leaving device change screen
        if (!location.startsWith('/device-change') &&
            _isDeviceChangeInProgress) {
          _isDeviceChangeInProgress = false;
          _pendingDeviceChangeData = null;
        }

        // Special handling for login process
        if (_isLoginInProgress && location == '/auth/login') {
          debugLog(
              'AppRouter', '🔐 Login in progress - staying on login screen');
          return null;
        }

        // Reset login flag if we're not on login screen
        if (!location.startsWith('/auth/login')) {
          _isLoginInProgress = false;
        }

        // Special handling for splash - only for initial app start
        if (location == '/splash') {
          if (_isLoginInProgress) {
            debugLog('AppRouter',
                '🚫 Blocking splash during login - staying on login');
            return '/auth/login';
          }

          if (authProvider.isInitialized) {
            if (authProvider.isAuthenticated) {
              final user = authProvider.currentUser;
              if (user?.schoolId == null) {
                debugLog('AppRouter',
                    '🏫 Auth initialized + authenticated + no school → school-selection');
                return '/school-selection';
              } else {
                debugLog(
                    'AppRouter', '🏠 Auth initialized + authenticated → home');
                return '/';
              }
            } else {
              debugLog('AppRouter',
                  '🔐 Auth initialized + not authenticated → login');
              return '/auth/login';
            }
          }

          debugLog('AppRouter', '✅ First launch - showing splash');
          return null;
        }

        if (!authProvider.isInitialized && location != '/splash') {
          debugLog('AppRouter', '⏳ Auth not initialized - going to splash');
          return '/splash';
        }

        final isAuthenticated = authProvider.isAuthenticated;
        final user = authProvider.currentUser;

        final publicRoutes = [
          '/auth/login',
          '/auth/register',
          '/device-change',
          '/payment-success',
        ];

        final isPublicRoute = publicRoutes.any(
            (route) => location == route || location.startsWith('$route?'));

        if (!isAuthenticated && !isPublicRoute) {
          debugLog('AppRouter', '🔐 Not authenticated - redirecting to login');
          return '/auth/login';
        }

        if (isAuthenticated &&
            location.startsWith('/auth/') &&
            location != '/auth/logout') {
          if (user?.schoolId == null) {
            debugLog('AppRouter',
                '🏫 No school selected - going to school selection');
            return '/school-selection';
          }
          debugLog('AppRouter', '✅ Going to home');
          return '/';
        }

        if (isAuthenticated) {
          if (user?.schoolId == null &&
              location != '/school-selection' &&
              location != '/payment-success' &&
              !location.startsWith('/auth/') &&
              location != '/splash' &&
              !location.startsWith('/device-change')) {
            debugLog(
                'AppRouter', '📚 No school - redirecting to school selection');
            return '/school-selection';
          }
        }

        debugLog('AppRouter', '✅ Route allowed: $location');
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/auth/register',
          name: 'register',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'login',
          pageBuilder: (context, state) {
            final forceLogin = state.uri.queryParameters['force'] == 'true';
            return CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              fullscreenDialog: forceLogin,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),

        // CRITICAL FIX: Updated device-change route with data
        GoRoute(
          path: '/device-change',
          name: 'device-change',
          pageBuilder: (context, state) {
            // First try to get extra from state
            Map<String, dynamic> extra = {};

            if (state.extra != null && state.extra is Map<String, dynamic>) {
              extra = state.extra as Map<String, dynamic>;
              debugLog('AppRouter',
                  '📱 Got device-change data from state.extra: $extra');
            }
            // If no extra, try from pending data
            else if (_pendingDeviceChangeData != null) {
              extra = _pendingDeviceChangeData!;
              debugLog(
                  'AppRouter', '📱 Using pending device change data: $extra');
            }

            return MaterialPage(
              key: state.pageKey,
              child: DeviceChangeScreen(),
              fullscreenDialog: true,
              arguments: extra,
            );
          },
        ),
        GoRoute(
          path: '/school-selection',
          name: 'school-selection',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SchoolSelectionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/payment',
          name: 'payment',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: PaymentScreen(extra: state.extra as Map<String, dynamic>?),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/payment-success',
          name: 'payment-success',
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: PaymentSuccessScreen(
                  extra: state.extra as Map<String, dynamic>?),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/subscriptions',
          name: 'subscriptions',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SubscriptionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/tv-pairing',
          name: 'tv-pairing',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const TvPairingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/parent-link',
          name: 'parent-link',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ParentLinkScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SupportScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const NotificationsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        ),
        GoRoute(
          path: '/category/:categoryId',
          name: 'category-detail',
          pageBuilder: (context, state) {
            final categoryId =
                int.tryParse(state.pathParameters['categoryId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('category-$categoryId'),
              child: CategoryDetailScreen(categoryId: categoryId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId',
          name: 'course-detail',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('course-$courseId'),
              child: CourseDetailScreen(courseId: courseId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/chapter/:chapterId',
          name: 'chapter-content',
          pageBuilder: (context, state) {
            final chapterId =
                int.tryParse(state.pathParameters['chapterId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('chapter-$chapterId'),
              child: ChapterContentScreen(chapterId: chapterId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
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
            return CustomTransitionPage(
              key: ValueKey('exam-$examId'),
              child: ExamScreen(
                examId: examId,
                exam: exam,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId/exams',
          name: 'exam-list',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('exam-list-$courseId'),
              child: ExamListScreen(courseId: courseId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
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
      errorBuilder: (context, state) {
        debugLog('AppRouter', '❌ Route error: ${state.error}');

        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The page you\'re looking for\ncouldn\'t be found.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        );
      },
      debugLogDiagnostics: true,
    );
  }

  void markLoginInProgress(bool inProgress) {
    _isLoginInProgress = inProgress;
    debugLog('AppRouter', '🔐 Login in progress: $inProgress');
  }
}
