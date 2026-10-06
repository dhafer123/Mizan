import '../../../../core/result/result.dart';
import '../entities/shared_expense.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';

/// A group's expenses, newest first.
class WatchSharedExpenses {
  const WatchSharedExpenses(this._repository);

  final GroupRepository _repository;

  Stream<Result<List<SharedExpense>, GroupFailure>> call(String groupId) =>
      _repository.watchExpenses(groupId);
}
