import 'dart:convert';
import 'dart:io' show Platform;

import 'package:familyacademyclient/app.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/chatbot_provider.dart';
import 'package:familyacademyclient/providers/device_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/school_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/providers/video_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/exam_question_provider.dart';
import 'package:familyacademyclient/providers/chapter_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/note_provider.dart';
import 'package:familyacademyclient/providers/question_provider.dart';
import 'package:familyacademyclient/providers/parent_link_provider.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/storage_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final notificationService = NotificationService();
  await notificationService.init();

  await notificationService.showLocalNotification(
    title: message.notification?.title ?? 'Background Notification',
    body: message.notification?.body ?? '',
    payload: json.encode(message.data),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await _initializeScreenProtection();

  final storageService = StorageService();
  await storageService.init();
  debugPrint('Main: StorageService initialized');

  final apiService = ApiService();
  debugPrint('Main: ApiService created');
  final notificationService = NotificationService();
  await notificationService.init();
  debugPrint('Main: NotificationService initialized');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            apiService: apiService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SchoolProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CourseProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ExamProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ExamQuestionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChapterProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => NoteProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => QuestionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => StreakProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ParentLinkProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
      ],
      child: FamilyAcademyApp(
        notificationService: notificationService,
      ),
    ),
  );
}

Future<void> _initializeScreenProtection() async {
  try {
    if (Platform.isAndroid) {
      await ScreenProtector.preventScreenshotOn();
    }
  } catch (e) {
    debugPrint('Failed to initialize screen protection: $e');
  }
}
