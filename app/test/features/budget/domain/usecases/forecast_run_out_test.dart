import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/forecast_run_out.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/recurring_cost.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/budget/domain/value_objects/spend_rate.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

/// A Wednesday. 60 days on is 6 December.
final _today = DateTime.utc(2026, 10, 7);
const _forecast = ForecastRunOut();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

DateTime _day(int month, int day) => DateTime.utc(2026, month, day);

DateTime _daysAgo(int days) => _today.subtract(Duration(days: days));

Expense _expense(Money amount, DateTime date, {String category = 'food'}) =>
    Expense(
      id: 'e-${date.toIso8601String()}-${amount.minorUnits}-$category',
      amount: amount,
      categoryId: category,
      date: date,
    );

/// [perDay] spent on each of the [days] days before today.
List<Expense> _daily(Money Function(DateTime day) perDay, {int days = 28}) => [
  for (var age = 1; age <= days; age++)
    if (perDay(_daysAgo(age)) case final amount when amount.isPositive)
      _expense(amount, _daysAgo(age)),
];

/// Synthetic history: 10 DT every day for four weeks.
final _steady = _daily((_) => _dt(10));

IncomeSource _income(String name, int dinars, IncomeSchedule schedule) =>
    IncomeSource(id: name, name: name, amount: _dt(dinars), schedule: schedule);

ProjectedForecast _projected(RunOutForecast forecast) =>
    forecast as ProjectedForecast;

void main() {
  group('steady history', () {
    test('runs out the first day the balance goes below 0', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: const [],
          expenses: _steady,
        ),
      );
      // 300 / 10 a day: 0 after day 30, below 0 on day 31.
      expect(f.runOut, _day(11, 7));
      expect(f.earliest, f.runOut);
      expect(f.latest, f.runOut);
      expect(f.rate, SpendRate.flat(_dt(10)));
      expect(f.coldStart, isFalse);
      expect(f.start, _dt(300));
      expect(f.horizonEnd, _day(12, 6));
    });

    test('lasting past the 60-day horizon gives no date', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(1000),
          incomes: const [],
          expenses: _steady,
        ),
      );
      expect(f.runOut, isNull);
      expect(f.latest, isNull);
    });

    test('already below 0 runs out today', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(-5),
          incomes: const [],
          expenses: _steady,
        ),
      );
      expect(f.runOut, _today);
      expect(f.earliest, _today);
      expect(f.latest, _today);
    });

    test('exactly 0 is not run out yet', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: Money.zero(Currency.tnd),
          incomes: const [],
          expenses: const [],
          monthlyBudget: Money.zero(Currency.tnd),
        ),
      );
      expect(f.runOut, isNull);
    });
  });

  test('weekend-heavy history runs out sooner than its weekly average '
      'suggests', () {
    final f = _projected(
      _forecast(
        today: _today,
        available: _dt(300),
        incomes: const [],
        expenses: _daily((d) => SpendRate.isWeekend(d) ? _dt(40) : _dt(5)),
      ),
    );
    expect(f.rate, SpendRate(weekday: _dt(5), weekend: _dt(40)));
    // Thu 8 – Sun 11: 300 → 210; to Sun 18: 105; to Sun 25: exactly 0;
    // Mon 26 goes below. A flat 15 a day (the same week) would go below on
    // the 28th.
    expect(f.runOut, _day(10, 26));
  });

  group('income', () {
    test('irregular income arrives on the 1st of each later month', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: [_income('Family', 200, const IncomeSchedule.irregular())],
          expenses: _steady,
        ),
      );
      // 8–31 Oct: 300 → 60. 1 Nov: +200 − 10 → 250, below 0 on 27 Nov.
      expect(f.runOut, _day(11, 27));
    });

    test('monthly income arrives on its payday in later months, and '
        "this month's income isn't added twice", () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: [
            _income('Grant', 100, const IncomeSchedule.monthly(dayOfMonth: 5)),
            // Already in this month's money left.
            _income('Gift', 500, IncomeSchedule.oneOff(date: _day(10, 20))),
          ],
          expenses: _steady,
        ),
      );
      // 31 Oct: 60. 4 Nov: 20. 5 Nov: +100 − 10 → 110, below 0 on 17 Nov.
      expect(f.runOut, _day(11, 17));
    });

    test('a one-off in a later month arrives on its date', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: [
            _income('Prize', 50, IncomeSchedule.oneOff(date: _day(11, 3))),
          ],
          expenses: _steady,
        ),
      );
      // 2 Nov: 40. 3 Nov: +50 − 10 → 80, below 0 on 12 Nov.
      expect(f.runOut, _day(11, 12));
    });
  });

  test('irregular history gives a range around the expected date', () {
    // One big shop each Sunday, growing: 20, 60, 100, 140.
    final sundays = {3: 140, 10: 100, 17: 60, 24: 20};
    final f = _projected(
      _forecast(
        today: _today,
        available: _dt(200),
        incomes: const [],
        expenses: [
          for (final MapEntry(key: age, value: dinars) in sundays.entries)
            _expense(_dt(dinars), _daysAgo(age)),
          _expense(_dt(1), _daysAgo(28)),
        ],
      ),
    );
    expect(f.runOut, isNotNull);
    expect(f.earliest!.isBefore(f.runOut!), isTrue);
    expect(f.latest!.isAfter(f.runOut!), isTrue);
  });

  group('cold start', () {
    test('under 14 days of history uses the budget, with no range', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: const [],
          expenses: [_expense(_dt(80), _day(10, 1))],
          // October has 31 days: 10 a day.
          monthlyBudget: _dt(310),
        ),
      );
      expect(f.coldStart, isTrue);
      expect(f.rate, SpendRate.flat(_dt(10)));
      expect(f.runOut, _day(11, 7));
      expect(f.earliest, f.runOut);
      expect(f.latest, f.runOut);
    });

    test('no history at all is a cold start too', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: const [],
          expenses: const [],
          monthlyBudget: _dt(310),
        ),
      );
      expect(f.coldStart, isTrue);
    });

    test('without a budget there is no forecast yet', () {
      final f = _forecast(
        today: _today,
        available: _dt(300),
        incomes: const [],
        expenses: [_expense(_dt(80), _day(10, 1))],
      );
      expect(f, const RunOutForecast.needsData(daysOfData: 6));
    });

    test('14 days of history is enough', () {
      final f = _projected(
        _forecast(
          today: _today,
          available: _dt(300),
          incomes: const [],
          expenses: _daily((_) => _dt(10), days: 14),
        ),
      );
      expect(f.coldStart, isFalse);
    });
  });

  test('money owed to me is added to the start when asked for', () {
    final f = _projected(
      _forecast(
        today: _today,
        available: _dt(300),
        incomes: const [],
        expenses: _steady,
        owedToMe: _dt(100),
      ),
    );
    expect(f.start, _dt(400));
    expect(f.runOut, _day(11, 17));
  });

  test('a recurring cost is subtracted on its day, and its category is '
      'left out of daily spending', () {
    final f = _projected(
      _forecast(
        today: _today,
        available: _dt(800),
        incomes: const [],
        expenses: [
          ..._steady,
          _expense(_dt(400), _day(10, 1), category: 'rent'),
        ],
        recurring: [
          RecurringCost(
            name: 'Rent',
            amount: _dt(400),
            dayOfMonth: 1,
            categoryId: 'rent',
          ),
        ],
      ),
    );
    expect(f.rate, SpendRate.flat(_dt(10)));
    // 31 Oct: 560. 1 Nov: −400 − 10 → 150, below 0 on 17 Nov.
    expect(f.runOut, _day(11, 17));
  });

  group('runOutDay', () {
    test('spends what spendOn says each day, with later income', () {
      final day = ForecastRunOut.runOutDay(
        today: _day(10, 30),
        start: _dt(20),
        // 31 Oct: 20 → 0. 1 Nov: +50 income − 30 → 20. 2 Nov: −30.
        spendOn: (day) => day == _day(10, 31) ? _dt(20) : _dt(30),
        until: _day(12, 31),
        incomes: [
          _income('Grant', 50, const IncomeSchedule.monthly(dayOfMonth: 1)),
        ],
      );
      expect(day, _day(11, 2));
    });

    test('stops at until, which is included', () {
      DateTime? runOut(DateTime until) => ForecastRunOut.runOutDay(
        today: _today,
        start: _dt(25),
        spendOn: (_) => _dt(10),
        until: until,
      );
      expect(runOut(_day(10, 9)), isNull);
      expect(runOut(_day(10, 10)), _day(10, 10));
    });
  });

  group('properties', () {
    Glados2(any.forecastHistory, any.intInRange(0, 3000000)).test(
      'earliest ≤ expected ≤ latest',
      (history, start) {
        final f = _projected(
          _forecast(
            today: _today,
            available: Money(start, Currency.tnd),
            incomes: const [],
            expenses: history,
          ),
        );
        expect(_order(f.earliest, f.runOut), lessThanOrEqualTo(0));
        expect(_order(f.runOut, f.latest), lessThanOrEqualTo(0));
      },
    );

    Glados3(
      any.forecastHistory,
      any.intInRange(-100000, 3000000),
      any.intInRange(0, 1000000),
    ).test('more money never runs out sooner', (history, start, extra) {
      DateTime? runOut(int money) => _projected(
        _forecast(
          today: _today,
          available: Money(money, Currency.tnd),
          incomes: [
            _income('Grant', 150, const IncomeSchedule.monthly(dayOfMonth: 25)),
          ],
          expenses: history,
        ),
      ).runOut;
      expect(
        _order(runOut(start), runOut(start + extra)),
        lessThanOrEqualTo(0),
      );
    });
  });
}

/// Compares run-out dates, with null (past the horizon) last.
int _order(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
  return a.compareTo(b);
}

extension ForecastAnys on Any {
  /// 14-45 days of history before [_today] (never a cold start), each day
  /// 0-200 DT, in minor units.
  Generator<List<Expense>> get forecastHistory => combine2(
    intInRange(14, 46),
    intInRange(0, 1 << 32),
    (int days, int seed) {
      final random = Random(seed);
      return [
        for (var age = 1; age <= days; age++)
          if (random.nextInt(3) > 0 || age == days)
            _expense(
              Money(1 + random.nextInt(200000), Currency.tnd),
              _daysAgo(age),
            ),
      ];
    },
  );
}
