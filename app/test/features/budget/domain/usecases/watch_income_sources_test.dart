import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/usecases/watch_budgets.dart';
import 'package:mizan/features/budget/domain/usecases/watch_income_sources.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:test/test.dart';

import '../../../../support/fake_budget_repository.dart';
import '../../../../support/fake_income_source_repository.dart';

IncomeSource _source(String id, String name) => IncomeSource(
  id: id,
  name: name,
  amount: const Money(1000, Currency.tnd),
  schedule: const IncomeSchedule.irregular(),
);

void main() {
  test('income sources come sorted by name, ignoring case', () async {
    final repository = FakeIncomeSourceRepository([
      _source('s1', 'tutoring'),
      _source('s3', 'Grant'),
      _source('s2', 'Grant'),
      _source('s4', 'allowance'),
    ]);

    final sources = (await WatchIncomeSources(repository)().first).valueOrNull!;

    expect(sources.map((s) => s.id), ['s4', 's2', 's3', 's1']);
  });

  test('income source failures pass through', () async {
    final repository = FakeIncomeSourceRepository()
      ..watchFailure = const BudgetFailure(BudgetError.storage);

    final result = await WatchIncomeSources(repository)().first;

    expect(result.failureOrNull?.error, BudgetError.storage);
  });

  test('budgets pass through', () async {
    const budget = Budget(id: 'budget-2026-10', month: YearMonth(2026, 10));

    final result = await WatchBudgets(FakeBudgetRepository([budget]))().first;

    expect(result.valueOrNull, [budget]);
  });
}
