import '../../../../core/result/result.dart';
import '../entities/group.dart';
import '../entities/history_entry.dart';
import '../entities/member.dart';
import '../entities/settlement.dart';
import '../entities/shared_expense.dart';
import '../value_objects/group_failure.dart';
import '../value_objects/group_invite.dart';
import '../value_objects/group_ledger.dart';
import '../value_objects/invite_preview.dart';

/// Groups and members on this device (written offline, queued for sync),
/// and the server calls for invites, which need a network.
abstract interface class GroupRepository {
  /// Live groups by name, re-emitted on every change.
  Stream<Result<List<Group>, GroupFailure>> watchGroups();

  /// One group (null once it's gone), re-emitted on every change.
  Stream<Result<Group?, GroupFailure>> watchGroup(String id);

  /// A group's live members by name, re-emitted on every change.
  Stream<Result<List<Member>, GroupFailure>> watchMembers(String groupId);

  /// [watchGroup], read once.
  Future<Result<Group?, GroupFailure>> getGroup(String id);

  /// [watchMembers], read once.
  Future<Result<List<Member>, GroupFailure>> getMembers(String groupId);

  /// A group's live expenses, newest first, re-emitted on every change.
  Stream<Result<List<SharedExpense>, GroupFailure>> watchExpenses(
    String groupId,
  );

  Future<Result<void, GroupFailure>> addExpense(SharedExpense expense);

  /// A group's live expenses and settlements, re-emitted when either
  /// changes.
  Stream<Result<GroupLedger, GroupFailure>> watchLedger(String groupId);

  /// [watchLedger], read once.
  Future<Result<GroupLedger, GroupFailure>> getLedger(String groupId);

  /// Settlements are insert-only: there is no update or delete.
  Future<Result<void, GroupFailure>> addSettlement(Settlement settlement);

  /// The group's history (the group, its members and expenses), newest
  /// first, re-emitted on every change. Only changes the server accepted.
  Stream<Result<List<HistoryEntry>, GroupFailure>> watchHistory(String groupId);

  /// Stores a new group with its founder (this account's member row).
  Future<Result<void, GroupFailure>> add(Group group, Member founder);

  Future<Result<void, GroupFailure>> addMember(Member member);

  /// A new invite to [groupId]; with [memberId], to claim that placeholder.
  Future<Result<GroupInvite, GroupFailure>> createInvite(
    String groupId, {
    String? memberId,
  });

  Future<Result<InvitePreview, GroupFailure>> previewInvite(String token);

  /// Joins the invite's group. Returns the group's id. Its rows arrive with
  /// the next sync.
  Future<Result<String, GroupFailure>> join(String token);
}
