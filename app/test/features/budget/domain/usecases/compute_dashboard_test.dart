import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/compute_dashboard.dart';
import 'package:mizan/features/budget/domain/value_objects/dashboard.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

const _compute = ComputeDashboard();
final _today = DateTime.utc(2026, 10, 6, 9);

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Expense _expense(
  String id,
  String categoryId,
  int dinars, {
  int month = 10,
  int day = 3,
}) => Expense(
  id: id,
  amount: _dt(dinars),
  categoryId: categoryId,
  date: DateTime.utc(2026, month, day),
);

IncomeSource _monthly(String id, String name, int dinars, int day) =>
    IncomeSource(
      id: id,
      name: name,
      amount: _dt(dinars),
      schedule: IncomeSchedule.monthly(dayOfMonth: day),
    );

Dashboard _dashboard({
  List<Expense> expenses = const [],
  List<Category>? categories,
  List<Budget> budgets = const [],
  List<IncomeSource> incomes = const [],
  DateTime? today,
}) => _compute(
  today: today ?? _today,
  currency: Currency.tnd,
  budgets: budgets,
  categories: categories ?? DefaultCategories.all,
  incomes: incomes,
  expenses: expenses,
);

/// Random expenses over September and October, in known and unknown
/// categories.
extension _DashboardAnys on Any {
  Generator<List<Expense>> get dashboardExpenses =>
      combine2(intInRange(0, 40), intInRange(0, 1 << 32), (int n, int seed) {
        final random = Random(seed);
        final ids = [for (final c in DefaultCategories.all) c.id, 'x', 'y'];
        return [
          for (var i = 0; i < n; i++)
            Expense(
              id: 'e${random.nextInt(1000)}-$i',
              // Small amounts, so ties in spending happen.
              amount: Money(1 + random.nextInt(5) * 1000, Currency.tnd),
              categoryId: ids[random.nextInt(ids.length)],
              date: DateTime.utc(2026, 9 + random.nextInt(2), 1 + i % 6),
            ),
        ];
      });
}

void main() {
  group('money left', () {
    test('this month: income minus spending', () {
      final dashboard = _dashboard(
        expenses: [
          _expense('e1', 'food', 120),
          _expense('e2', 'rent', 300),
          _expense('e0', 'food', 999, month: 9),
        ],
        incomes: [_monthly('s1', 'Grant', 450, 15)],
      );

      expect(dashboard.available.income, _dt(450));
      expect(dashboard.available.spent, _dt(420));
      expect(dashboard.available.available, _dt(30));
    });

    test('the overall budget in force, and whether it is over', () {
      final dashboard = _dashboard(
        expenses: [_expense('e1', 'food', 650)],
        budgets: [
          Budget(
            id: Budget.idFor(const YearMonth(2026, 9)),
            month: const YearMonth(2026, 9),
            totalLimit: _dt(600),
          ),
        ],
      );

      expect(dashboard.overview.month, const YearMonth(2026, 10));
      expect(dashboard.overview.totalLeft, _dt(-50));
      expect(dashboard.overview.isOver, isTrue);
    });
  });

  group('days to the next income', () {
    test('counts calendar days from today', () {
      final dashboard = _dashboard(incomes: [_monthly('s1', 'Grant', 450, 15)]);

      expect(dashboard.available.next?.source.name, 'Grant');
      expect(dashboard.daysToNextIncome, 9);
    });

    test('0 on payday, whatever the time', () {
      final dashboard = _dashboard(
        incomes: [_monthly('s1', 'Grant', 450, 6)],
        today: DateTime.utc(2026, 10, 6, 23, 59),
      );

      expect(dashboard.daysToNextIncome, 0);
    });

    test('into next month once this month has paid', () {
      final dashboard = _dashboard(incomes: [_monthly('s1', 'Grant', 450, 1)]);

      expect(dashboard.daysToNextIncome, 26); // Oct 6 -> Nov 1
    });

    test('null with nothing scheduled', () {
      expect(_dashboard().daysToNextIncome, isNull);
      expect(
        _dashboard(
          incomes: [
            IncomeSource(
              id: 's1',
              name: 'Tutoring',
              amount: _dt(100),
              schedule: const IncomeSchedule.irregular(),
            ),
          ],
        ).daysToNextIncome,
        isNull,
      );
    });
  });

  group('top categories', () {
    test('most spent first, the rest summed', () {
      final dashboard = _dashboard(
        expenses: [
          _expense('e1', 'food', 50),
          _expense('e2', 'food', 70),
          _expense('e3', 'rent', 300),
          _expense('e4', 'transport', 12),
          _expense('e5', 'study', 40),
          _expense('e6', 'leisure', 8),
          _expense('e7', 'other', 5),
          _expense('e0', 'other', 999, month: 9),
        ],
      );

      expect(dashboard.topCategories.map((l) => (l.category?.id, l.spent)), [
        ('rent', _dt(300)),
        ('food', _dt(120)),
        ('study', _dt(40)),
        ('transport', _dt(12)),
      ]);
      expect(dashboard.otherSpent, _dt(13));
    });

    test('skips categories with nothing spent', () {
      final dashboard = _dashboard(expenses: [_expense('e1', 'food', 10)]);

      expect(dashboard.topCategories.map((l) => l.category?.id), ['food']);
      expect(dashboard.otherSpent, _dt(0));
    });

    test('ties go by name; unknown categories rank last', () {
      final dashboard = _dashboard(
        expenses: [
          _expense('e1', 'x', 10),
          _expense('e2', 'transport', 10),
          _expense('e3', 'food', 10),
        ],
      );

      expect(dashboard.topCategories.map((l) => l.category?.name), [
        'Food',
        'Transport',
        null,
      ]);
    });

    test('keeps each category limit, to flag one that is over', () {
      final dashboard = _dashboard(
        expenses: [_expense('e1', 'food', 200)],
        categories: [DefaultCategories.food.copyWith(monthlyLimit: _dt(150))],
      );

      expect(dashboard.topCategories.single.isOver, isTrue);
    });
  });

  group('recent expenses', () {
    test('newest first, at most five, reaching into last month', () {
      final dashboard = _dashboard(
        expenses: [
          _expense('a', 'food', 1, day: 2),
          _expense('b', 'food', 1, day: 5),
          _expense('c', 'food', 1, day: 5),
          _expense('d', 'food', 1, month: 9, day: 30),
          _expense('e', 'food', 1, month: 9, day: 20),
          _expense('f', 'food', 1, month: 9, day: 10),
        ],
      );

      // Same day: the later id (UUIDv7: created later) first.
      expect(dashboard.recent.map((e) => e.id), ['c', 'b', 'a', 'd', 'e']);
    });

    test('empty with no expenses', () {
      final dashboard = _dashboard();

      expect(dashboard.recent, isEmpty);
      expect(dashboard.isEmptyMonth, isTrue);
      expect(dashboard.topCategories, isEmpty);
    });

    test('a month with nothing spent yet still shows last month', () {
      final dashboard = _dashboard(
        expenses: [_expense('d', 'food', 5, month: 9, day: 30)],
      );

      expect(dashboard.isEmptyMonth, isTrue);
      expect(dashboard.recent.map((e) => e.id), ['d']);
    });
  });

  group('sharePercent', () {
    test('rounds to the nearest whole percent of the month', () {
      final dashboard = _dashboard(
        expenses: [_expense('e1', 'food', 2), _expense('e2', 'rent', 1)],
      );

      expect(dashboard.sharePercent(_dt(2)), 67);
      expect(dashboard.sharePercent(_dt(1)), 33);
    });

    test('0 when nothing was spent', () {
      expect(_dashboard().sharePercent(_dt(0)), 0);
    });
  });

  Glados(any.dashboardExpenses).test(
    'top categories and the rest add up to the month, most spent first',
    (expenses) {
      final dashboard = _dashboard(expenses: expenses);
      final october = expenses.where((e) => e.date.month == 10);

      final top = dashboard.topCategories;
      expect(top.length, lessThanOrEqualTo(ComputeDashboard.topCount));
      expect(
        Money.sum([
          ...top.map((l) => l.spent),
          dashboard.otherSpent,
        ], Currency.tnd),
        Money.sum(october.map((e) => e.amount), Currency.tnd),
      );
      for (var i = 1; i < top.length; i++) {
        expect(top[i - 1].spent >= top[i].spent, isTrue);
      }
      expect(top.every((l) => l.spent.isPositive), isTrue);
      // Every folded category spent no more than the smallest slice.
      if (top.length == ComputeDashboard.topCount) {
        final ranked = dashboard.overview.categories.where(
          (l) => l.spent.isPositive && !top.contains(l),
        );
        expect(ranked.every((l) => l.spent <= top.last.spent), isTrue);
      } else {
        expect(dashboard.otherSpent.isZero, isTrue);
      }
    },
  );

  Glados(any.dashboardExpenses).test(
    'recent: the newest expenses, newest first, whatever the input order',
    (expenses) {
      final dashboard = _dashboard(expenses: expenses);
      final reversed = _dashboard(expenses: expenses.reversed.toList());

      expect(dashboard.recent, reversed.recent);
      expect(
        dashboard.recent.length,
        expenses.length < ComputeDashboard.recentCount
            ? expenses.length
            : ComputeDashboard.recentCount,
      );
      final shown = dashboard.recent.toSet();
      final oldestShown = dashboard.recent.isEmpty
          ? null
          : dashboard.recent.last.date;
      for (final e in expenses.where((e) => !shown.contains(e))) {
        expect(e.date.isAfter(oldestShown!), isFalse);
      }
      for (var i = 1; i < dashboard.recent.length; i++) {
        expect(
          dashboard.recent[i - 1].date.isBefore(dashboard.recent[i].date),
          isFalse,
        );
      }
    },
  );
}
