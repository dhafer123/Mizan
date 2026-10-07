import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/groups_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/forecast_run_out.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/domain/value_objects/recurring_cost.dart';
import 'package:mizan/features/budget/domain/value_objects/run_out_forecast.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/groups/domain/value_objects/group_share.dart';
import 'package:mizan/features/groups/domain/value_objects/my_group_money.dart';
import 'package:mizan/features/groups/presentation/shared/group_data_providers.dart'
    show myGroupMoneyProvider;

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_budget_repository.dart';
import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_group_repository.dart';
import '../../../../support/fake_income_source_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Expense _expense(
  String id,
  String categoryId,
  int dinars, {
  int month = 10,
  required int day,
  String? note,
}) => Expense(
  id: id,
  amount: _dt(dinars),
  categoryId: categoryId,
  date: DateTime.utc(2026, month, day),
  note: note,
);

IncomeSource _grant(int dinars) => IncomeSource(
  id: 's1',
  name: 'Grant',
  amount: _dt(dinars),
  schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
);

Budget _budget(int month, int dinars) => Budget(
  id: Budget.idFor(YearMonth(2026, month)),
  month: YearMonth(2026, month),
  totalLimit: _dt(dinars),
);

/// October 2026 spending: 515 DT over six categories, and 999 DT in
/// September that doesn't count.
List<Expense> _october() => [
  _expense('e1', 'food', 120, day: 6, note: 'Groceries'),
  _expense('e2', 'rent', 330, day: 5),
  _expense('e3', 'transport', 12, day: 3),
  _expense('e4', 'study', 40, day: 2),
  _expense('e5', 'leisure', 8, day: 1),
  _expense('e6', 'other', 5, day: 1),
  _expense('e0', 'food', 999, month: 9, day: 20),
];

class _Repos {
  _Repos({
    List<Expense> expenses = const [],
    List<IncomeSource> incomes = const [],
    List<Budget> budgets = const [],
    Money? rentLimit,
  }) : expenses = FakeExpenseRepository(expenses),
       incomes = FakeIncomeSourceRepository(incomes),
       budgets = FakeBudgetRepository(budgets),
       categories = FakeCategoryRepository([
         DefaultCategories.food.copyWith(monthlyLimit: _dt(150)),
         DefaultCategories.transport,
         DefaultCategories.rent.copyWith(monthlyLimit: rentLimit),
         ...DefaultCategories.all.skip(3),
       ]);

  final FakeExpenseRepository expenses;
  final FakeIncomeSourceRepository incomes;
  final FakeBudgetRepository budgets;
  final FakeCategoryRepository categories;
}

Future<void> _pump(
  WidgetTester tester,
  _Repos repos, {
  MyGroupMoney? groups,
  ForecastRunOut? forecast,
}) async {
  // Tall enough to show every card without scrolling.
  tester.view
    ..physicalSize = const Size(1200, 2600)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 10, 6, 9)),
        ),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        expenseRepositoryProvider.overrideWithValue(repos.expenses),
        categoryRepositoryProvider.overrideWithValue(repos.categories),
        budgetRepositoryProvider.overrideWithValue(repos.budgets),
        incomeSourceRepositoryProvider.overrideWithValue(repos.incomes),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        if (groups != null)
          myGroupMoneyProvider.overrideWith((ref) => Stream.value(groups)),
        if (forecast != null)
          forecastRunOutProvider.overrideWithValue(forecast),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
}

String _moneyLeft(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('moneyLeft'))).data!;

Finder _inCard(String card, Finder matching) => find.descendant(
  of: find.ancestor(of: find.text(card), matching: find.byType(Card)),
  matching: matching,
);

void main() {
  testWidgets('loading, then the dashboard', (tester) async {
    await _pump(tester, _Repos());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Money left this month'), findsOneWidget);
    expect(find.text('Top categories'), findsOneWidget);
    expect(find.text('Recent expenses'), findsOneWidget);
  });

  group('a normal month', () {
    Future<void> pumpNormal(WidgetTester tester) async {
      await _pump(
        tester,
        _Repos(
          expenses: _october(),
          incomes: [_grant(600)],
          budgets: [_budget(9, 600)],
          rentLimit: _dt(400),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('money left, the budget and the next income', (tester) async {
      await pumpNormal(tester);

      expect(_moneyLeft(tester), '85.000 DT'); // 600 - 515
      expect(find.text('600.000 DT income · 515.000 DT spent'), findsOneWidget);
      expect(
        find.text('85.000 DT left of your 600.000 DT budget'),
        findsOneWidget,
      );
      expect(find.text('Next income in 9 days: Grant'), findsOneWidget);
      expect(find.textContaining('Over budget'), findsNothing);
    });

    testWidgets('the top four categories, then the rest', (tester) async {
      await pumpNormal(tester);

      Finder legend(String text) => _inCard('Top categories', find.text(text));
      final names = ['Rent', 'Food', 'Study', 'Transport', 'Other categories'];
      final tops = [
        for (final name in names) tester.getTopLeft(legend(name)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(legend('64%'), findsOneWidget); // 330 of 515
      expect(legend('23%'), findsOneWidget); // 120
      expect(legend('8%'), findsOneWidget); // 40
      expect(legend('2%'), findsOneWidget); // 12
      expect(legend('3%'), findsOneWidget); // 8 + 5, folded
      expect(legend('13.000 DT'), findsOneWidget);
      expect(legend('Leisure'), findsNothing);
      expect(legend('Over its limit'), findsNothing);
    });

    testWidgets('the five newest expenses, newest first', (tester) async {
      await pumpNormal(tester);

      Finder recent(String text) => _inCard('Recent expenses', find.text(text));
      expect(recent('Groceries'), findsOneWidget);
      expect(recent('Food · Today'), findsOneWidget);
      expect(recent('Yesterday'), findsOneWidget);
      expect(recent('Sat, Oct 3'), findsOneWidget);
      expect(recent('Fri, Oct 2'), findsOneWidget);
      expect(recent('Thu, Oct 1'), findsOneWidget); // e6 only
      expect(recent('8.000 DT'), findsNothing); // e5, sixth
      expect(recent('999.000 DT'), findsNothing);
      final groceries = tester.getTopLeft(recent('Groceries')).dy;
      final rent = tester.getTopLeft(recent('Rent')).dy;
      expect(groceries, lessThan(rent));
    });

    testWidgets('tapping a recent expense opens it to edit', (tester) async {
      await pumpNormal(tester);

      await tester.tap(_inCard('Recent expenses', find.text('Groceries')));
      await tester.pumpAndSettle();

      expect(find.text('Edit expense'), findsOneWidget);
    });

    testWidgets('the add button opens a new expense', (tester) async {
      await pumpNormal(tester);

      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);
    });
  });

  group('an empty month', () {
    testWidgets('nothing at all: prompts to add income and expenses', (
      tester,
    ) async {
      await _pump(tester, _Repos());
      await tester.pumpAndSettle();

      expect(_moneyLeft(tester), '0.000 DT');
      expect(
        find.text('Add your income to see what you can spend.'),
        findsOneWidget,
      );
      expect(find.text('Add income'), findsOneWidget);
      expect(find.textContaining('No spending yet this month'), findsOneWidget);
      expect(find.textContaining('No expenses yet'), findsOneWidget);
      expect(
        _inCard('Money left this month', find.textContaining('budget')),
        findsNothing,
      );
    });

    testWidgets('income but no spending: all of it is left', (tester) async {
      await _pump(tester, _Repos(incomes: [_grant(450)]));
      await tester.pumpAndSettle();

      expect(_moneyLeft(tester), '450.000 DT');
      expect(find.text('Next income in 9 days: Grant'), findsOneWidget);
      expect(find.textContaining('No spending yet this month'), findsOneWidget);
    });

    testWidgets("last month's expenses still show as recent", (tester) async {
      await _pump(
        tester,
        _Repos(expenses: [_expense('e0', 'food', 999, month: 9, day: 30)]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No spending yet this month'), findsOneWidget);
      expect(
        _inCard('Recent expenses', find.text('999.000 DT')),
        findsOneWidget,
      );
      expect(find.textContaining('No expenses yet'), findsNothing);
    });

    testWidgets('irregular income only: no date to count down to', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repos(
          incomes: [
            IncomeSource(
              id: 's1',
              name: 'Tutoring',
              amount: _dt(100),
              schedule: const IncomeSchedule.irregular(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No income date scheduled.'), findsOneWidget);
      expect(find.text('Add income'), findsNothing);
    });
  });

  testWidgets('over budget: shown in red, and the category over its limit', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repos(
        expenses: _october(),
        incomes: [_grant(450)],
        budgets: [_budget(9, 600), _budget(10, 400)],
        rentLimit: _dt(300),
      ),
    );
    await tester.pumpAndSettle();

    final error = Theme.of(
      tester.element(find.byType(HomeScreen)),
    ).colorScheme.error;
    expect(_moneyLeft(tester), '-65.000 DT'); // 450 - 515
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('moneyLeft'))).style?.color,
      error,
    );
    expect(find.text('Over budget by 115.000 DT'), findsOneWidget);
    expect(find.textContaining('left of your'), findsNothing);
    final rentRow = find.ancestor(
      of: _inCard('Top categories', find.text('Rent')),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: rentRow.first, matching: find.text('Over its limit')),
      findsOneWidget,
    );
    expect(find.text('Over its limit'), findsOneWidget); // food is under
  });

  testWidgets('a change shows at once', (tester) async {
    final repos = _Repos(incomes: [_grant(450)]);
    await _pump(tester, repos);
    await tester.pumpAndSettle();

    await repos.expenses.add(_expense('n1', 'food', 50, day: 6));
    await tester.pumpAndSettle();

    expect(_moneyLeft(tester), '400.000 DT');
    expect(_inCard('Top categories', find.text('100%')), findsOneWidget);
  });

  testWidgets('a failure shows its message and can be retried', (tester) async {
    final repos = _Repos();
    repos.budgets.watchFailure = const BudgetFailure(BudgetError.storage);
    await _pump(tester, repos);
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    repos.budgets.watchFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Money left this month'), findsOneWidget);
  });

  group('forecast', () {
    /// 10 DT on each of the 28 days before today (6 Oct), 50 of it in
    /// October.
    final steady = [
      for (var age = 1; age <= 28; age++)
        Expense(
          id: 'd$age',
          amount: _dt(10),
          categoryId: 'food',
          date: DateTime.utc(2026, 10, 6).subtract(Duration(days: age)),
        ),
    ];

    String headline(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('forecastHeadline')))
        .data!;

    testWidgets('no history and no budget: asks for more data', (tester) async {
      await _pump(tester, _Repos());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('forecastNeedsData')), findsOneWidget);
      expect(find.textContaining('(14 to go)'), findsOneWidget);
      expect(find.text('Set budget'), findsOneWidget);
    });

    testWidgets('steady spending: the run-out day and what it is based on', (
      tester,
    ) async {
      // 300 - 50 = 250 left: 0 on 31 Oct, below on 1 Nov.
      await _pump(tester, _Repos(expenses: steady, incomes: [_grant(300)]));
      await tester.pumpAndSettle();

      expect(headline(tester), 'Money runs out around Nov 1');
      expect(find.text('Based on spending 10.000 DT a day.'), findsOneWidget);
      // Steady: no range to show.
      expect(find.byKey(const ValueKey('forecastRange')), findsNothing);
    });

    testWidgets('enough money: lasts past the horizon', (tester) async {
      await _pump(tester, _Repos(expenses: steady, incomes: [_grant(600)]));
      await tester.pumpAndSettle();

      expect(headline(tester), 'Your money lasts past Dec 5');
    });

    testWidgets('already below 0: says so', (tester) async {
      await _pump(tester, _Repos(expenses: steady));
      await tester.pumpAndSettle();

      expect(headline(tester), 'Your money for this month has run out');
    });

    testWidgets('cold start: uses the budget and says so', (tester) async {
      await _pump(
        tester,
        _Repos(
          expenses: [_expense('e1', 'food', 20, day: 1)],
          incomes: [_grant(300)],
          budgets: [_budget(10, 310)],
        ),
      );
      await tester.pumpAndSettle();

      // 280 left at 10 a day: 0 on 3 Nov, below on 4 Nov.
      expect(headline(tester), 'Money runs out around Nov 4');
      expect(
        find.text(
          'Based on your monthly budget until you have 14 days of spending.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('money owed to me can be counted', (tester) async {
      await _pump(
        tester,
        _Repos(expenses: steady, incomes: [_grant(300)]),
        groups: MyGroupMoney(
          shares: const <GroupShare>[],
          owedToMe: _dt(100),
          iOwe: Money.zero(Currency.tnd),
        ),
      );
      await tester.pumpAndSettle();
      expect(headline(tester), 'Money runs out around Nov 1');

      await tester.tap(find.byKey(const ValueKey('includeOwed')));
      await tester.pumpAndSettle();

      // 350 instead of 250: ten days later.
      expect(headline(tester), 'Money runs out around Nov 11');
    });

    testWidgets('no switch when nothing is owed', (tester) async {
      await _pump(tester, _Repos(expenses: steady, incomes: [_grant(300)]));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('includeOwed')), findsNothing);
    });

    testWidgets('a failure shows in the card and can be retried', (
      tester,
    ) async {
      final forecast = _FlakyForecast();
      await _pump(
        tester,
        _Repos(expenses: steady, incomes: [_grant(300)]),
        forecast: forecast,
      );
      await tester.pumpAndSettle();

      expect(find.text('Money left this month'), findsOneWidget);
      expect(find.byKey(const ValueKey('forecastHeadline')), findsNothing);
      expect(find.text('Try again'), findsOneWidget);

      forecast.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(headline(tester), 'Money runs out around Nov 1');
    });
  });
}

/// Fails until [fail] is cleared.
class _FlakyForecast extends ForecastRunOut {
  bool fail = true;

  @override
  RunOutForecast call({
    required DateTime today,
    required Money available,
    required List<IncomeSource> incomes,
    required List<Expense> expenses,
    List<GroupShare> shares = const [],
    List<RecurringCost> recurring = const [],
    Money? owedToMe,
    Money? monthlyBudget,
  }) {
    if (fail) throw StateError('forecast failed');
    return super(
      today: today,
      available: available,
      incomes: incomes,
      expenses: expenses,
      shares: shares,
      recurring: recurring,
      owedToMe: owedToMe,
      monthlyBudget: monthlyBudget,
    );
  }
}
