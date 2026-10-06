import '../../../../core/ids/id_generator.dart';
import '../../../../core/result/result.dart';
import '../entities/member.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/group_names.dart';

/// Adds someone who isn't on the app yet. They can claim this member later
/// with an invite made for them. Works offline. Returns the member.
class AddPlaceholderMember {
  const AddPlaceholderMember(this._repository, this._ids);

  final GroupRepository _repository;
  final IdGenerator _ids;

  Future<Result<Member, GroupFailure>> call({
    required String groupId,
    required String name,
  }) async {
    final validated = GroupNames.validate(name, max: GroupNames.maxMemberName);
    if (validated case Err(:final failure)) return Err(failure);
    final member = Member(
      id: _ids.newId(),
      groupId: groupId,
      displayName: validated.valueOrNull!,
    );
    final saved = await _repository.addMember(member);
    return saved.map((_) => member);
  }
}
