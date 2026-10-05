import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/usecases/set_monthly_budget.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_budget_repository.dart';

const _october = YearMonth(2026, 10);

void main() {
  late FakeBudgetRepository repository;
  late SetMonthlyBudget setMonthlyBudget;

  setUp(() {
    repository = FakeBudgetRepository();
    setMonthlyBudget = SetMonthlyBudget(repository);
  });

  test("saves the limit as the month's budget", () async {
    final result = await setMonthlyBudget(
      _october,
      totalLimit: const Money(600000, Currency.tnd),
    );

    const expected = Budget(
      id: 'budget-2026-10',
      month: _october,
      totalLimit: Money(600000, Currency.tnd),
    );
    expect(result.valueOrNull, expected);
    expect(repository.budgets, [expected]);
  });

  test('setting it again replaces that month only', () async {
    await setMonthlyBudget(
      const YearMonth(2026, 9),
      totalLimit: const Money(500000, Currency.tnd),
    );
    await setMonthlyBudget(_october, totalLimit: const Money(1, Currency.tnd));
    await setMonthlyBudget(_october, totalLimit: const Money(2, Currency.tnd));

    expect(repository.budgets.map((b) => b.totalLimit?.minorUnits), [
      500000,
      2,
    ]);
  });

  test('a null limit is saved: no limit from this month on', () async {
    final result = await setMonthlyBudget(_october, totalLimit: null);

    expect(result.valueOrNull?.totalLimit, isNull);
    expect(repository.budgets, hasLength(1));
  });

  test('refuses a zero or negative limit', () async {
    for (final units in [0, -5]) {
      final result = await setMonthlyBudget(
        _october,
        totalLimit: Money(units, Currency.tnd),
      );
      expect(result.failureOrNull?.error, BudgetError.limitNotPositive);
    }
    expect(repository.budgets, isEmpty);
  });

  test('passes on a storage failure', () async {
    repository.writeFailure = const BudgetFailure(BudgetError.storage);

    final result = await setMonthlyBudget(_october, totalLimit: null);

    expect(result.failureOrNull?.error, BudgetError.storage);
  });

  test('ids are derived from the month', () {
    expect(Budget.idFor(const YearMonth(2026, 1)), 'budget-2026-01');
    expect(Budget.idFor(const YearMonth(999, 12)), 'budget-0999-12');
  });
}
