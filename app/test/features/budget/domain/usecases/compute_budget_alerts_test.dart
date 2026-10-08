import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/compute_budget_alerts.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_overview.dart';
import 'package:mizan/features/budget/domain/value_objects/category_budget.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/next_income.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/budget/domain/value_objects/spend_rate.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/groups/domain/value_objects/group_share.dart';

final _today = DateTime.utc(2026, 10, 20);
const _october = YearMonth(2026, 10);
const _compute = ComputeBudgetAlerts();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

DateTime _day(int day) => DateTime.utc(2026, 10, day);

Expense _expense(String id, int dinars, int day, {String category = 'food'}) =>
    Expense(id: id, amount: _dt(dinars), categoryId: category, date: _day(day));

BudgetOverview _overview(List<CategoryBudget> lines) => BudgetOverview(
  month: _october,
  spent: Money.sum(lines.map((l) => l.spent), Currency.tnd),
  categories: lines,
);

final _noOverview = _overview(const []);

RunOutForecast _runsOut(DateTime? runOut) => RunOutForecast.projected(
  today: _today,
  horizonEnd: _today.add(const Duration(days: 60)),
  start: _dt(100),
  runOut: runOut,
  earliest: runOut,
  latest: runOut,
  rate: SpendRate.flat(_dt(10)),
  coldStart: false,
);

final _lasts = _runsOut(null);

NextIncome _payday(DateTime date) => NextIncome(
  source: IncomeSource(
    id: 'grant',
    name: 'Grant',
    amount: _dt(300),
    schedule: IncomeSchedule.monthly(dayOfMonth: date.day),
  ),
  date: date,
);

List<BudgetAlert> _alerts({
  BudgetOverview? overview,
  RunOutForecast? forecast,
  NextIncome? next,
  List<Expense> expenses = const [],
  List<GroupShare> shares = const [],
}) => _compute(
  today: _today,
  overview: overview ?? _noOverview,
  forecast: forecast ?? _lasts,
  next: next,
  expenses: expenses,
  shares: shares,
  categories: DefaultCategories.all,
);

/// Food at 10, 12, 14 DT in the weeks before: median 12.
final _usualFood = [
  _expense('u1', 10, 5),
  _expense('u2', 12, 9),
  _expense('u3', 14, 15),
];

void main() {
  test('nothing to warn about: no alerts', () {
    expect(_alerts(), isEmpty);
  });

  group('category limit', () {
    CategoryBudget line(int spent, int? limit) => CategoryBudget(
      category: DefaultCategories.food,
      spent: _dt(spent),
      limit: limit == null ? null : _dt(limit),
    );

    test('fires at 80% of the limit', () {
      expect(_alerts(overview: _overview([line(120, 150)])), [
        BudgetAlert.categoryLimit(
          categoryId: 'food',
          categoryName: 'Food',
          month: _october,
          spent: _dt(120),
          limit: _dt(150),
          usedPercent: 80,
        ),
      ]);
    });

    test('also when over the limit', () {
      final alerts = _alerts(overview: _overview([line(200, 150)]));
      expect((alerts.single as CategoryLimitAlert).usedPercent, 133);
    });

    test('not below 80%, nor without a limit', () {
      expect(_alerts(overview: _overview([line(119, 150)])), isEmpty);
      expect(_alerts(overview: _overview([line(500, null)])), isEmpty);
    });

    test('not for spending in a category this phone doesn\'t know', () {
      final unknown = CategoryBudget(category: null, spent: _dt(500));
      expect(_alerts(overview: _overview([unknown])), isEmpty);
    });
  });

  group('run-out', () {
    test('fires when the forecast runs out before the next income', () {
      final alerts = _alerts(
        forecast: _runsOut(_day(23)),
        next: _payday(_day(25)),
      );
      expect(alerts, [
        BudgetAlert.runOut(runOut: _day(23), next: _payday(_day(25))),
      ]);
    });

    test('not when the money lasts until payday, or past the horizon', () {
      expect(
        _alerts(forecast: _runsOut(_day(25)), next: _payday(_day(25))),
        isEmpty,
      );
      expect(_alerts(forecast: _lasts, next: _payday(_day(25))), isEmpty);
    });

    test('with no income scheduled, any run-out fires', () {
      expect(_alerts(forecast: _runsOut(DateTime.utc(2026, 12, 1))), [
        BudgetAlert.runOut(runOut: DateTime.utc(2026, 12, 1)),
      ]);
    });

    test('not without a forecast', () {
      expect(
        _alerts(forecast: const RunOutForecast.needsData(daysOfData: 3)),
        isEmpty,
      );
    });
  });

  group('unusual spending', () {
    test('fires above 2.5× the median of the 4 weeks before', () {
      final alerts = _alerts(
        expenses: [..._usualFood, _expense('big', 31, 20)],
      );
      expect(alerts, [
        BudgetAlert.unusualSpending(
          expenseId: 'big',
          categoryName: 'Food',
          date: _day(20),
          amount: _dt(31),
          median: _dt(12),
        ),
      ]);
    });

    test('not at exactly 2.5×', () {
      expect(
        _alerts(expenses: [..._usualFood, _expense('big', 30, 20)]),
        isEmpty,
      );
    });

    test('yesterday counts; two days ago is too old', () {
      expect(
        _alerts(expenses: [..._usualFood, _expense('big', 90, 19)]),
        hasLength(1),
      );
      expect(
        _alerts(expenses: [..._usualFood, _expense('big', 90, 18)]),
        isEmpty,
      );
    });

    test('needs 3 earlier expenses in the category', () {
      expect(
        _alerts(expenses: [..._usualFood.take(2), _expense('big', 90, 20)]),
        isEmpty,
      );
    });

    test('only compares with its own category', () {
      expect(
        _alerts(
          expenses: [
            ..._usualFood,
            _expense('rent', 400, 20, category: 'rent'),
          ],
        ),
        isEmpty,
      );
    });

    test('only compares with the 4 weeks before, not the same day', () {
      // Over 4 weeks old, and same-day: neither counts, so too few to judge.
      final alerts = _alerts(
        expenses: [
          _expense('old', 10, 1).copyWith(date: DateTime.utc(2026, 9, 21)),
          _expense('u2', 12, 9),
          _expense('u3', 14, 15),
          _expense('same', 11, 20),
          _expense('big', 90, 20),
        ],
      );
      expect(alerts, isEmpty);
    });

    test('my share of a group expense counts', () {
      final alerts = _alerts(
        expenses: _usualFood,
        shares: [
          GroupShare(
            groupId: 'g',
            expenseId: 'dinner',
            amount: _dt(40),
            categoryId: 'food',
            date: _day(20),
          ),
        ],
      );
      expect((alerts.single as UnusualSpendingAlert).expenseId, 'dinner');
    });

    test('the median of an even count is the mean of the middle two', () {
      final alerts = _alerts(
        expenses: [
          ..._usualFood,
          _expense('u4', 20, 16),
          _expense('big', 40, 20),
        ],
      );
      // 10, 12, 14, 20 → 13; 40 > 32.5.
      expect((alerts.single as UnusualSpendingAlert).median, _dt(13));
    });
  });

  test('all three at once', () {
    final alerts = _alerts(
      overview: _overview([
        CategoryBudget(
          category: DefaultCategories.food,
          spent: _dt(140),
          limit: _dt(150),
        ),
      ]),
      forecast: _runsOut(_day(22)),
      next: _payday(_day(25)),
      expenses: [..._usualFood, _expense('big', 90, 20)],
    );
    expect(alerts.map((a) => a.runtimeType.toString()), [
      'CategoryLimitAlert',
      'RunOutAlert',
      'UnusualSpendingAlert',
    ]);
  });
}
