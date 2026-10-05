import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';
import '../value_objects/budget_error.dart';
import '../value_objects/budget_failure.dart';

/// Sets the overall spending limit from [month] on (until a later month sets
/// another). A null limit removes it from [month] on. Earlier months keep
/// theirs.
class SetMonthlyBudget {
  const SetMonthlyBudget(this._repository);

  final BudgetRepository _repository;

  Future<Result<Budget, BudgetFailure>> call(
    YearMonth month, {
    required Money? totalLimit,
  }) async {
    if (totalLimit != null && !totalLimit.isPositive) {
      return const Err(BudgetFailure(BudgetError.limitNotPositive));
    }
    final budget = Budget(
      id: Budget.idFor(month),
      month: month,
      totalLimit: totalLimit,
    );
    final saved = await _repository.save(budget);
    return saved.map((_) => budget);
  }
}
