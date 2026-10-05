import '../../../../core/result/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';
import '../value_objects/budget_failure.dart';

/// Every month budget ever set. `ComputeBudgetOverview` picks the one in
/// force for a month.
class WatchBudgets {
  const WatchBudgets(this._repository);

  final BudgetRepository _repository;

  Stream<Result<List<Budget>, BudgetFailure>> call() => _repository.watchAll();
}
