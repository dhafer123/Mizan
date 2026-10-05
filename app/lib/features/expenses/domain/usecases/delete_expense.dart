import '../../../../core/result/result.dart';
import '../repositories/expense_repository.dart';
import '../value_objects/expense_failure.dart';

/// Deletes an expense (a tombstone, so the delete syncs).
class DeleteExpense {
  const DeleteExpense(this._repository);

  final ExpenseRepository _repository;

  Future<Result<void, ExpenseFailure>> call(String id) =>
      _repository.delete(id);
}
