import '../../../../core/result/result.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/group_invite.dart';

/// Asks the server for an invite to a group (needs a network, and the group
/// synced). With [memberId], whoever joins becomes that placeholder.
class CreateInvite {
  const CreateInvite(this._repository);

  final GroupRepository _repository;

  Future<Result<GroupInvite, GroupFailure>> call(
    String groupId, {
    String? memberId,
  }) => _repository.createInvite(groupId, memberId: memberId);
}
