import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';
import 'controllers/tv_session_controller.dart';
import 'screens/main/main_navigation.dart';
import 'screens/pairing_screen.dart';
import 'services/tv_api_service.dart';
import 'widgets/tv_input_shell.dart';
import 'widgets/tv_focus_card.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  final api = TvApiService();
  runApp(FamilyAcademyTvApp(apiService: api));
}

class FamilyAcademyTvApp extends StatelessWidget {
  const FamilyAcademyTvApp({super.key, required this.apiService});

  final TvApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TvApiService>.value(value: apiService),
        ChangeNotifierProvider(
          create: (_) => TvSessionController(apiService)..bootstrap(),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF09111F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4EA1FF),
            secondary: Color(0xFF72B4FF),
            surface: Color(0xFF10203B),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        scrollBehavior: const TvScrollBehavior(),
        home: const TvAppBootstrap(),
        builder: (context, child) {
          return TvInputShell(child: child ?? const SizedBox());
        },
      ),
    );
  }
}

class TvAppBootstrap extends StatelessWidget {
  const TvAppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TvSessionController>();

    switch (session.state) {
      case TvBootState.loading:
        return Scaffold(
          body: Center(
            child: session.loadingTimedOut
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Starting Family Academy TV is taking longer than expected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Please try again in a moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8C6E3),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 280,
                          child: TvFocusCard(
                            autofocus: true,
                            onPressed: session.bootstrap,
                            child: const Center(
                              child: Text(
                                'Try Again',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      case TvBootState.authenticated:
        return const TvShellScreen();
      case TvBootState.pairing:
      case TvBootState.error:
        return const PairingScreen();
    }
  }
}
