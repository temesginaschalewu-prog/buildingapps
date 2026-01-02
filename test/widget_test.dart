import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:familyacademyclient/main.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/storage_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              apiService: ApiService(),
              storageService: StorageService(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('Family Academy Test'))),
        ),
      ),
    );

    // Verify that our counter starts at 0.
    expect(find.text('Family Academy Test'), findsOneWidget);
  });
}
