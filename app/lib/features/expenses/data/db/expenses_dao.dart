import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'expenses_table.dart';

part 'expenses_dao.g.dart';

/// Expense rows. Every write also queues its sync op, in one transaction.
@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.attachedDatabase);

  static const entity = 'expenses';

  Future<ExpenseRow?> findById(String id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Every live (not deleted) expense, once.
  Future<List<ExpenseRow>> getLive() =>
      (select(expenses)..where((e) => e.deleted.not())).get();

  /// Live (not deleted) expenses dated in [from, to), re-emitted on every
  /// change. Dates are stored as UTC ISO-8601 text, which sorts like time, so
  /// both bounds must be UTC too.
  Stream<List<ExpenseRow>> watchBetween(DateTime from, DateTime to) {
    assert(from.isUtc && to.isUtc, 'date bounds must be UTC');
    return (select(expenses)..where(
          (e) =>
              e.deleted.not() &
              e.date.isBiggerOrEqualValue(from) &
              e.date.isSmallerThanValue(to),
        ))
        .watch();
  }

  Future<void> insertExpense(ExpenseRow row) =>
      attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: row.version,
        ),
        () => into(expenses).insert(row),
      );

  /// Saves [updated] and queues only the fields that changed. Sync metadata
  /// in [updated] is ignored. Returns false if nothing changed.
  ///
  /// Throws [StateError] if the expense does not exist or is deleted.
  Future<bool> updateExpense(ExpenseRow updated) => transaction(() async {
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
      () => update(expenses).replace(
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

  /// Marks the expense deleted (a tombstone, so the delete can sync).
  ///
  /// Throws [StateError] if the expense does not exist or is already deleted.
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
      () => (update(expenses)..where((e) => e.id.equals(id))).write(
        const ExpensesCompanion(deleted: Value(true)),
      ),
    );
  });

  Future<ExpenseRow> _live(String id) async {
    final row = await findById(id);
    if (row == null || row.deleted) {
      throw StateError('No live expense with id $id');
    }
    return row;
  }
}
