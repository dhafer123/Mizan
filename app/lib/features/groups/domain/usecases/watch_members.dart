import '../../../../core/result/result.dart';
import '../entities/member.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';

class WatchMembers {
  const WatchMembers(this._repository);

  final GroupRepository _repository;

  Stream<Result<List<Member>, GroupFailure>> call(String groupId) =>
      _repository.watchMembers(groupId);
}
