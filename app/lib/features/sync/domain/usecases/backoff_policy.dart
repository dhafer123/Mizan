import 'dart:math';

/// How long to wait before retry number [attempt] (0-based) after a failed
/// sync: exponential, capped, with ±[jitter] so phones that went offline
/// together don't all retry at the same moment.
class BackoffPolicy {
  const BackoffPolicy({
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 5),
    this.jitter = 0.2,
  });

  final Duration base;
  final Duration max;

  /// Fraction of the delay, either way.
  final double jitter;

  /// [random] in [0, 1); defaults to a fresh `Random`.
  Duration call(int attempt, {double Function()? random}) {
    final exponent = attempt.clamp(0, 30);
    final raw = base.inMilliseconds * pow(2, exponent);
    final capped = min(raw, max.inMilliseconds).toDouble();
    final r = (random ?? Random().nextDouble)();
    final factor = 1 - jitter + 2 * jitter * r;
    return Duration(milliseconds: (capped * factor).round());
  }
}
