import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'groups_table.dart';
import 'members_table.dart';

part 'groups_dao.g.dart';

/// Groups and their members. Every write also queues its sync op, in one
/// transaction.
@DriftAccessor(tables: [Groups, Members])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(super.attachedDatabase);

  static const groupEntity = 'groups';
  static const memberEntity = 'members';

  Future<GroupRow?> findGroup(String id) =>
      (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<MemberRow?> findMember(String id) =>
      (select(members)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Live groups by name, re-emitted on every change.
  Stream<List<GroupRow>> watchGroups() =>
      (select(groups)
            ..where((g) => g.deleted.not())
            ..orderBy([
              (g) => OrderingTerm.asc(g.name.collate(Collate.noCase)),
            ]))
          .watch();

  Stream<GroupRow?> watchGroup(String id) => (select(
    groups,
  )..where((g) => g.id.equals(id) & g.deleted.not())).watchSingleOrNull();

  /// A group's live members by name, re-emitted on every change.
  Stream<List<MemberRow>> watchMembers(String groupId) =>
      _members(groupId).watch();

  /// [watchMembers], read once.
  Future<List<MemberRow>> getMembers(String groupId) => _members(groupId).get();

  SimpleSelectStatement<$MembersTable, MemberRow> _members(String groupId) =>
      select(members)
        ..where((m) => m.groupId.equals(groupId) & m.deleted.not())
        ..orderBy([
          (m) => OrderingTerm.asc(m.displayName.collate(Collate.noCase)),
        ]);

  /// A new group and its founder (this account's member row): two ops, the
  /// group's first, so the server sees the group before its member.
  Future<void> insertGroup(GroupRow group, MemberRow founder) =>
      transaction(() async {
        await attachedDatabase.outboxDao.recordWrite(
          _create(groupEntity, group.id, group),
          () => into(groups).insert(group),
        );
        await insertMember(founder);
      });

  Future<void> insertMember(MemberRow member) =>
      attachedDatabase.outboxDao.recordWrite(
        _create(memberEntity, member.id, member),
        () => into(members).insert(member),
      );

  static PendingOp _create(String entity, String id, DataClass row) =>
      PendingOp(
        entity: entity,
        entityId: id,
        type: OutboxOpType.create,
        changedFields: syncPayload(row),
        baseVersion: 0,
      );
}
