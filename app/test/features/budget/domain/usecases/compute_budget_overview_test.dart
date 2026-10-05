import 'package:glados/glados.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/usecases/compute_budget_overview.dart';
import 'package:mizan/features/budget/domain/value_objects/category_budget.dart';
import 'package:mizan/features/expenses/domain/entities/category.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

const _october = YearMonth(2026, 10);
const _compute = ComputeBudgetOverview();

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Expense _expense(String id, String categoryId, int dinars, {int day = 6}) =>
    Expense(
      id: id,
      amount: _dt(dinars),
      categoryId: categoryId,
      date: DateTime.utc(2026, 10, day),
    );

Budget _budget(YearMonth month, int? dinars) => Budget(
  id: Budget.idFor(month),
  month: month,
  totalLimit: dinars == null ? null : _dt(dinars),
);

final _categories = [
  DefaultCategories.food.copyWith(monthlyLimit: _dt(150)),
  DefaultCategories.transport,
  DefaultCategories.rent.copyWith(monthlyLimit: _dt(300)),
  DefaultCategories.study,
  DefaultCategories.leisure.copyWith(archived: true),
  DefaultCategories.other,
];

/// Random October expenses over a few categories, some unknown, plus
/// random limits and month budgets.
extension _BudgetAnys on Any {
  Generator<(List<Category>, List<Expense>, List<Budget>)> get budgetCase =>
      combine2(intInRange(0, 30), intInRange(0, 1 << 32), (int n, int seed) {
        final random = Random(seed);
        final ids = ['food', 'transport', 'rent', 'study', 'leisure', 'x'];
        final categories = [
          for (final c in DefaultCategories.all)
            c.copyWith(
              archived: random.nextInt(4) == 0,
              monthlyLimit: random.nextBool()
                  ? Money(1 + random.nextInt(500000), Currency.tnd)
                  : null,
            ),
        ];
        final expenses = [
          for (var i = 0; i < n; i++)
            Expense(
              id: 'e$i',
              amount: Money(1 + random.nextInt(100000), Currency.tnd),
              categoryId: ids[random.nextInt(ids.length)],
              // Mostly October, some September and November.
              date: DateTime.utc(2026, 9 + random.nextInt(3), 1 + i % 28),
            ),
        ];
        final budgets = [
          for (final month in [
            const YearMonth(2026, 8),
            const YearMonth(2026, 10),
            const YearMonth(2026, 12),
          ])
            if (random.nextBool())
              Budget(
                id: Budget.idFor(month),
                month: month,
                totalLimit: random.nextBool()
                    ? Money(1 + random.nextInt(900000), Currency.tnd)
                    : null,
              ),
        ];
        return (categories, expenses, budgets);
      });
}

void main() {
  CategoryBudget line(List<CategoryBudget> lines, String id) =>
      lines.singleWhere((l) => l.category?.id == id);

  test('spending per category against each standing limit', () {
    final overview = _compute(
      month: _october,
      currency: Currency.tnd,
      budgets: [_budget(_october, 600)],
      categories: _categories,
      expenses: [
        _expense('e1', 'food', 40),
        _expense('e2', 'food', 80),
        _expense('e3', 'rent', 330),
        _expense('e4', 'transport', 12),
      ],
    );

    expect(overview.spent, _dt(462));
    expect(overview.totalLimit, _dt(600));
    expect(overview.totalLeft, _dt(138));
    expect(overview.usedPercent, 77);
    expect(overview.isOver, isFalse);

    final food = line(overview.categories, 'food');
    expect(food.spent, _dt(120));
    expect(food.left, _dt(30));
    expect(food.usedPercent, 80);
    expect(food.isOver, isFalse);

    final rent = line(overview.categories, 'rent');
    expect(rent.left, _dt(-30));
    expect(rent.isOver, isTrue);
    expect(rent.usedPercent, 110);

    final transport = line(overview.categories, 'transport');
    expect(transport.spent, _dt(12));
    expect(transport.limit, isNull);
    expect(transport.left, isNull);
    expect(transport.usedPercent, isNull);
  });

  test('lists active categories, even with nothing spent, in order', () {
    final overview = _compute(
      month: _october,
      currency: Currency.tnd,
      budgets: const [],
      categories: _categories,
      expenses: const [],
    );

    expect(overview.categories.map((l) => l.category!.id), [
      'food',
      'transport',
      'rent',
      'study',
      'other',
    ]);
    expect(overview.spent, _dt(0));
    expect(overview.categories.every((l) => l.spent.isZero), isTrue);
    expect(overview.totalLimit, isNull);
    expect(overview.totalLeft, isNull);
    expect(overview.usedPercent, isNull);
  });

  test('archived and unknown categories appear only with spending', () {
    final overview = _compute(
      month: _october,
      currency: Currency.tnd,
      budgets: const [],
      categories: _categories,
      expenses: [
        _expense('e1', 'leisure', 20),
        _expense('e2', 'gone-1', 5),
        _expense('e3', 'gone-2', 7),
      ],
    );

    final lines = overview.categories;
    expect(lines[lines.length - 2].category!.id, 'leisure');
    expect(lines[lines.length - 2].spent, _dt(20));
    expect(lines.last.category, isNull);
    expect(lines.last.spent, _dt(12));
  });

  test('only the month counts', () {
    final overview = _compute(
      month: _october,
      currency: Currency.tnd,
      budgets: const [],
      categories: _categories,
      expenses: [
        _expense('e1', 'food', 10, day: 1),
        _expense('e2', 'food', 20, day: 31),
        Expense(
          id: 'e3',
          amount: _dt(99),
          categoryId: 'food',
          date: DateTime.utc(2026, 9, 30),
        ),
        Expense(
          id: 'e4',
          amount: _dt(99),
          categoryId: 'food',
          date: DateTime.utc(2026, 11),
        ),
      ],
    );

    expect(overview.spent, _dt(30));
  });

  group('the overall limit carries forward', () {
    final budgets = [
      _budget(const YearMonth(2026, 8), 500),
      _budget(const YearMonth(2026, 10), 600),
      _budget(const YearMonth(2026, 12), null),
    ];

    Money? limitIn(YearMonth month) =>
        ComputeBudgetOverview.budgetFor(month, budgets)?.totalLimit;

    test('none before the first budget', () {
      expect(
        ComputeBudgetOverview.budgetFor(const YearMonth(2026, 7), budgets),
        isNull,
      );
    });

    test('a month uses the latest budget set in it or before it', () {
      expect(limitIn(const YearMonth(2026, 8)), _dt(500));
      expect(limitIn(const YearMonth(2026, 9)), _dt(500));
      expect(limitIn(const YearMonth(2026, 10)), _dt(600));
      expect(limitIn(const YearMonth(2026, 11)), _dt(600));
    });

    test('a budget without a limit ends it from its month on', () {
      expect(limitIn(const YearMonth(2026, 12)), isNull);
      expect(limitIn(const YearMonth(2027, 3)), isNull);
    });

    test('the order of the budgets does not matter', () {
      final reversed = budgets.reversed.toList();
      expect(
        ComputeBudgetOverview.budgetFor(const YearMonth(2026, 11), reversed),
        budgets[1],
      );
    });
  });

  Glados(any.budgetCase).test(
    'category spending adds up to the total, and left + spent = limit',
    (input) {
      final (categories, expenses, budgets) = input;
      final overview = _compute(
        month: _october,
        currency: Currency.tnd,
        budgets: budgets,
        categories: categories,
        expenses: expenses,
      );

      final october = expenses.where((e) => _october.contains(e.date));
      expect(
        overview.spent,
        Money.sum(october.map((e) => e.amount), Currency.tnd),
      );
      expect(
        Money.sum(overview.categories.map((l) => l.spent), Currency.tnd),
        overview.spent,
      );
      for (final l in overview.categories) {
        if (l.limit case final limit?) {
          expect(l.left! + l.spent, limit);
        }
      }
      if (overview.totalLimit case final limit?) {
        expect(overview.totalLeft! + overview.spent, limit);
      }
      // Every active category has exactly one line.
      for (final c in categories.where((c) => !c.archived)) {
        expect(
          overview.categories.where((l) => l.category?.id == c.id),
          hasLength(1),
        );
      }
    },
  );
}
