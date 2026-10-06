import '../../../../core/result/result.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';

/// One group; null once it's gone.
class WatchGroup {
  const WatchGroup(this._repository);

  final GroupRepository _repository;

  Stream<Result<Group?, GroupFailure>> call(String id) =>
      _repository.watchGroup(id);
}
