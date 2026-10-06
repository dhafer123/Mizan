import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/invite_link.dart';

/// Joins a group with an invite link. Returns the group's id; its rows
/// arrive with the next sync, so sync right after.
class JoinGroup {
  const JoinGroup(this._repository);

  final GroupRepository _repository;

  Future<Result<String, GroupFailure>> call(String link) async {
    final token = InviteLink.tokenFrom(link);
    if (token == null) return const Err(GroupFailure(GroupError.invalidLink));
    return _repository.join(token);
  }
}
