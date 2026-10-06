import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import 'sync_state_table.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.attachedDatabase);

  static const _rowId = 1;

  /// The pull cursor: the highest `serverSeq` pulled (0 before the first pull).
  Future<SyncStateRow> read() async =>
      await (select(
        syncState,
      )..where((s) => s.id.equals(_rowId))).getSingleOrNull() ??
      const SyncStateRow(id: _rowId, cursor: 0);

  /// Marks the synced data as [accountId]'s; [resetCursor] also forgets the
  /// cursor and last sync (after a wipe).
  Future<void> claim(String accountId, {required bool resetCursor}) =>
      into(syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(
          id: const Value(_rowId),
          accountId: Value(accountId),
          cursor: resetCursor ? const Value(0) : const Value.absent(),
          lastSyncAt: resetCursor ? const Value(null) : const Value.absent(),
        ),
      );

  /// Records a finished pull. Call inside the transaction that applied it.
  Future<void> saveCursor(int cursor, DateTime syncedAt) =>
      into(syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(
          id: const Value(_rowId),
          cursor: Value(cursor),
          lastSyncAt: Value(syncedAt.toUtc()),
        ),
      );
}
