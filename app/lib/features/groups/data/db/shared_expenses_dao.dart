import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'shared_expenses_table.dart';

part 'shared_expenses_dao.g.dart';

/// Shared expenses. Every write also queues its sync op, in one transaction.
@DriftAccessor(tables: [SharedExpenses])
class SharedExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$SharedExpensesDaoMixin {
  SharedExpensesDao(super.attachedDatabase);

  static const entity = 'shared_expenses';

  Future<SharedExpenseRow?> findById(String id) =>
      (select(sharedExpenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// A group's live expenses, newest first, re-emitted on every change.
  Stream<List<SharedExpenseRow>> watchGroup(String groupId) =>
      (select(sharedExpenses)
            ..where((e) => e.groupId.equals(groupId) & e.deleted.not())
            ..orderBy([
              (e) => OrderingTerm.desc(e.date),
              (e) => OrderingTerm.desc(e.id),
            ]))
          .watch();

  Future<void> insertSharedExpense(SharedExpenseRow row) =>
      attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: 0,
        ),
        () => into(sharedExpenses).insert(row),
      );
}
