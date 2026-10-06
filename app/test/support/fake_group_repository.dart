import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/entities/shared_expense.dart';
import 'package:mizan/features/groups/domain/repositories/group_repository.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/group_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/group_invite.dart';
import 'package:mizan/features/groups/domain/value_objects/invite_preview.dart';

/// Groups in memory. Server calls answer [joinResult] and record their token.
class FakeGroupRepository implements GroupRepository {
  final groups = <Group>[];
  final members = <Member>[];
  final expenses = <SharedExpense>[];
  final tokens = <String>[];
  Result<String, GroupFailure> joinResult = const Ok('g1');

  @override
  Stream<Result<List<Group>, GroupFailure>> watchGroups() =>
      Stream.value(Ok(groups));

  @override
  Stream<Result<Group?, GroupFailure>> watchGroup(String id) =>
      Stream.value(Ok(groups.where((g) => g.id == id).firstOrNull));

  @override
  Stream<Result<List<Member>, GroupFailure>> watchMembers(String groupId) =>
      Stream.value(Ok(members.where((m) => m.groupId == groupId).toList()));

  @override
  Future<Result<Group?, GroupFailure>> getGroup(String id) async =>
      Ok(groups.where((g) => g.id == id).firstOrNull);

  @override
  Future<Result<List<Member>, GroupFailure>> getMembers(String groupId) async =>
      Ok(members.where((m) => m.groupId == groupId).toList());

  @override
  Stream<Result<List<SharedExpense>, GroupFailure>> watchExpenses(
    String groupId,
  ) => Stream.value(Ok(expenses.where((e) => e.groupId == groupId).toList()));

  @override
  Future<Result<void, GroupFailure>> addExpense(SharedExpense expense) async {
    expenses.add(expense);
    return const Ok(null);
  }

  @override
  Future<Result<void, GroupFailure>> add(Group group, Member founder) async {
    groups.add(group);
    members.add(founder);
    return const Ok(null);
  }

  @override
  Future<Result<void, GroupFailure>> addMember(Member member) async {
    members.add(member);
    return const Ok(null);
  }

  @override
  Future<Result<GroupInvite, GroupFailure>> createInvite(
    String groupId, {
    String? memberId,
  }) async => Ok(
    GroupInvite(
      token: 'token-0123456789abcdef',
      groupId: groupId,
      memberId: memberId,
      expiresAt: DateTime.utc(2026, 10, 13),
    ),
  );

  @override
  Future<Result<InvitePreview, GroupFailure>> previewInvite(
    String token,
  ) async {
    tokens.add(token);
    return const Err(GroupFailure(GroupError.inviteExpired));
  }

  @override
  Future<Result<String, GroupFailure>> join(String token) async {
    tokens.add(token);
    return joinResult;
  }
}
