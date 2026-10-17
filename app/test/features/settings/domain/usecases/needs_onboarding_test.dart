import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/budget/domain/entities/budget.dart';
import 'package:mizan/features/budget/domain/entities/income_source.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_error.dart';
import 'package:mizan/features/budget/domain/value_objects/budget_failure.dart';
import 'package:mizan/features/budget/domain/value_objects/income_schedule.dart';
import 'package:mizan/features/expenses/domain/entities/expense.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_error.dart';
import 'package:mizan/features/expenses/domain/value_objects/expense_failure.dart';
import 'package:mizan/features/settings/domain/usecases/finish_onboarding.dart';
import 'package:mizan/features/settings/domain/usecases/needs_onboarding.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_error.dart';
import 'package:mizan/features/settings/domain/value_objects/settings_failure.dart';
import 'package:test/test.dart';

import '../../../../support/fake_budget_repository.dart';
import '../../../../support/fake_device_preferences_repository.dart';
import '../../../../support/fake_expense_repository.dart';
import '../../../../support/fake_income_source_repository.dart';

const _dt = Money(300000, Currency.tnd);

const _grant = IncomeSource(
  id: 'i1',
  name: 'Grant',
  amount: _dt,
  schedule: IncomeSchedule.irregular(),
);

class _Setup {
  _Setup({
    bool onboarded = false,
    List<Expense> expenses = const [],
    List<IncomeSource> incomes = const [],
    List<Budget> budgets = const [],
  }) : preferences = FakeDevicePreferencesRepository(onboarded: onboarded),
       expenses = FakeExpenseRepository(expenses),
       incomes = FakeIncomeSourceRepository(incomes),
       budgets = FakeBudgetRepository(budgets);

  final FakeDevicePreferencesRepository preferences;
  final FakeExpenseRepository expenses;
  final FakeIncomeSourceRepository incomes;
  final FakeBudgetRepository budgets;

  NeedsOnboarding get needsOnboarding =>
      NeedsOnboarding(preferences, expenses, incomes, budgets);
}

void main() {
  group('NeedsOnboarding', () {
    test('a new install with no data needs it', () async {
      final setup = _Setup();

      expect(
        await setup.needsOnboarding(),
        const Ok<bool, SettingsFailure>(true),
      );
      expect(setup.preferences.onboarded, isFalse, reason: 'not finished yet');
    });

    test('once finished, never again', () async {
      final setup = _Setup();
      await FinishOnboarding(setup.preferences)();

      expect(
        await setup.needsOnboarding(),
        const Ok<bool, SettingsFailure>(false),
      );
    });

    final withData = {
      'an expense': _Setup(
        expenses: [
          Expense(
            id: 'e1',
            amount: _dt,
            categoryId: 'food',
            date: DateTime.utc(2026, 10, 1),
          ),
        ],
      ),
      'an income source': _Setup(incomes: [_grant]),
      'a budget': _Setup(
        budgets: [
          Budget(
            id: Budget.idFor(const YearMonth(2026, 10)),
            month: const YearMonth(2026, 10),
            totalLimit: _dt,
          ),
        ],
      ),
    };
    for (final MapEntry(key: what, value: setup) in withData.entries) {
      test('a phone that already has $what skips it, for good', () async {
        expect(
          await setup.needsOnboarding(),
          const Ok<bool, SettingsFailure>(false),
        );
        expect(setup.preferences.onboarded, isTrue);
      });
    }

    test('a failed read of the flag is a storage failure', () async {
      final setup = _Setup();
      setup.preferences.loadFailure = const SettingsFailure(
        SettingsError.storage,
      );

      expect(
        await setup.needsOnboarding(),
        const Err<bool, SettingsFailure>(
          SettingsFailure(SettingsError.storage),
        ),
      );
    });

    test('a failed read of the data is a storage failure', () async {
      final expensesFail = _Setup()
        ..expenses.readFailure = const ExpenseFailure(ExpenseError.storage);
      final incomesFail = _Setup()
        ..incomes.watchFailure = const BudgetFailure(BudgetError.storage);
      final budgetsFail = _Setup()
        ..budgets.watchFailure = const BudgetFailure(BudgetError.storage);

      for (final setup in [expensesFail, incomesFail, budgetsFail]) {
        expect(
          await setup.needsOnboarding(),
          const Err<bool, SettingsFailure>(
            SettingsFailure(SettingsError.storage),
          ),
        );
      }
    });

    test('a failed save of the flag still skips it', () async {
      final setup = _Setup(incomes: [_grant]);
      setup.preferences.saveFailure = const SettingsFailure(
        SettingsError.storage,
      );

      expect(
        await setup.needsOnboarding(),
        const Ok<bool, SettingsFailure>(false),
      );
    });
  });
}
