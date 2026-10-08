import 'package:flutter_test/flutter_test.dart';

import '../../../tool/backtest/backtest_day.dart';
import '../../../tool/backtest/backtest_outcome.dart';
import '../../../tool/backtest/backtest_summary.dart';

DateTime _day(int day) => DateTime.utc(2026, 10, day);

void main() {
  test('averages exact errors, and bounds with them for the lower bound', () {
    final summary = BacktestSummary.of([
      // Too late by 2, actual inside the range.
      BacktestDay(
        day: _day(1),
        outcome: BacktestOutcome.exact,
        forecast: _day(12),
        earliest: _day(9),
        latest: _day(14),
        actual: _day(10),
        errorDays: 2,
      ),
      // Too early by 4, actual after the range.
      BacktestDay(
        day: _day(2),
        outcome: BacktestOutcome.exact,
        forecast: _day(10),
        earliest: _day(8),
        latest: _day(11),
        actual: _day(14),
        errorDays: -4,
      ),
      BacktestDay(
        day: _day(3),
        outcome: BacktestOutcome.atLeast,
        forecast: _day(20),
        errorDays: 6,
      ),
      BacktestDay(day: _day(4), outcome: BacktestOutcome.censored),
      BacktestDay(day: _day(5), outcome: BacktestOutcome.alreadyOut),
    ]);

    expect(summary.days, 5);
    expect(summary.count(BacktestOutcome.exact), 2);
    expect(summary.count(BacktestOutcome.atLeast), 1);
    expect(summary.count(BacktestOutcome.noForecast), 0);
    expect(summary.meanAbsError, 3);
    expect(summary.meanAbsErrorAtLeast, 4);
    expect(summary.bias, -1);
    expect(summary.inRange, 0.5);
  });

  test('nothing scored gives no numbers', () {
    final summary = BacktestSummary.of([
      BacktestDay(day: _day(1), outcome: BacktestOutcome.censored),
    ]);
    expect(summary.meanAbsError, isNull);
    expect(summary.meanAbsErrorAtLeast, isNull);
    expect(summary.bias, isNull);
    expect(summary.inRange, isNull);
    expect(summary.toString(), contains('mean abs. error:       - days'));
  });

  test('a range past the horizon holds when the money really lasted', () {
    BacktestDay lasted({DateTime? latest}) => BacktestDay(
      day: _day(1),
      outcome: BacktestOutcome.exact,
      earliest: _day(20),
      latest: latest,
      errorDays: 0,
    );
    expect(lasted().inRange, isTrue);
    expect(lasted(latest: _day(25)).inRange, isFalse);
  });
}
