import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import '../../../sync/data/db/outbox_op_type.dart';
import '../../../sync/data/db/pending_op.dart';
import '../../../sync/data/db/sync_payload.dart';
import 'settlements_table.dart';

part 'settlements_dao.g.dart';

/// Settlements. Insert-only; every insert also queues its sync op, in one
/// transaction.
@DriftAccessor(tables: [Settlements])
class SettlementsDao extends DatabaseAccessor<AppDatabase>
    with _$SettlementsDaoMixin {
  SettlementsDao(super.attachedDatabase);

  static const entity = 'settlements';

  Future<SettlementRow?> findById(String id) =>
      (select(settlements)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// A group's settlements, newest first, re-emitted on every change.
  Stream<List<SettlementRow>> watchGroup(String groupId) =>
      _group(groupId).watch();

  /// [watchGroup], read once.
  Future<List<SettlementRow>> getGroup(String groupId) => _group(groupId).get();

  SimpleSelectStatement<$SettlementsTable, SettlementRow> _group(
    String groupId,
  ) => select(settlements)
    ..where((s) => s.groupId.equals(groupId) & s.deleted.not())
    ..orderBy([
      (s) => OrderingTerm.desc(s.date),
      (s) => OrderingTerm.desc(s.id),
    ]);

  Future<void> insertSettlement(SettlementRow row) =>
      attachedDatabase.outboxDao.recordWrite(
        PendingOp(
          entity: entity,
          entityId: row.id,
          type: OutboxOpType.create,
          changedFields: syncPayload(row),
          baseVersion: 0,
        ),
        () => into(settlements).insert(row),
      );
}
