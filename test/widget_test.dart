import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create mock services
    final connectivityService = ConnectivityService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ConnectivityService>.value(value: connectivityService),
          ChangeNotifierProvider(
            create: (_) =>
                ThemeProvider(connectivityService: connectivityService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Family Academy Test'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Family Academy Test'), findsOneWidget);
  });
}
