import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'income_sources_table.dart';

part 'income_sources_dao.g.dart';

/// Income source rows. Every write also queues its sync op, in one
/// transaction.
@DriftAccessor(tables: [IncomeSources])
class IncomeSourcesDao extends DatabaseAccessor<AppDatabase>
    with _$IncomeSourcesDaoMixin {
  IncomeSourcesDao(super.attachedDatabase);

  static const entity = 'income_sources';

  Future<IncomeSourceRow?> findById(String id) =>
      (select(incomeSources)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Live (not deleted) sources, re-emitted on every change.
  Stream<List<IncomeSourceRow>> watchLive() =>
      (select(incomeSources)..where((s) => s.deleted.not())).watch();

  Future<void> insertSource(IncomeSourceRow row) =>
      attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: row.version,
        ),
        () => into(incomeSources).insert(row),
      );

  /// Saves [updated] and queues only the fields that changed. Sync metadata
  /// in [updated] is ignored. Returns false if nothing changed.
  ///
  /// Throws [StateError] if the source does not exist or is deleted.
  Future<bool> updateSource(IncomeSourceRow updated) => transaction(() async {
    final current = await _live(updated.id);
    final changed = changedSyncFields(current, updated);
    if (changed.isEmpty) return false;

    await attachedDatabase.outboxDao.recordWrite(
      PendingOp(
        entity: entity,
        entityId: current.id,
        type: OutboxOpType.update,
        changedFields: changed,
        baseVersion: current.version,
      ),
      () => update(incomeSources).replace(
        updated.copyWith(
          version: current.version,
          deleted: current.deleted,
          updatedBy: Value(current.updatedBy),
          serverSeq: Value(current.serverSeq),
        ),
      ),
    );
    return true;
  });

  /// Marks the source deleted (a tombstone, so the delete can sync).
  ///
  /// Throws [StateError] if the source does not exist or is already deleted.
  Future<void> softDelete(String id) => transaction(() async {
    final current = await _live(id);
    await attachedDatabase.outboxDao.recordWrite(
      PendingOp(
        entity: entity,
        entityId: id,
        type: OutboxOpType.delete,
        changedFields: const {},
        baseVersion: current.version,
      ),
      () => (update(incomeSources)..where((s) => s.id.equals(id))).write(
        const IncomeSourcesCompanion(deleted: Value(true)),
      ),
    );
  });

  Future<IncomeSourceRow> _live(String id) async {
    final row = await findById(id);
    if (row == null || row.deleted) {
      throw StateError('No live income source with id $id');
    }
    return row;
  }
}
