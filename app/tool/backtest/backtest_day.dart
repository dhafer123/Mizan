import 'backtest_outcome.dart';

/// One replayed day: what the forecast said at the end of [day], and when
/// money really ran out. Dates are calendar days (UTC midnight).
class BacktestDay {
  const BacktestDay({
    required this.day,
    required this.outcome,
    this.coldStart = false,
    this.forecast,
    this.earliest,
    this.latest,
    this.actual,
    this.errorDays,
  });

  final DateTime day;
  final BacktestOutcome outcome;

  /// The forecast used the budget, not a learned rate.
  final bool coldStart;

  /// The forecast's run-out date; null if past its horizon.
  final DateTime? forecast;

  /// The forecast's range; null if past its horizon.
  final DateTime? earliest;
  final DateTime? latest;

  /// The first day money left really went below 0; null if not before the
  /// data or the horizon ended.
  final DateTime? actual;

  /// Forecast − actual in days: above 0 means the forecast was too late
  /// (too hopeful). For [BacktestOutcome.atLeast], a lower bound on the
  /// size of the error, with its sign. Null when nothing is known.
  final int? errorDays;

  /// Whether the real run-out fell inside the forecast's range. Null unless
  /// [outcome] is [BacktestOutcome.exact].
  bool? get inRange {
    if (outcome != BacktestOutcome.exact) return null;
    final actual = this.actual;
    final earliest = this.earliest;
    final latest = this.latest;
    // Both past the horizon: the range said so if its latest end did.
    if (actual == null) return latest == null;
    return earliest != null &&
        !actual.isBefore(earliest) &&
        (latest == null || !actual.isAfter(latest));
  }

  @override
  String toString() {
    String date(DateTime? d) =>
        d == null ? '-' : d.toIso8601String().substring(0, 10);
    return '${date(day)}  ${outcome.name.padRight(10)}'
        '${coldStart ? ' cold' : '     '}'
        '  forecast ${date(forecast)} (${date(earliest)}..${date(latest)})'
        '  actual ${date(actual)}'
        '  error ${errorDays ?? '-'}';
  }
}
