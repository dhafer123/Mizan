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

  /// History rows of [groupId], its members and its expenses, newest first,
  /// re-emitted on every change. History rows don't carry a group, so they
  /// are matched by entity id.
  Stream<List<EntityHistoryRow>> watchHistory(String groupId) {
    final db = attachedDatabase;
    final expenseIds = selectOnly(db.sharedExpenses)
      ..addColumns([db.sharedExpenses.id])
      ..where(db.sharedExpenses.groupId.equals(groupId));
    final settlementIds = selectOnly(db.settlements)
      ..addColumns([db.settlements.id])
      ..where(db.settlements.groupId.equals(groupId));
    final memberIds = selectOnly(members)
      ..addColumns([members.id])
      ..where(members.groupId.equals(groupId));
    return (select(db.entityHistory)
          ..where(
            (h) =>
                (h.entity.equals('shared_expenses') &
                    h.entityId.isInQuery(expenseIds)) |
                (h.entity.equals('settlements') &
                    h.entityId.isInQuery(settlementIds)) |
                (h.entity.equals(memberEntity) &
                    h.entityId.isInQuery(memberIds)) |
                (h.entity.equals(groupEntity) & h.entityId.equals(groupId)),
          )
          ..orderBy([(h) => OrderingTerm.desc(h.serverSeq)])
          ..limit(historyLimit))
        .watch();
  }

  /// A group's live expenses and settlements, read together whenever either
  /// table changes: what its balances are computed from.
  Stream<(List<SharedExpenseRow>, List<SettlementRow>)> watchLedger(
    String groupId,
  ) async* {
    final db = attachedDatabase;
    Future<(List<SharedExpenseRow>, List<SettlementRow>)> read() => transaction(
      () async => (
        await db.sharedExpensesDao.getGroup(groupId),
        await db.settlementsDao.getGroup(groupId),
      ),
    );
    yield await read();
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables([db.sharedExpenses, db.settlements]),
    )) {
      yield await read();
    }
  }

  /// Every live group with its live members, expenses and settlements, read
  /// together whenever any of those tables changes.
  Stream<
    List<
      (GroupRow, List<MemberRow>, List<SharedExpenseRow>, List<SettlementRow>)
    >
  >
  watchEverything() async* {
    final db = attachedDatabase;
    Future<
      List<
        (GroupRow, List<MemberRow>, List<SharedExpenseRow>, List<SettlementRow>)
      >
    >
    read() => transaction(() async {
      final all = await (select(groups)..where((g) => g.deleted.not())).get();
      final people = await (select(
        members,
      )..where((m) => m.deleted.not())).get();
      final spent = await (select(
        db.sharedExpenses,
      )..where((e) => e.deleted.not())).get();
      final paid = await (select(
        db.settlements,
      )..where((s) => s.deleted.not())).get();
      return [
        for (final g in all)
          (
            g,
            [
              for (final m in people)
                if (m.groupId == g.id) m,
            ],
            [
              for (final e in spent)
                if (e.groupId == g.id) e,
            ],
            [
              for (final s in paid)
                if (s.groupId == g.id) s,
            ],
          ),
      ];
    });
    yield await read();
    await for (final _ in db.tableUpdates(
      TableUpdateQuery.onAllTables([
        groups,
        members,
        db.sharedExpenses,
        db.settlements,
      ]),
    )) {
      yield await read();
    }
  }

  /// The most history rows shown for one group.
  static const historyLimit = 300;

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
