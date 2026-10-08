import 'backtest_day.dart';
import 'backtest_outcome.dart';

/// The backtest's numbers over a set of replayed days.
class BacktestSummary {
  const BacktestSummary._({
    required this.days,
    required this.counts,
    required this.meanAbsError,
    required this.meanAbsErrorAtLeast,
    required this.bias,
    required this.inRange,
  });

  factory BacktestSummary.of(Iterable<BacktestDay> days) {
    final list = days.toList();
    final exact = [
      for (final d in list)
        if (d.outcome == BacktestOutcome.exact) d.errorDays!,
    ];
    final bounded = [
      ...exact,
      for (final d in list)
        if (d.outcome == BacktestOutcome.atLeast) d.errorDays!,
    ];
    double? mean(List<int> values) =>
        values.isEmpty ? null : values.fold(0, (a, b) => a + b) / values.length;
    final ranges = [for (final d in list) ?d.inRange];
    return BacktestSummary._(
      days: list.length,
      counts: {
        for (final outcome in BacktestOutcome.values)
          outcome: list.where((d) => d.outcome == outcome).length,
      },
      meanAbsError: mean([for (final e in exact) e.abs()]),
      meanAbsErrorAtLeast: mean([for (final e in bounded) e.abs()]),
      bias: mean(exact),
      inRange: ranges.isEmpty
          ? null
          : ranges.where((hit) => hit).length / ranges.length,
    );
  }

  final int days;
  final Map<BacktestOutcome, int> counts;

  /// Mean absolute error in days over the exact days.
  final double? meanAbsError;

  /// The same over the exact and lower-bound days, counting each bound as
  /// its error: a lower bound on the true mean over those days.
  final double? meanAbsErrorAtLeast;

  /// Mean signed error over the exact days: above 0, forecasts ran out
  /// later than reality (too hopeful).
  final double? bias;

  /// Share of exact days whose real run-out was inside the forecast range.
  final double? inRange;

  int count(BacktestOutcome outcome) => counts[outcome] ?? 0;

  @override
  String toString() {
    String num(double? v) => v == null ? '-' : v.toStringAsFixed(2);
    String pct(double? v) =>
        v == null ? '-' : '${(v * 100).toStringAsFixed(0)}%';
    return [
      'days replayed:         $days',
      '  exact:               ${count(BacktestOutcome.exact)}',
      '  lower bound only:    ${count(BacktestOutcome.atLeast)}',
      '  censored:            ${count(BacktestOutcome.censored)}',
      '  already run out:     ${count(BacktestOutcome.alreadyOut)}',
      '  no forecast:         ${count(BacktestOutcome.noForecast)}',
      'mean abs. error:       ${num(meanAbsError)} days (exact days)',
      'with lower bounds:     >= ${num(meanAbsErrorAtLeast)} days',
      'bias (+ = too late):   ${num(bias)} days',
      'actual inside range:   ${pct(inRange)}',
    ].join('\n');
  }
}
