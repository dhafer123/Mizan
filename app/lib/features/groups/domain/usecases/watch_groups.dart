import '../../../../core/result/result.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';

class WatchGroups {
  const WatchGroups(this._repository);

  final GroupRepository _repository;

  Stream<Result<List<Group>, GroupFailure>> call() => _repository.watchGroups();
}
