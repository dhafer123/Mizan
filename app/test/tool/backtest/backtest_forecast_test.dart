import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/forecast_run_out.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import '../../../tool/backtest/backtest_day.dart';
import '../../../tool/backtest/backtest_forecast.dart';
import '../../../tool/backtest/backtest_outcome.dart';
import '../../../tool/backtest/backtest_summary.dart';

const _backtest = BacktestForecast();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

DateTime _day(int month, int day) => DateTime.utc(2026, month, day);

/// [perDay] spent on every day from [from] to [to], both included.
List<Expense> _daily(
  DateTime from,
  DateTime to,
  int Function(DateTime) perDay,
) => [
  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1)))
    if (perDay(d) > 0)
      Expense(
        id: 'e-${d.toIso8601String()}',
        amount: _dt(perDay(d)),
        categoryId: 'food',
        date: d,
      ),
];

List<IncomeSource> _monthly(int dinars) => [
  IncomeSource(
    id: 'grant',
    name: 'Grant',
    amount: _dt(dinars),
    schedule: const IncomeSchedule.monthly(dayOfMonth: 1),
  ),
];

BacktestDay _on(List<BacktestDay> days, DateTime day) =>
    days.singleWhere((d) => d.day == day);

int _count(List<BacktestDay> days, BacktestOutcome outcome) =>
    days.where((d) => d.outcome == outcome).length;

void main() {
  test('steady spending is forecast exactly once the rate is learned', () {
    // 300 a month, 15 a day: below 0 on the 21st of each month.
    final days = _backtest(
      expenses: _daily(_day(9, 1), _day(10, 31), (_) => 15),
      incomes: _monthly(300),
      currency: Currency.tnd,
      end: _day(10, 31),
    );

    // 1 Sep to 30 Oct: the last day has nothing after it to compare with.
    expect(days, hasLength(60));
    expect(days.first.day, _day(9, 1));
    expect(days.last.day, _day(10, 30));
    // Under 14 days of history and no budget: 1-14 Sep.
    expect(_count(days, BacktestOutcome.noForecast), 14);
    // 21-30 Sep and 21-30 Oct.
    expect(_count(days, BacktestOutcome.alreadyOut), 20);
    expect(_count(days, BacktestOutcome.exact), 26);
    expect(_on(days, _day(9, 15)).forecast, _day(9, 21));
    expect(_on(days, _day(9, 15)).actual, _day(9, 21));
    expect(_on(days, _day(10, 1)).actual, _day(10, 21));

    final summary = BacktestSummary.of(days);
    expect(summary.meanAbsError, 0);
    expect(summary.bias, 0);
    expect(summary.inRange, 1);
  });

  test('a budget gives cold-start forecasts before the rate is learned', () {
    final days = _backtest(
      expenses: _daily(_day(9, 1), _day(10, 31), (_) => 15),
      incomes: _monthly(300),
      currency: Currency.tnd,
      end: _day(10, 31),
      monthlyBudget: _dt(300),
    );

    final first = _on(days, _day(9, 1));
    expect(first.coldStart, isTrue);
    // 285 left at 10 a day (300 over 30 days): below 0 on 30 Sep. Really
    // 15 a day: the 21st.
    expect(first.outcome, BacktestOutcome.exact);
    expect(first.forecast, _day(9, 30));
    expect(first.actual, _day(9, 21));
    expect(first.errorDays, 9);
    expect(_on(days, _day(9, 15)).coldStart, isFalse);
    expect(_count(days, BacktestOutcome.noForecast), 0);
  });

  test('each day sees only the spending up to that day', () {
    // 10 a day in September, then 30 a day from 1 October.
    final expenses = _daily(
      _day(9, 1),
      _day(10, 31),
      (d) => d.month == 9 ? 10 : 30,
    );
    final days = _backtest(
      expenses: expenses,
      incomes: _monthly(400),
      currency: Currency.tnd,
      end: _day(10, 31),
    );

    final oct1 = _on(days, _day(10, 1));
    final blind =
        const ForecastRunOut()(
              today: _day(10, 1),
              available: _dt(370),
              incomes: _monthly(400),
              expenses: [
                for (final e in expenses)
                  if (!e.date.isAfter(_day(10, 1))) e,
              ],
            )
            as ProjectedForecast;
    expect(oct1.forecast, blind.runOut);
    // At 10 a day, 370 + November's 400 lasts past the horizon (1 Dec).
    // Really 30 a day: below 0 on 14 Oct.
    expect(oct1.forecast, isNull);
    expect(oct1.actual, _day(10, 14));
    expect(oct1.outcome, BacktestOutcome.atLeast);
    expect(oct1.errorDays, 48);

    // Still catching up with the faster spending: a little too late.
    final oct10 = _on(days, _day(10, 10));
    expect(oct10.outcome, BacktestOutcome.exact);
    expect(oct10.errorDays, greaterThan(0));
  });

  test('a forecast run-out that never came is a lower bound', () {
    // 30 a day for two weeks, then nothing.
    final days = _backtest(
      expenses: _daily(_day(9, 1), _day(9, 14), (_) => 30),
      incomes: _monthly(600),
      currency: Currency.tnd,
      end: _day(9, 30),
    );

    // 15 Sep: 180 left at 30 a day is below 0 on the 22nd. No run-out by
    // 30 Sep, so it is at least 9 days too early.
    final sep15 = _on(days, _day(9, 15));
    expect(sep15.forecast, _day(9, 22));
    expect(sep15.actual, isNull);
    expect(sep15.outcome, BacktestOutcome.atLeast);
    expect(sep15.errorDays, -9);
  });

  test('money that lasts past the data is censored', () {
    final days = _backtest(
      expenses: _daily(_day(9, 1), _day(9, 30), (_) => 10),
      incomes: _monthly(1000),
      currency: Currency.tnd,
      end: _day(9, 30),
    );

    expect(_count(days, BacktestOutcome.noForecast), 14);
    expect(_count(days, BacktestOutcome.censored), 15);
    expect(BacktestSummary.of(days).meanAbsError, isNull);
  });

  test('money that lasts the whole horizon, as forecast, is exact', () {
    // 2 a day for 90 days on 1000 a month never runs out.
    final days = _backtest(
      expenses: _daily(_day(8, 1), _day(10, 29), (_) => 2),
      incomes: _monthly(1000),
      currency: Currency.tnd,
      end: _day(10, 29),
    );

    // 15 Aug + 60 days = 14 Oct, still inside the data.
    final aug15 = _on(days, _day(8, 15));
    expect(aug15.outcome, BacktestOutcome.exact);
    expect(aug15.forecast, isNull);
    expect(aug15.actual, isNull);
    expect(aug15.errorDays, 0);
    expect(aug15.inRange, isTrue);
  });

  test('no expenses, no days', () {
    expect(
      _backtest(
        expenses: const [],
        incomes: const [],
        currency: Currency.tnd,
        end: _day(10, 1),
      ),
      isEmpty,
    );
  });
}
