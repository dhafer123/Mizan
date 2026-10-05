import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../app/db/app_database.dart';
import 'outbox_status.dart';
import 'outbox_table.dart';
import 'pending_op.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  /// Runs [write] and appends [op] to the outbox in one transaction: if
  /// either fails, neither is kept. Every write to a synced table must go
  /// through here.
  Future<T> recordWrite<T>(PendingOp op, Future<T> Function() write) =>
      transaction(() async {
        final result = await write();
        await into(outbox).insert(
          OutboxCompanion.insert(
            opId: attachedDatabase.ids.newId(),
            entity: op.entity,
            entityId: op.entityId,
            opType: op.type,
            changedFields: jsonEncode(op.changedFields),
            baseVersion: op.baseVersion,
            createdAt: attachedDatabase.clock.now().toUtc(),
          ),
        );
        return result;
      });

  /// Ops waiting to be pushed, oldest first.
  Future<List<OutboxEntry>> pending({int limit = 200}) =>
      (select(outbox)
            ..where((o) => o.status.equalsValue(OutboxStatus.pending))
            ..orderBy([(o) => OrderingTerm.asc(o.seq)])
            ..limit(limit))
          .get();

  Stream<int> watchPendingCount() {
    final count = outbox.seq.count();
    return (selectOnly(outbox)
          ..addColumns([count])
          ..where(outbox.status.equalsValue(OutboxStatus.pending)))
        .map((row) => row.read(count)!)
        .watchSingle();
  }

  Future<void> markSending(Iterable<int> seqs) => _setStatus(
    seqs,
    const OutboxCompanion(status: Value(OutboxStatus.sending)),
  );

  /// A push failed (network, server error): back to pending, one more attempt.
  Future<void> markRetry(Iterable<int> seqs) =>
      (update(outbox)..where((o) => o.seq.isIn(seqs))).write(
        OutboxCompanion.custom(
          status: Constant(OutboxStatus.pending.name),
          attempts: outbox.attempts + const Constant(1),
        ),
      );

  Future<void> markRejected(Iterable<int> seqs) => _setStatus(
    seqs,
    const OutboxCompanion(status: Value(OutboxStatus.rejected)),
  );

  /// The server applied (or merged) these ops: they are done.
  Future<void> removeAcknowledged(Iterable<int> seqs) =>
      (delete(outbox)..where((o) => o.seq.isIn(seqs))).go();

  Future<void> _setStatus(Iterable<int> seqs, OutboxCompanion status) =>
      (update(outbox)..where((o) => o.seq.isIn(seqs))).write(status);
}
