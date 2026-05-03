import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tv_session_controller.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TvSessionController>();
    final code = controller.pairingCode ?? '------';
    final digits = code.padRight(6, '-').split('');
    final statusMessage =
        controller.errorMessage ?? 'Generating your TV pairing code...';

    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Pair Your TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Open Family Academy on your phone, go to TV Pairing, and enter this code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB8C6E3),
                      fontSize: 20,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: digits
                        .map(
                          (digit) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            child: Container(
                              width: 92,
                              height: 116,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF12203A),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: const Color(0xFF2D5D9F),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                digit,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'This code refreshes automatically in ${controller.pairingCountdown}.',
                    style: const TextStyle(
                      color: Color(0xFF8FA5CB),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: controller.errorMessage == null
                            ? const Color(0xFFB8C6E3)
                            : const Color(0xFFFFB4B4),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () =>
                        controller.startPairingSession(showLoadingState: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4EA1FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Refresh Code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
