import 'package:flutter/material.dart';

/// A progress bar that grows to its [value] (0–1) when it first shows, and
/// slides to a new value when it changes. Still with reduced motion. Screen
/// readers hear the final percent, never the frames in between.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    required this.value,
    this.color,
    this.backgroundColor,
    this.minHeight = 6,
    this.semanticsLabel,
    super.key,
  });

  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double minHeight;
  final String? semanticsLabel;

  static const duration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    final end = value.clamp(0.0, 1.0);
    Widget bar(double shown) => LinearProgressIndicator(
      value: shown,
      color: color,
      backgroundColor: backgroundColor,
      minHeight: minHeight,
      borderRadius: BorderRadius.circular(minHeight / 2),
      semanticsLabel: semanticsLabel,
      semanticsValue: '${(end * 100).round()}%',
    );
    if (MediaQuery.disableAnimationsOf(context)) return bar(end);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: end),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => bar(shown),
    );
  }
}
