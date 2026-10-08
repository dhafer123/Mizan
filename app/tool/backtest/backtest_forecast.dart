import 'package:mizan/core/clock/calendar_day.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/compute_money_available.dart';
import 'package:mizan/features/budget/domain/usecases/forecast_run_out.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import 'backtest_day.dart';
import 'backtest_outcome.dart';

/// Replays a spending history day by day to measure the run-out forecast
/// (ARCHITECTURE.md §7, ADR 0014).
///
/// At the end of each day *d* from the first spending to the day before
/// [call]'s `end`, it forecasts as Home would have that evening, from
/// expenses dated up to *d* only: money left is *d*'s month's income minus
/// its spending so far. The actual run-out is found the same way the
/// forecast projects (`ForecastRunOut.runOutDay`, same income and
/// carry-over), but spending what was really spent each day. So the error
/// is the spending guess alone.
///
/// The actual date is only looked for up to the forecast's horizon and the
/// end of the data. When that cuts it off, the error is a lower bound or
/// unknown (see [BacktestOutcome]).
class BacktestForecast {
  const BacktestForecast({ForecastRunOut forecast = const ForecastRunOut()})
    : _forecast = forecast;

  final ForecastRunOut _forecast;

  List<BacktestDay> call({
    required List<Expense> expenses,
    required List<IncomeSource> incomes,
    required Currency currency,

    /// The last day the data covers (e.g. the day it was exported).
    required DateTime end,

    /// The overall monthly budget, for cold-start forecasts.
    Money? monthlyBudget,
  }) {
    if (expenses.isEmpty) return const [];
    final lastDay = end.calendarDay;
    final spentOn = <DateTime, int>{};
    for (final e in expenses) {
      spentOn[e.date] = (spentOn[e.date] ?? 0) + e.amount.minorUnits;
    }
    final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
    Money actualSpend(DateTime day) => Money(spentOn[day] ?? 0, currency);

    final days = <BacktestDay>[];
    var known = 0;
    for (
      var day = sorted.first.date;
      day.isBefore(lastDay);
      day = day.add(const Duration(days: 1))
    ) {
      while (known < sorted.length && !sorted[known].date.isAfter(day)) {
        known++;
      }
      final history = sorted.sublist(0, known);
      final available = const ComputeMoneyAvailable()(
        month: YearMonth.of(day),
        currency: currency,
        incomes: incomes,
        expenses: history,
        today: day,
      ).available;
      if (available.isNegative) {
        days.add(BacktestDay(day: day, outcome: BacktestOutcome.alreadyOut));
        continue;
      }

      final forecast = _forecast(
        today: day,
        available: available,
        incomes: incomes,
        expenses: history,
        monthlyBudget: monthlyBudget,
      );
      if (forecast is! ProjectedForecast) {
        days.add(BacktestDay(day: day, outcome: BacktestOutcome.noForecast));
        continue;
      }

      final seenUntil = forecast.horizonEnd.isBefore(lastDay)
          ? forecast.horizonEnd
          : lastDay;
      final actual = ForecastRunOut.runOutDay(
        today: day,
        start: forecast.start,
        spendOn: actualSpend,
        until: seenUntil,
        incomes: incomes,
      );
      final (outcome, error) = _score(
        forecast: forecast.runOut,
        actual: actual,
        seenUntil: seenUntil,
        horizonEnd: forecast.horizonEnd,
      );
      days.add(
        BacktestDay(
          day: day,
          outcome: outcome,
          coldStart: forecast.coldStart,
          forecast: forecast.runOut,
          earliest: forecast.earliest,
          latest: forecast.latest,
          actual: actual,
          errorDays: error,
        ),
      );
    }
    return days;
  }

  /// A date past what was seen counts as the day after it: the smallest it
  /// could be.
  static (BacktestOutcome, int?) _score({
    required DateTime? forecast,
    required DateTime? actual,
    required DateTime seenUntil,
    required DateTime horizonEnd,
  }) {
    int days(DateTime from, DateTime to) => to.difference(from).inDays;
    final pastHorizon = horizonEnd.add(const Duration(days: 1));
    final pastSeen = seenUntil.add(const Duration(days: 1));

    if (actual != null) {
      return forecast != null
          ? (BacktestOutcome.exact, days(actual, forecast))
          : (BacktestOutcome.atLeast, days(actual, pastHorizon));
    }
    if (seenUntil == horizonEnd) {
      // Money really lasted the whole horizon.
      return forecast == null
          ? (BacktestOutcome.exact, 0)
          : (BacktestOutcome.atLeast, days(pastHorizon, forecast));
    }
    if (forecast != null && !forecast.isAfter(seenUntil)) {
      return (BacktestOutcome.atLeast, days(pastSeen, forecast));
    }
    return (BacktestOutcome.censored, null);
  }
}
