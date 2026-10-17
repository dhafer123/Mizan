import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/value_objects/penny_mood.dart';

/// Penny's head, drawn in code from the mascot sheet: the navy hood with its
/// cyan tuft, the white rim, the black visor, and glowing eyes that change
/// with her [mood].
///
/// She's alive in short bursts on timers rather than endless loops: a blink
/// or a small bob every few seconds, a pulse while listening, a floating "z"
/// while asleep, and a bounce when her mood changes or she's [pokes]d. Short
/// animations let the screen settle in between (and in tests). With reduced
/// motion she holds still and changes expression without animating.
///
/// Decoration only: whatever her face means is always also said in words.
class PennyHead extends StatefulWidget {
  const PennyHead({
    required this.mood,
    this.size = 72,
    this.pokes = 0,
    super.key,
  });

  final PennyMood mood;
  final double size;

  /// Bump to make her bounce (she was tapped, or new words were heard).
  final int pokes;

  @override
  State<PennyHead> createState() => _PennyHeadState();
}

class _PennyHeadState extends State<PennyHead> with TickerProviderStateMixin {
  static const _idleEvery = (min: 2600, max: 5200); // ms
  static const _pulseEvery = Duration(milliseconds: 1100);

  final _random = math.Random();
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _idle;
  late PennyMood _previous = widget.mood;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(PennyHead old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _previous = old.mood;
      if (_still) {
        _swap.value = 1;
      } else {
        _swap.forward(from: 0);
      }
      _schedule();
    }
    if (old.pokes != widget.pokes && !_still) _bob.forward(from: 0);
  }

  /// The next burst of life, a few seconds from now.
  void _schedule() {
    _idle?.cancel();
    if (_still) return;
    final listening = widget.mood == PennyMood.listening;
    final wait = listening
        ? _pulseEvery
        : Duration(
            milliseconds:
                _idleEvery.min +
                _random.nextInt(_idleEvery.max - _idleEvery.min),
          );
    _idle = Timer(wait, () {
      if (!mounted) return;
      switch (widget.mood) {
        case PennyMood.listening:
          _pulse.forward(from: 0);
        case PennyMood.sleepy:
          _pulse.forward(from: 0); // the "z" floats up
        case PennyMood.calm || PennyMood.worried || PennyMood.surprised:
          // Mostly blinks, sometimes a bob.
          if (_random.nextInt(3) == 0) {
            _bob.forward(from: 0);
          } else {
            _blink.forward(from: 0).then((_) {
              if (mounted) _blink.reverse();
            });
          }
        case PennyMood.happy || PennyMood.excited || PennyMood.wink:
          _bob.forward(from: 0);
      }
      _schedule();
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _blink.dispose();
    _bob.dispose();
    _swap.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_blink, _bob, _swap, _pulse]),
          builder: (context, _) {
            final bob = math.sin(_bob.value * math.pi);
            final swap = Curves.easeOut.transform(_swap.value);
            final bounce = math.sin(swap * math.pi) * 0.06;
            return Transform.translate(
              offset: Offset(0, -bob * widget.size * 0.04),
              child: Transform.scale(
                scale: 1 + bounce + bob * 0.02,
                child: CustomPaint(
                  painter: PennyPainter(
                    mood: widget.mood,
                    previous: _previous,
                    swap: swap,
                    openness: 1 - _blink.value,
                    pulse: math.sin(_pulse.value * math.pi),
                    float: _pulse.value,
                    glow: dark,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints Penny on a 100×100 canvas, scaled to the size given.
class PennyPainter extends CustomPainter {
  const PennyPainter({
    required this.mood,
    this.previous,
    this.swap = 1,
    this.openness = 1,
    this.pulse = 0,
    this.float = 0,
    this.glow = false,
  });

  final PennyMood mood;

  /// The mood she's changing from, faded out as [swap] goes 0 → 1.
  final PennyMood? previous;
  final double swap;

  /// 1 with eyes open, 0 mid-blink.
  final double openness;

  /// 0 → 1 → 0 during a listening pulse.
  final double pulse;

  /// 0 → 1 as a sleepy "z" floats up.
  final double float;

  /// A cyan halo, so the navy hood stands out on dark pages.
  final bool glow;

  static const _cyan = Color(0xFF22D3EE);
  static const _hoodTop = Color(0xFF34489F);
  static const _hoodBottom = Color(0xFF141A3D);
  static const _rim = Color(0xFFEEF2FF);
  static const _rimShade = Color(0xFFC3CDEE);

  static const _leftEye = Offset(36.5, 67);
  static const _rightEye = Offset(63.5, 67);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 100, size.height / 100);
    final hood = _hoodPath();

    if (glow) {
      canvas.drawPath(
        hood,
        Paint()
          ..color = _cyan.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    } else {
      canvas.drawShadow(hood, Colors.black, 3, false);
    }

    _tuft(canvas);
    canvas.drawPath(
      hood,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hoodTop, _hoodBottom],
        ).createShader(const Rect.fromLTWH(0, 20, 100, 82)),
    );
    // Soft light on the hood's top left.
    canvas.drawPath(
      hood,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.7),
          radius: 0.7,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(const Rect.fromLTWH(0, 20, 100, 82)),
    );

    // The face opening: white rim, then the black visor with a gloss.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 65), width: 80, height: 62),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rim, _rimShade],
        ).createShader(const Rect.fromLTWH(10, 34, 80, 62)),
    );
    final visor = Rect.fromCenter(
      center: const Offset(50, 66.5),
      width: 67,
      height: 48,
    );
    canvas
      ..drawOval(
        visor,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111833), Color(0xFF02040C)],
          ).createShader(visor),
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(39, 50), width: 28, height: 7),
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );

    // Eyes: the old mood fades out as the new one fades in.
    canvas
      ..save()
      ..clipPath(Path()..addOval(visor));
    final old = previous;
    if (old != null && old != mood && swap < 1) {
      _face(canvas, old, 1 - swap);
    }
    final strength = old == null || old == mood ? 1.0 : swap;
    _face(canvas, mood, strength);
    canvas.restore();
    // Outside the visor: the sleepy "z"s float above the hood.
    if (mood == PennyMood.sleepy) _zzz(canvas, strength);
    if (old == PennyMood.sleepy && old != mood) _zzz(canvas, 1 - swap);
    canvas.restore();
  }

  Path _hoodPath() => Path()
    ..moveTo(12, 96)
    ..cubicTo(2, 76, 5, 40, 30, 27)
    ..cubicTo(42, 20, 58, 20, 70, 27)
    ..cubicTo(95, 40, 98, 76, 88, 96)
    ..quadraticBezierTo(50, 103, 12, 96)
    ..close();

  void _tuft(Canvas canvas) {
    Path leaf(Offset base, Offset tip, double width) {
      final mid = Offset.lerp(base, tip, 0.5)!;
      final along = tip - base;
      final normal = Offset(-along.dy, along.dx) / along.distance * (width / 2);
      return Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          mid.dx + normal.dx,
          mid.dy + normal.dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          mid.dx - normal.dx,
          mid.dy - normal.dy,
          base.dx,
          base.dy,
        )
        ..close();
    }

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5EEBFA), Color(0xFF0EA5E9)],
      ).createShader(const Rect.fromLTWH(30, 0, 44, 24));
    canvas
      ..drawPath(leaf(const Offset(45, 30), const Offset(30, 10), 14), paint)
      ..drawPath(leaf(const Offset(62, 30), const Offset(78, 15), 13), paint)
      ..drawPath(leaf(const Offset(53, 29), const Offset(61, 1), 19), paint);
  }

  void _face(Canvas canvas, PennyMood mood, double opacity) {
    if (opacity <= 0) return;
    final color = _cyan.withValues(alpha: opacity);
    final glow = Paint()
      ..color = _cyan.withValues(alpha: 0.55 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final fill = Paint()..color = color;
    Paint stroke(double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint strokeGlow(double width) => Paint()
      ..color = glow.color
      ..maskFilter = glow.maskFilter
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 2
      ..strokeCap = StrokeCap.round;

    void both(void Function(Offset centre, bool left) draw) {
      draw(_leftEye, true);
      draw(_rightEye, false);
    }

    void capsule(Offset c, double w, double h) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w, height: math.max(1.5, h)),
        Radius.circular(w / 2),
      );
      canvas
        ..drawRRect(rect.inflate(1.5), glow)
        ..drawRRect(rect, fill);
    }

    void arc(Offset c, {required bool up}) {
      // up: a happy "^"; down: closed, sleeping eyes.
      final d = up ? -9.0 : 8.0;
      final y = up ? 3.0 : -1.5;
      final path = Path()
        ..moveTo(c.dx - 8, c.dy + y)
        ..quadraticBezierTo(c.dx, c.dy + d, c.dx + 8, c.dy + y);
      canvas
        ..drawPath(path, strokeGlow(4.2))
        ..drawPath(path, stroke(4.2));
    }

    switch (mood) {
      case PennyMood.calm:
        both((c, _) => capsule(c, 9, 15 * openness));
      case PennyMood.happy:
        both((c, _) => arc(c, up: true));
      case PennyMood.excited:
        both((c, _) => _star(canvas, c, fill, glow));
      case PennyMood.worried:
        both((c, left) {
          capsule(c + const Offset(0, 2), 8.5, 12.5 * openness);
          // Brows tilted up towards the middle.
          final brow = left
              ? (c + const Offset(-7.5, -9), c + const Offset(5, -13.5))
              : (c + const Offset(-5, -13.5), c + const Offset(7.5, -9));
          canvas.drawLine(brow.$1, brow.$2, stroke(3));
        });
        // A small sweat drop by the right eye.
        final drop = Path()
          ..moveTo(76, 50)
          ..quadraticBezierTo(72, 57, 76, 59)
          ..quadraticBezierTo(80, 57, 76, 50)
          ..close();
        canvas.drawPath(
          drop,
          Paint()..color = const Color(0xFF9BE9F6).withValues(alpha: opacity),
        );
      case PennyMood.surprised:
        both((c, _) {
          final r = 7.5 * (0.4 + 0.6 * openness);
          canvas
            ..drawCircle(c, r, strokeGlow(3.4))
            ..drawCircle(c, r, stroke(3.4));
        });
        canvas.drawCircle(const Offset(50, 81), 3.2, stroke(2.4));
      case PennyMood.wink:
        arc(_leftEye, up: true);
        final c = _rightEye;
        final chevron = Path()
          ..moveTo(c.dx + 6.5, c.dy - 6.5)
          ..lineTo(c.dx - 5, c.dy)
          ..lineTo(c.dx + 6.5, c.dy + 6.5);
        canvas
          ..drawPath(chevron, strokeGlow(4))
          ..drawPath(chevron, stroke(4));
      case PennyMood.listening:
        both((c, _) {
          final r = 7 * (1 + 0.18 * pulse);
          canvas
            ..drawCircle(c, r, strokeGlow(3.2))
            ..drawCircle(c, r, stroke(3.2))
            ..drawCircle(c, 2.4, fill);
        });
      case PennyMood.sleepy:
        both((c, _) => arc(c, up: false));
    }
  }

  void _star(Canvas canvas, Offset c, Paint fill, Paint glow) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? 9.5 : 3.0;
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(path, glow)
      ..drawPath(path, fill);
  }

  /// Two little "z"s above the hood, drifting up and fading as [float] goes.
  void _zzz(Canvas canvas, double opacity) {
    void z(Offset at, double size, double alpha) {
      final s = size;
      final path = Path()
        ..moveTo(at.dx, at.dy)
        ..lineTo(at.dx + s, at.dy)
        ..lineTo(at.dx, at.dy + s)
        ..lineTo(at.dx + s, at.dy + s);
      canvas.drawPath(
        path,
        Paint()
          ..color = _cyan.withValues(alpha: alpha * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final rise = float * 6;
    z(Offset(80, 20 - rise), 8, 1 - float * 0.6);
    z(Offset(91, 8 - rise), 6, 0.8 - float * 0.5);
  }

  @override
  bool shouldRepaint(PennyPainter old) =>
      old.mood != mood ||
      old.previous != previous ||
      old.swap != swap ||
      old.openness != openness ||
      old.pulse != pulse ||
      old.float != float ||
      old.glow != glow;
}
