import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/usecases/estimate_daily_spend.dart';
import 'package:mizan/features/budget/domain/value_objects/spend_rate.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/groups/domain/value_objects/group_share.dart';

/// A Wednesday.
final _today = DateTime.utc(2026, 10, 7);
const _estimate = EstimateDailySpend();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

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

void main() {
  test('no spending: zero rates and no days of data', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: const [],
    );
    expect(estimate.daysOfData, 0);
    expect(estimate.expected, SpendRate.flat(Money.zero(Currency.tnd)));
  });

  test('steady spending: every rate is that amount', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: _daily((_) => _dt(10)),
    );
    expect(estimate.expected, SpendRate.flat(_dt(10)));
    expect(estimate.low, SpendRate.flat(_dt(10)));
    expect(estimate.high, SpendRate.flat(_dt(10)));
    expect(estimate.daysOfData, 28);
  });

  test('weekdays and weekends are learned apart', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: _daily((d) => SpendRate.isWeekend(d) ? _dt(40) : _dt(5)),
    );
    expect(estimate.expected, SpendRate(weekday: _dt(5), weekend: _dt(40)));
    // Every 7-day window holds 5 weekdays and 2 weekend days: no spread.
    expect(estimate.low, estimate.expected);
    expect(estimate.high, estimate.expected);
  });

  test('recent days weigh more than older ones', () {
    // Nothing for two weeks, then 20 DT a day: the plain mean is 10.
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: [
        ..._daily((_) => _dt(20), days: 14),
        _expense(const Money(1, Currency.tnd), _daysAgo(28)),
      ],
    );
    expect(estimate.expected.weekday, greaterThan(_dt(10)));
    expect(estimate.expected.weekday, lessThan(_dt(20)));
  });

  test("days before the first spending don't dilute the rate", () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: _daily((_) => _dt(10), days: 15),
    );
    expect(estimate.daysOfData, 15);
    expect(estimate.expected, SpendRate.flat(_dt(10)));
  });

  test("today's and future spending are left out; so is spending over "
      '28 days old', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: [
        ..._daily((_) => _dt(10)),
        _expense(_dt(500), _today),
        _expense(_dt(500), _today.add(const Duration(days: 3))),
        _expense(_dt(500), _daysAgo(29)),
      ],
    );
    expect(estimate.expected, SpendRate.flat(_dt(10)));
    expect(estimate.daysOfData, 29);
  });

  test('my shares of group expenses count as spending', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: _daily((_) => _dt(6)),
      shares: [
        for (var age = 1; age <= 28; age++)
          GroupShare(
            groupId: 'g',
            expenseId: 's$age',
            amount: _dt(4),
            date: _daysAgo(age),
          ),
      ],
    );
    expect(estimate.expected, SpendRate.flat(_dt(10)));
  });

  test('excluded categories are left out of the rates but not the history', () {
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: [
        ..._daily((_) => _dt(10), days: 20),
        _expense(_dt(400), _daysAgo(25), category: 'rent'),
      ],
      excludedCategoryIds: {'rent'},
    );
    expect(estimate.daysOfData, 25);
    expect(estimate.expected.weekday, lessThan(_dt(10)));
    expect(estimate.expected.weekday, greaterThan(_dt(5)));
  });

  test('lumpy spending gives a range around the expected rate', () {
    // One shop each Sunday, growing: 20, 60, 100, 140.
    final sundays = {3: 140, 10: 100, 17: 60, 24: 20};
    final estimate = _estimate(
      today: _today,
      currency: Currency.tnd,
      expenses: [
        for (final MapEntry(key: age, value: dinars) in sundays.entries)
          _expense(_dt(dinars), _daysAgo(age)),
        _expense(const Money(1, Currency.tnd), _daysAgo(28)),
      ],
    );
    expect(estimate.low.weekend, lessThan(estimate.expected.weekend));
    expect(estimate.high.weekend, greaterThan(estimate.expected.weekend));
  });

  group('properties', () {
    Glados(any.history).test('low ≤ expected ≤ high on both kinds of day', (
      history,
    ) {
      final e = _estimate(
        today: _today,
        currency: Currency.tnd,
        expenses: history,
      );
      for (final day in [_today, _today.add(const Duration(days: 3))]) {
        expect(e.low.on(day), lessThanOrEqualTo(e.expected.on(day)));
        expect(e.expected.on(day), lessThanOrEqualTo(e.high.on(day)));
        expect(e.low.on(day).isNegative, isFalse);
      }
    });

    Glados2(any.intInRange(7, 40), any.intInRange(1, 1000000)).test(
      'spending the same every day gives exactly that rate',
      (days, perDay) {
        final amount = Money(perDay, Currency.tnd);
        final e = _estimate(
          today: _today,
          currency: Currency.tnd,
          expenses: _daily((_) => amount, days: days),
        );
        expect(e.expected, SpendRate.flat(amount));
        expect(e.low, e.expected);
        expect(e.high, e.expected);
      },
    );
  });
}

extension HistoryAnys on Any {
  /// 1-45 days of history before [_today], each day 0-200 DT, in minor
  /// units.
  Generator<List<Expense>> get history =>
      combine2(intInRange(1, 46), intInRange(0, 1 << 32), (int days, int seed) {
        final random = Random(seed);
        return [
          for (var age = 1; age <= days; age++)
            if (random.nextInt(3) > 0 || age == days)
              _expense(
                Money(1 + random.nextInt(200000), Currency.tnd),
                _daysAgo(age),
              ),
        ];
      });
}
