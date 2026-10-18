import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/value_objects/penny_mood.dart';
import 'penny_head.dart';

/// Penny's full-body illustrations, for the big moments: onboarding, empty
/// states, celebrations, errors. Made from `docs/brand/penny` by
/// `tool/penny/make_poses.py`, all the same size with the feet on one line.
enum PennyArt {
  wave('penny_wave', PennyMood.happy),
  wallet('penny_wallet', PennyMood.happy),
  budget('penny_budget', PennyMood.calm),
  friends('penny_friends', PennyMood.happy),
  phone('penny_phone', PennyMood.calm),
  sleep('penny_sleep', PennyMood.sleepy),
  celebrate('penny_celebrate', PennyMood.excited),
  worried('penny_worried', PennyMood.worried),
  listen('penny_listen', PennyMood.listening);

  const PennyArt(this._file, this.mood);

  final String _file;

  /// Her face for this pose, drawn instead if the artwork can't load.
  final PennyMood mood;

  String get asset => 'assets/penny/$_file.webp';
}

/// One of Penny's [pose]s on a soft glow, floating up gently when it first
/// shows and hopping when [hops] changes (neither with reduced motion).
/// Decoration: the words next to her say what she means.
class PennyPose extends StatelessWidget {
  const PennyPose(this.pose, {this.size = 180, this.hops = 0, super.key});

  final PennyArt pose;
  final double size;

  /// Bump to make her hop (new words were heard).
  final int hops;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final art = Image.asset(
      pose.asset,
      width: size,
      height: size,
      // Decoded at the size shown, not the full 600 px.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      gaplessPlayback: true,
      // A missing or broken asset falls back to her face.
      errorBuilder: (context, _, _) => Center(
        child: PennyHead(mood: pose.mood, size: size * 0.6),
      ),
    );

    final glow = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          // Fades out fully inside the box, so no edge shows.
          center: const Alignment(0, 0.1),
          radius: 0.44,
          colors: [
            colors.primary.withValues(alpha: 0.16),
            colors.primary.withValues(alpha: 0),
          ],
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: _Hop(hops: hops, height: size * 0.05, child: art),
      ),
    );

    return ExcludeSemantics(
      child: MediaQuery.disableAnimationsOf(context)
          ? glow
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 12),
                  child: child,
                ),
              ),
              child: glow,
            ),
    );
  }
}

/// A small hop each time [hops] changes.
class _Hop extends StatefulWidget {
  const _Hop({required this.hops, required this.height, required this.child});

  final int hops;
  final double height;
  final Widget child;

  @override
  State<_Hop> createState() => _HopState();
}

class _HopState extends State<_Hop> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void didUpdateWidget(_Hop old) {
    super.didUpdateWidget(old);
    if (old.hops != widget.hops && !MediaQuery.disableAnimationsOf(context)) {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _hop,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -math.sin(_hop.value * math.pi) * widget.height),
      child: child,
    ),
    child: widget.child,
  );
}
