import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quick_input_timings.g.dart';

/// Times from the end of speech to the confirmation items on screen, this
/// session, for METRICS.md (task 5.5). Shown in Settings.
@Riverpod(keepAlive: true)
class QuickInputTimings extends _$QuickInputTimings {
  @override
  List<Duration> build() => const [];

  void add(Duration time) => state = [...state, time];

  void clear() => state = const [];
}

/// The median of [times], or null if there are none.
Duration? medianOf(List<Duration> times) {
  if (times.isEmpty) return null;
  final sorted = [...times]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) ~/ 2;
}
