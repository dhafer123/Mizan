import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../budget/data/db/budgets_dao.dart';
import '../../../budget/data/db/income_sources_dao.dart';
import '../../../expenses/data/db/categories_dao.dart';
import '../../../expenses/data/db/expenses_dao.dart';
import '../../domain/usecases/rebase_row.dart';
import '../remote/sync_api.dart';
import 'sync_payload.dart';

/// The local data belongs to another account now; the page was not applied.
class AccountChangedException implements Exception {
  const AccountChangedException();
}

/// Writes pulled changes into the local tables, and owns which account the
/// synced data belongs to.
///
/// Pulled rows bypass the outbox on purpose: they come *from* the server.
/// Rows of entities this app version has no table for yet (groups, members,
/// shared expenses, settlements until week 4) are skipped; the migration
/// that adds such a table must reset the cursor to 0 so they are pulled
/// again (ADR 0007).
class SyncLocalStore {
  SyncLocalStore(this._db);

  final AppDatabase _db;

  static const historyEntity = 'entity_history';

  /// Applies one pull page and moves the cursor, in one transaction, only if
  /// the data still belongs to [accountId]. Returns how many changes it
  /// applied. Throws [AccountChangedException].
  Future<int> applyPage(
    PullPage page, {
    required String accountId,
    required DateTime now,
  }) => _db.transaction(() async {
    final state = await _db.syncStateDao.read();
    if (state.accountId != accountId) throw const AccountChangedException();
    var applied = 0;
    for (final change in page.changes) {
      if (await _apply(change)) applied++;
    }
    await _db.syncStateDao.saveCursor(page.cursor, now);
    return applied;
  });

  Future<bool> _apply(PulledChange change) async {
    if (change.entity == historyEntity) {
      await _db
          .into(_db.entityHistory)
          .insertOnConflictUpdate(_historyRow(change.state));
      return true;
    }
    final row = await _rebased(change);
    switch (change.entity) {
      case ExpensesDao.entity:
        await _db
            .into(_db.expenses)
            .insertOnConflictUpdate(
              ExpenseRow.fromJson(row, serializer: syncSerializer),
            );
      case CategoriesDao.entity:
        await _db
            .into(_db.categories)
            .insertOnConflictUpdate(
              CategoryRow.fromJson(row, serializer: syncSerializer),
            );
      case IncomeSourcesDao.entity:
        await _db
            .into(_db.incomeSources)
            .insertOnConflictUpdate(
              IncomeSourceRow.fromJson(row, serializer: syncSerializer),
            );
      case BudgetsDao.entity:
        await _db
            .into(_db.budgets)
            .insertOnConflictUpdate(
              BudgetRow.fromJson(row, serializer: syncSerializer),
            );
      default:
        return false; // No table for it in this app version yet.
    }
    return true;
  }

  /// The server's row with this phone's still-queued changes on top.
  Future<Map<String, Object?>> _rebased(PulledChange change) async {
    final id = change.state['id'];
    if (id is! String) throw const FormatException('Pulled row without id');
    final queued = await _db.outboxDao.queuedFor(change.entity, id);
    return rebaseRow(change.state, [
      for (final op in queued)
        (
          opType: op.opType.name,
          changedFields: (jsonDecode(op.changedFields) as Map)
              .cast<String, Object?>(),
        ),
    ]);
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
      ]) {
        await _db.delete(table).go();
      }
    }
    await _db.syncStateDao.claim(accountId, resetCursor: wipe);
    return wipe;
  });
}
