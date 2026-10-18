import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades [child] in and lifts it a little into place when it first shows.
/// Siblings pass their [index] to come in one after another (the first few
/// only, so a long page doesn't keep you waiting). Shown at once with
/// reduced motion, and never again on rebuilds.
class Entrance extends StatefulWidget {
  const Entrance({required this.child, this.index = 0, super.key});

  final int index;
  final Widget child;

  static const step = Duration(milliseconds: 60);
  static const length = Duration(milliseconds: 380);
  static const _staggered = 6;
  static const _lift = 16.0;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = Entrance.step * math.min(widget.index, Entrance._staggered);
    final total = delay + Entrance.length;
    _controller = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _t.value) * Entrance._lift),
        child: child,
      ),
    ),
    child: widget.child,
  );
}
