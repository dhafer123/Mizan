import '../../../../core/result/result.dart';
import '../repositories/income_source_repository.dart';
import '../value_objects/budget_failure.dart';

/// Deletes an income source (a tombstone, so the delete syncs).
class DeleteIncomeSource {
  const DeleteIncomeSource(this._repository);

  final IncomeSourceRepository _repository;

  Future<Result<void, BudgetFailure>> call(String id) => _repository.delete(id);
}
