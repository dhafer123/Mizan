import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/budget/presentation/budget/budget_screen.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import '../../../../support/fake_budget_repository.dart';
import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_income_source_repository.dart';
import '../../../../support/sequential_id_generator.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Expense _expense(String id, String categoryId, int dinars, {int month = 10}) =>
    Expense(
      id: id,
      amount: _dt(dinars),
      categoryId: categoryId,
      date: DateTime.utc(2026, month, 3),
    );

final _grant = IncomeSource(
  id: 's1',
  name: 'Grant',
  amount: _dt(450),
  schedule: const IncomeSchedule.monthly(dayOfMonth: 15),
);

class _Repos {
  final expenses = FakeExpenseRepository([
    _expense('e1', 'food', 120),
    _expense('e2', 'rent', 330),
    _expense('e3', 'transport', 12),
    _expense('e0', 'food', 999, month: 9),
  ]);
  final categories = FakeCategoryRepository([
    DefaultCategories.food.copyWith(monthlyLimit: _dt(150)),
    DefaultCategories.transport,
    DefaultCategories.rent.copyWith(monthlyLimit: _dt(300)),
    ...DefaultCategories.all.skip(3),
  ]);
  final budgets = FakeBudgetRepository([
    Budget(
      id: Budget.idFor(const YearMonth(2026, 9)),
      month: const YearMonth(2026, 9),
      totalLimit: _dt(600),
    ),
  ]);
  final incomes = FakeIncomeSourceRepository([_grant]);
}

Future<_Repos> _pump(WidgetTester tester, {_Repos? repos}) async {
  final r = repos ?? _Repos();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 10, 6, 9)),
        ),
        idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
        expenseRepositoryProvider.overrideWithValue(r.expenses),
        categoryRepositoryProvider.overrideWithValue(r.categories),
        budgetRepositoryProvider.overrideWithValue(r.budgets),
        incomeSourceRepositoryProvider.overrideWithValue(r.incomes),
      ],
      child: const MaterialApp(home: BudgetScreen()),
    ),
  );
  return r;
}

Finder _inTile(String title, String text) => find.descendant(
  of: find.widgetWithText(ListTile, title),
  matching: find.text(text),
);

void main() {
  testWidgets('loading, then the month', (tester) async {
    await _pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Money available'), findsOneWidget);
  });

  testWidgets('money available: income minus spending, and next income', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('available'))).data,
      '-12.000 DT', // 450 - (120 + 330 + 12)
    );
    expect(find.text('450.000 DT'), findsOneWidget);
    expect(
      find.text('Next income: Grant on Thu, Oct 15 (in 9 days)'),
      findsOneWidget,
    );
  });

  testWidgets('the overall budget carries over from September', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('462.000 DT of 600.000 DT'), findsOneWidget);
    expect(find.text('138.000 DT left'), findsOneWidget);
  });

  testWidgets('used and left per category', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(_inTile('Food', '120.000 DT of 150.000 DT'), findsOneWidget);
    expect(_inTile('Food', '30.000 DT left'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Rent'), 100);
    expect(_inTile('Rent', '330.000 DT of 300.000 DT'), findsOneWidget);
    expect(_inTile('Rent', 'Over by 30.000 DT'), findsOneWidget);
    expect(_inTile('Transport', '12.000 DT spent · no limit'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Other'), 100);
    expect(_inTile('Other', '0.000 DT spent · no limit'), findsOneWidget);
  });

  testWidgets('no income: a prompt to add some', (tester) async {
    final repos = _Repos();
    await repos.incomes.delete('s1');
    await _pump(tester, repos: repos);
    await tester.pumpAndSettle();

    expect(
      find.text('Add your income to see what you can spend.'),
      findsOneWidget,
    );
    expect(find.textContaining('Next income'), findsNothing);
  });

  testWidgets('an earlier month: no next income, its own spending', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('Next income'), findsNothing);
    expect(_inTile('Food', '999.000 DT of 150.000 DT'), findsOneWidget);
  });

  group('setting the overall budget', () {
    testWidgets('saves it for this month on', (tester) async {
      final repos = await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        find.text('From October 2026 on, until you change it.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '700');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        repos.budgets.budgets.map((b) => (b.id, b.totalLimit)),
        containsAll([
          ('budget-2026-09', _dt(600)),
          ('budget-2026-10', _dt(700)),
        ]),
      );
      expect(find.text('462.000 DT of 700.000 DT'), findsOneWidget);
    });

    testWidgets('remove it', (tester) async {
      final repos = await _pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove budget'));
      await tester.pumpAndSettle();

      expect(
        repos.budgets.budgets
            .singleWhere((b) => b.id == 'budget-2026-10')
            .totalLimit,
        isNull,
      );
      expect(find.text('462.000 DT spent · no monthly budget'), findsOneWidget);
      expect(find.text('Set budget'), findsOneWidget);
    });

    testWidgets('validation errors stay in the sheet', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('The budget must be more than 0.'), findsOneWidget);
    });
  });

  testWidgets('tapping a category opens it to change its limit', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Food'));
    await tester.pumpAndSettle();

    expect(find.text('Edit category'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Monthly limit (optional)'),
      findsOneWidget,
    );
  });

  testWidgets('a failure shows its message and can be retried', (tester) async {
    final repos = _Repos();
    repos.budgets.watchFailure = const BudgetFailure(BudgetError.storage);
    await _pump(tester, repos: repos);
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    repos.budgets.watchFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Money available'), findsOneWidget);
  });
}
