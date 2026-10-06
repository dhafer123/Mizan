import '../../../../core/result/result.dart';
import '../entities/history_entry.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';

/// Who changed what in a group, newest first.
class WatchGroupHistory {
  const WatchGroupHistory(this._repository);

  final GroupRepository _repository;

  Stream<Result<List<HistoryEntry>, GroupFailure>> call(String groupId) =>
      _repository.watchHistory(groupId);
}
