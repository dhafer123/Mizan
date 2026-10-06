import '../../../../core/ids/id_generator.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../../../auth/domain/entities/account.dart';
import '../entities/group.dart';
import '../entities/member.dart';
import '../repositories/group_repository.dart';
import '../value_objects/group_error.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/group_names.dart';

/// Creates a group with this account as its first member. Works offline;
/// it reaches the server with the next sync. Returns the group as saved.
class CreateGroup {
  const CreateGroup(this._repository, this._ids);

  final GroupRepository _repository;
  final IdGenerator _ids;

  Future<Result<Group, GroupFailure>> call({
    required String name,
    required Currency currency,
    required Account? me,
  }) async {
    if (me == null) return const Err(GroupFailure(GroupError.signedOut));
    final validated = GroupNames.validate(name, max: GroupNames.maxGroupName);
    if (validated case Err(:final failure)) return Err(failure);

    final group = Group(
      id: _ids.newId(),
      name: validated.valueOrNull!,
      currency: currency,
    );
    final founder = Member(
      id: _ids.newId(),
      groupId: group.id,
      userId: me.id,
      displayName: displayNameOf(me),
    );
    final saved = await _repository.add(group, founder);
    return saved.map((_) => group);
  }

  /// The name other members see: the account's, or its email's first part
  /// (as the server does for members who join).
  static String displayNameOf(Account account) {
    final name = account.displayName?.trim() ?? '';
    final shown = name.isNotEmpty ? name : account.email.split('@').first;
    return shown.length > GroupNames.maxMemberName
        ? shown.substring(0, GroupNames.maxMemberName)
        : shown;
  }
}
