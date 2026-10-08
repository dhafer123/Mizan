import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../budget/data/db/budgets_dao.dart';
import '../../../budget/data/db/income_sources_dao.dart';
import '../../../expenses/data/db/categories_dao.dart';
import '../../../expenses/data/db/expenses_dao.dart';
import '../../../groups/data/db/groups_dao.dart';
import '../../../groups/data/db/settlements_dao.dart';
import '../../../groups/data/db/shared_expenses_dao.dart';
import '../../domain/usecases/rebase_row.dart';
import '../remote/sync_api.dart';
import 'sync_payload.dart';

/// The local data belongs to another account now; the page was not applied.
class AccountChangedException implements Exception {
  const AccountChangedException();
}

/// Writes server rows into the local tables, and owns which account the
/// synced data belongs to.
///
/// Every server row is kept as a shadow (`server_rows`), and the row the app
/// shows is always that shadow with the still-queued local ops on top
/// (`rebaseRow`). Rows are rebuilt from the shadow when a pull brings a new
/// version and when a pushed op leaves the outbox, so no local value
/// outlives the op that made it. Overwriting rows in place was not enough:
/// a retried push whose first answer was lost left the op's values on top
/// of a newer server row for good (found by the sync simulation, 3.7).
///
/// Pulled rows bypass the outbox on purpose: they come *from* the server.
/// Shadows are kept for entities this app version has no table for yet
/// (none since 4.4), so the migration that adds
/// such a table can build its rows from them (ADR 0007).
///
/// **Joining a group.** The group's older rows have seqs below the cursor,
/// so the normal pull never brings them. When a pull shows this account
/// newly in a group (its own member row), the group is queued in
/// `group_backfills` and pulled on its own ([applyBackfillPage]).
class SyncLocalStore {
  SyncLocalStore(this._db);

  final AppDatabase _db;

  static const historyEntity = 'entity_history';

  // Upserts take companions built with `toCompanion(false)`: every column
  // explicit, nulls included. A row passed as is would drop its nulls from
  // the ON CONFLICT update, so a value cleared on the server (a removed
  // limit, an emptied note) would never be cleared here. The sync
  // simulation (test/sync_sim) caught that.

  /// Applies one pull page and moves the cursor, in one transaction, only if
  /// the data still belongs to [accountId]. Returns how many changes it
  /// applied to local tables. Throws [AccountChangedException].
  Future<int> applyPage(
    PullPage page, {
    required String accountId,
    required DateTime now,
  }) => _db.transaction(() async {
    final state = await _db.syncStateDao.read();
    if (state.accountId != accountId) throw const AccountChangedException();
    var applied = 0;
    for (final change in page.changes) {
      if (change.entity == GroupsDao.memberEntity) {
        await _queueBackfillIfJoined(change.state, accountId);
      }
      if (await _apply(change)) applied++;
    }
    await _db.syncStateDao.saveCursor(page.cursor, now);
    return applied;
  });

  /// Groups still to backfill, with the cursor to resume from.
  Future<List<GroupBackfill>> pendingBackfills() =>
      _db.select(_db.groupBackfills).get();

  /// Applies one page of a group's backfill (`/sync/pull?group=`) and moves
  /// its cursor, or ends it after the last page. The normal pull may have
  /// brought a newer version of a row already, so an older one is skipped.
  /// Throws [AccountChangedException].
  Future<void> applyBackfillPage(
    String groupId,
    PullPage page, {
    required String accountId,
  }) => _db.transaction(() async {
    final state = await _db.syncStateDao.read();
    if (state.accountId != accountId) throw const AccountChangedException();
    for (final change in page.changes) {
      final id = change.state['id'];
      if (change.entity != historyEntity && id is String) {
        final known = (await _shadow(change.entity, id))?.serverSeq;
        if (known != null && known >= change.serverSeq) continue;
      }
      await _apply(change);
    }
    final backfill = _db.groupBackfills;
    if (page.hasMore) {
      await (_db.update(backfill)..where((b) => b.groupId.equals(groupId)))
          .write(GroupBackfillsCompanion(cursor: Value(page.cursor)));
    } else {
      await (_db.delete(
        backfill,
      )..where((b) => b.groupId.equals(groupId))).go();
    }
  });

  /// [member] (a pulled member row) is this account, in its group, and the
  /// last row seen was not: this account just joined, created the group on
  /// another phone, or came back. Queue the group's backfill.
  Future<void> _queueBackfillIfJoined(
    Map<String, Object?> member,
    String accountId,
  ) async {
    bool mine(Map<String, Object?> row) =>
        row['userId'] == accountId && row['deleted'] != true;
    final id = member['id'];
    final groupId = member['groupId'];
    if (!mine(member) || id is! String || groupId is! String) return;
    final before = await _shadow(GroupsDao.memberEntity, id);
    if (before != null &&
        mine((jsonDecode(before.state) as Map).cast<String, Object?>())) {
      return;
    }
    await _db
        .into(_db.groupBackfills)
        .insert(
          GroupBackfillsCompanion.insert(groupId: groupId),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// A pushed op for this row left the outbox (accepted or refused). Takes
  /// the server row it came back with, unless the shadow is newer (a
  /// retried op replays its first, older answer), and rebuilds the row.
  Future<void> applyPushResult(
    String entity,
    String entityId,
    Map<String, Object?>? state,
  ) async {
    final seq = state?['serverSeq'];
    if (state != null && seq is int && state['id'] == entityId) {
      // Rows pulled before schema v3 have no shadow: compare with the row.
      final known =
          (await _shadow(entity, entityId))?.serverSeq ??
          await _localServerSeq(entity, entityId);
      if (known == null || known <= seq) {
        await _saveShadow(entity, entityId, state, seq);
      }
    }
    if (!await _rebuild(entity, entityId)) {
      await _dropIfOnlyLocal(entity, entityId);
    }
  }

  /// A row the server never had (no shadow) whose ops all left the queue
  /// refused: it exists only here, so it goes. E.g. two phones reversing
  /// the same payment offline: the second reversal is refused and must not
  /// stay on its phone.
  Future<void> _dropIfOnlyLocal(String entity, String id) async {
    final table = _tables[entity];
    if (table == null || await _shadow(entity, id) != null) return;
    if ((await _db.outboxDao.queuedFor(entity, id)).isNotEmpty) return;
    await _db.customUpdate(
      'DELETE FROM "${table.actualTableName}" '
      'WHERE id = ? AND server_seq IS NULL',
      variables: [Variable.withString(id)],
      updates: {table},
      updateKind: UpdateKind.delete,
    );
  }

  late final Map<String, TableInfo<Table, Object?>> _tables = {
    ExpensesDao.entity: _db.expenses,
    CategoriesDao.entity: _db.categories,
    IncomeSourcesDao.entity: _db.incomeSources,
    BudgetsDao.entity: _db.budgets,
    GroupsDao.groupEntity: _db.groups,
    GroupsDao.memberEntity: _db.members,
    SharedExpensesDao.entity: _db.sharedExpenses,
    SettlementsDao.entity: _db.settlements,
  };

  Future<int?> _localServerSeq(
    String entity,
    String id,
  ) async => switch (entity) {
    ExpensesDao.entity => (await _db.expensesDao.findById(id))?.serverSeq,
    CategoriesDao.entity => (await _db.categoriesDao.findById(id))?.serverSeq,
    IncomeSourcesDao.entity => (await _db.incomeSourcesDao.findById(
      id,
    ))?.serverSeq,
    BudgetsDao.entity => (await _db.budgetsDao.findById(id))?.serverSeq,
    GroupsDao.groupEntity => (await _db.groupsDao.findGroup(id))?.serverSeq,
    GroupsDao.memberEntity => (await _db.groupsDao.findMember(id))?.serverSeq,
    SettlementsDao.entity => (await _db.settlementsDao.findById(id))?.serverSeq,
    SharedExpensesDao.entity => (await _db.sharedExpensesDao.findById(
      id,
    ))?.serverSeq,
    _ => null,
  };

  Future<bool> _apply(PulledChange change) async {
    if (change.entity == historyEntity) {
      await _db
          .into(_db.entityHistory)
          .insertOnConflictUpdate(_historyRow(change.state).toCompanion(false));
      return true;
    }
    final id = change.state['id'];
    if (id is! String) throw const FormatException('Pulled row without id');
    await _saveShadow(change.entity, id, change.state, change.serverSeq);
    return _rebuild(change.entity, id);
  }

  Future<ServerRow?> _shadow(String entity, String id) =>
      (_db.select(_db.serverRows)
            ..where((r) => r.entity.equals(entity) & r.entityId.equals(id)))
          .getSingleOrNull();

  Future<void> _saveShadow(
    String entity,
    String id,
    Map<String, Object?> state,
    int serverSeq,
  ) => _db
      .into(_db.serverRows)
      .insertOnConflictUpdate(
        ServerRow(
          entity: entity,
          entityId: id,
          state: jsonEncode(state),
          serverSeq: serverSeq,
        ),
      );

  /// The local row = the shadow + queued ops. Without a shadow (never
  /// synced) the local row is left as it is. Returns whether a local table
  /// was written.
  Future<bool> _rebuild(String entity, String id) async {
    final shadow = await _shadow(entity, id);
    if (shadow == null) return false;
    final queued = await _db.outboxDao.queuedFor(entity, id);
    final row =
        rebaseRow((jsonDecode(shadow.state) as Map).cast<String, Object?>(), [
          for (final op in queued)
            (
              opType: op.opType.name,
              changedFields: (jsonDecode(op.changedFields) as Map)
                  .cast<String, Object?>(),
            ),
        ]);
    switch (entity) {
      case ExpensesDao.entity:
        await _db
            .into(_db.expenses)
            .insertOnConflictUpdate(
              ExpenseRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case CategoriesDao.entity:
        await _db
            .into(_db.categories)
            .insertOnConflictUpdate(
              CategoryRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case IncomeSourcesDao.entity:
        await _db
            .into(_db.incomeSources)
            .insertOnConflictUpdate(
              IncomeSourceRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case BudgetsDao.entity:
        await _db
            .into(_db.budgets)
            .insertOnConflictUpdate(
              BudgetRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case GroupsDao.groupEntity:
        await _db
            .into(_db.groups)
            .insertOnConflictUpdate(
              GroupRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case GroupsDao.memberEntity:
        await _db
            .into(_db.members)
            .insertOnConflictUpdate(
              MemberRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case SharedExpensesDao.entity:
        await _db
            .into(_db.sharedExpenses)
            .insertOnConflictUpdate(
              SharedExpenseRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      case SettlementsDao.entity:
        await _db
            .into(_db.settlements)
            .insertOnConflictUpdate(
              SettlementRow.fromJson(
                row,
                serializer: syncSerializer,
              ).toCompanion(false),
            );
      default:
        return false; // No table for it in this app version yet.
    }
    return true;
  }

  static EntityHistoryRow _historyRow(Map<String, Object?> json) {
    String? encode(Object? value) => value == null ? null : jsonEncode(value);
    return switch (json) {
      {
        'id': final String id,
        'entity': final String entity,
        'entityId': final String entityId,
        'kind': final String kind,
        'field': final String field,
        'serverSeq': final int serverSeq,
        'changedAt': final String changedAt,
      } =>
        EntityHistoryRow(
          id: id,
          entity: entity,
          entityId: entityId,
          kind: kind,
          field: field,
          oldValue: encode(json['oldValue']),
          newValue: encode(json['newValue']),
          changedBy: json['changedBy'] as String?,
          serverSeq: serverSeq,
          changedAt: DateTime.parse(changedAt),
        ),
      _ => throw const FormatException('Bad history row'),
    };
  }

  /// Makes the synced data [accountId]'s. Never synced: it's kept (and its
  /// outbox uploads). Synced with another account: wiped, cursor back to 0.
  /// Returns whether it wiped.
  Future<bool> claimFor(String accountId) => _db.transaction(() async {
    final state = await _db.syncStateDao.read();
    if (state.accountId == accountId) return false;
    final wipe = state.accountId != null;
    if (wipe) {
      for (final table in <TableInfo<Table, Object?>>[
        _db.expenses,
        _db.categories,
        _db.incomeSources,
        _db.budgets,
        _db.budgetCategoryLimits,
        _db.outbox,
        _db.entityHistory,
        _db.serverRows,
        _db.groups,
        _db.members,
        _db.groupBackfills,
        _db.sharedExpenses,
        _db.settlements,
        // Another account's alerts mustn't hold back this one's.
        _db.sentAlerts,
      ]) {
        await _db.delete(table).go();
      }
    }
    await _db.syncStateDao.claim(accountId, resetCursor: wipe);
    return wipe;
  });
}
