import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusCard extends StatefulWidget {
  const TvFocusCard({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFF142039),
    this.borderRadius = 24,
    this.focusedBorderColor = const Color(0xFF4EA1FF),
    this.unfocusedBorderColor = Colors.white12,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;
  final EdgeInsets padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color focusedBorderColor;
  final Color unfocusedBorderColor;

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _focused ? 1.04 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _focused
                    ? widget.focusedBorderColor
                    : widget.unfocusedBorderColor,
                width: _focused ? 2.5 : 1,
              ),
              boxShadow: _focused
                  ? const [
                      BoxShadow(
                        color: Color(0x553F8CFF),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
