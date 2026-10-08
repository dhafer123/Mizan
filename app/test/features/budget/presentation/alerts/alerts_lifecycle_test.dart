import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/budget_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/expenses_providers.dart';
import 'package:mizan/app/di/groups_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_alert.dart';
import 'package:mizan/features/budget/presentation/alerts/alerts_lifecycle.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';

import '../../../../support/fake_alert_log.dart';
import '../../../../support/fake_alert_notifier.dart';
import '../../../../support/fake_auth_repository.dart';
import '../../../../support/fake_budget_repository.dart';
import '../../../../support/fake_category_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_group_repository.dart';
import '../../../../support/fake_income_source_repository.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Expense _food(String id, int dinars, int day) => Expense(
  id: id,
  amount: _dt(dinars),
  categoryId: 'food',
  date: DateTime.utc(2026, 10, day),
);

void main() {
  late FakeExpenseRepository expenses;
  late FakeAlertNotifier notifier;
  late FakeAlertLog log;

  Future<void> pump(WidgetTester tester, List<Expense> initial) async {
    expenses = FakeExpenseRepository(initial);
    notifier = FakeAlertNotifier();
    log = FakeAlertLog();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(
            FakeClock(DateTime.utc(2026, 10, 6, 9)),
          ),
          expenseRepositoryProvider.overrideWithValue(expenses),
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository([
              DefaultCategories.food.copyWith(monthlyLimit: _dt(150)),
              ...DefaultCategories.all.skip(1),
            ]),
          ),
          budgetRepositoryProvider.overrideWithValue(FakeBudgetRepository()),
          incomeSourceRepositoryProvider.overrideWithValue(
            FakeIncomeSourceRepository(),
          ),
          groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          alertNotificationsProvider.overrideWithValue(notifier),
          alertLogProvider.overrideWithValue(log),
        ],
        child: const AlertsLifecycle(child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks for permission once, on start', (tester) async {
    await pump(tester, const []);
    expect(notifier.permissionRequests, 1);
    expect(notifier.shown, isEmpty);
  });

  testWidgets('an expense that takes a category past 80% alerts once', (
    tester,
  ) async {
    await pump(tester, [_food('e1', 100, 2)]);
    expect(notifier.shown, isEmpty);

    await expenses.add(_food('e2', 25, 6)); // 125 of 150: 83%
    await tester.pumpAndSettle();
    expect(notifier.shown, hasLength(1));
    expect(
      notifier.shown.single,
      isA<CategoryLimitAlert>().having((a) => a.usedPercent, 'used', 83),
    );

    await expenses.add(_food('e3', 10, 6)); // still the same situation
    await tester.pumpAndSettle();
    expect(notifier.shown, hasLength(1));
  });
}
