import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvInputShell extends StatelessWidget {
  const TvInputShell({super.key, required this.child});

  final Widget child;

  Future<void> _handleDismiss(BuildContext context) async {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    final focusedWidget = focusContext?.widget;

    if (focusedWidget is EditableText) {
      primaryFocus?.unfocus();
      return;
    }

    final navigator = Navigator.maybeOf(focusContext ?? context);
    if (navigator != null && await navigator.maybePop()) {
      return;
    }

    primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (intent) {
              unawaited(_handleDismiss(context));
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(child: child),
      ),
    );
  }
}

class TvScrollBehavior extends MaterialScrollBehavior {
  const TvScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
