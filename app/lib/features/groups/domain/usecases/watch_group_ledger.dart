import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/group_ledger.dart';

/// A group's expenses and settlements (payments newest first).
class WatchGroupLedger {
  const WatchGroupLedger(this._repository);

  final GroupRepository _repository;

  Stream<Result<GroupLedger, GroupFailure>> call(String groupId) =>
      _repository.watchLedger(groupId);
}
