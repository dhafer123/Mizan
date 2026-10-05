import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'budgets_table.dart';

part 'budgets_dao.g.dart';

/// Month budget rows. Every write also queues its sync op, in one
/// transaction.
@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.attachedDatabase);

  static const entity = 'budgets';

  Future<BudgetRow?> findById(String id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  /// Live (not deleted) budgets, re-emitted on every change.
  Stream<List<BudgetRow>> watchLive() =>
      (select(budgets)..where((b) => b.deleted.not())).watch();

  /// Stores [row]: a create the first time its id is saved, then updates of
  /// the fields that changed. Sync metadata in [row] is ignored. Returns
  /// false if nothing changed.
  Future<bool> saveBudget(BudgetRow row) => transaction(() async {
    final current = await findById(row.id);
    if (current == null || current.deleted) {
      await attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: 0,
        ),
        () => into(
          budgets,
        ).insertOnConflictUpdate(row.copyWith(version: 0, deleted: false)),
      );
      return true;
    }

    final changed = changedSyncFields(current, row);
    if (changed.isEmpty) return false;
    await attachedDatabase.outboxDao.recordWrite(
      PendingOp(
        entity: entity,
        entityId: current.id,
        type: OutboxOpType.update,
        changedFields: changed,
        baseVersion: current.version,
      ),
      () => update(budgets).replace(
        row.copyWith(
          version: current.version,
          deleted: false,
          updatedBy: Value(current.updatedBy),
          serverSeq: Value(current.serverSeq),
        ),
      ),
    );
    return true;
  });
}
