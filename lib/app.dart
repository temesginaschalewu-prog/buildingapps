import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'utils/router.dart';
import 'services/notification_service.dart';
import 'utils/helpers.dart';

class FamilyAcademyApp extends StatefulWidget {
  final NotificationService notificationService;

  const FamilyAcademyApp({
    super.key,
    required this.notificationService,
  });

  @override
  State<FamilyAcademyApp> createState() => _FamilyAcademyAppState();
}

class _FamilyAcademyAppState extends State<FamilyAcademyApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await widget.notificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Family Academy',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter().router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: 1.0,
              ),
              child: child ?? const SizedBox(),
            );
          },
        );
      },
    );
  }
}
