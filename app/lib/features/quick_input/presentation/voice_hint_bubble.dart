import 'dart:async';

import 'package:flutter/material.dart';

/// A speech bubble pointing right, at the voice button beside it, saying
/// what it does. It comes and goes ([shown] on, [hidden] off) so it doesn't
/// crowd the screen. Tapping it does the same as the button.
///
/// Decoration for screen readers: the button's own label says the same.
class VoiceHintBubble extends StatefulWidget {
  const VoiceHintBubble({required this.onTap, super.key});

  final VoidCallback onTap;

  static const shown = Duration(seconds: 4);
  static const hidden = Duration(seconds: 8);

  @override
  State<VoiceHintBubble> createState() => _VoiceHintBubbleState();
}

class _VoiceHintBubbleState extends State<VoiceHintBubble> {
  var _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer = Timer(
      _visible ? VoiceHintBubble.shown : VoiceHintBubble.hidden,
      () {
        if (!mounted) return;
        setState(() => _visible = !_visible);
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return ExcludeSemantics(
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: fade,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.inverseSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Say your expense',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(8, 16),
                  painter: _TailPainter(colors.inverseSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bubble's tail: a triangle pointing right.
class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
