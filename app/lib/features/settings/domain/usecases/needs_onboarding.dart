import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';
import '../../../budget/domain/repositories/budget_repository.dart';
import '../../../budget/domain/repositories/income_source_repository.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../repositories/device_preferences_repository.dart';
import '../value_objects/settings_error.dart';
import '../value_objects/settings_failure.dart';

/// Whether to show onboarding: only on a new install. A phone that already
/// has an expense, an income source or a budget (a beta tester updating, say)
/// skips it, and is recorded as onboarded so it never sees it later either.
class NeedsOnboarding {
  const NeedsOnboarding(
    this._preferences,
    this._expenses,
    this._incomes,
    this._budgets,
  );

  final DevicePreferencesRepository _preferences;
  final ExpenseRepository _expenses;
  final IncomeSourceRepository _incomes;
  final BudgetRepository _budgets;

  Future<Result<bool, SettingsFailure>> call() async {
    switch (await _preferences.loadOnboarded()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Ok(false);
      case Ok():
        break;
    }

    switch (await _hasData()) {
      case null:
        return const Err(SettingsFailure(SettingsError.storage));
      case false:
        return const Ok(true);
      case true:
        // Not showing it is right either way; a failed save just checks
        // again next start.
        await _preferences.saveOnboarded();
        return const Ok(false);
    }
  }

  /// Null when a read fails.
  Future<bool?> _hasData() async {
    final reads = <Future<Result<List<Object>, Failure>> Function()>[
      _expenses.getAll,
      _incomes.getAll,
      _budgets.getAll,
    ];
    for (final read in reads) {
      switch (await read()) {
        case Err():
          return null;
        case Ok(:final value):
          if (value.isNotEmpty) return true;
      }
    }
    return false;
  }
}
