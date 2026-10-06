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

  /// The server refused these for good: kept, with its reason, for the UI.
  Future<void> markRejected(Map<int, String> reasons) => transaction(() async {
    for (final MapEntry(key: seq, value: reason) in reasons.entries) {
      await (update(outbox)..where((o) => o.seq.equals(seq))).write(
        OutboxCompanion(
          status: const Value(OutboxStatus.rejected),
          rejectReason: Value(reason),
        ),
      );
    }
  });

  /// Ops left `sending` by a push that never finished (the app was killed):
  /// back to pending. Re-sending is safe; the server dedupes by op id.
  Future<void> resetSending() =>
      (update(outbox)..where((o) => o.status.equalsValue(OutboxStatus.sending)))
          .write(const OutboxCompanion(status: Value(OutboxStatus.pending)));

  /// Ops for one row that the server hasn't taken yet (pending or sending),
  /// oldest first: what a pull re-applies on top of the server's row.
  Future<List<OutboxEntry>> queuedFor(String entity, String entityId) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.entity.equals(entity) &
                  o.entityId.equals(entityId) &
                  o.status.equalsValue(OutboxStatus.rejected).not(),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  /// Ops waiting (pending or in flight) and refused, re-emitted on changes.
  Stream<({int pending, int rejected})> watchCounts() {
    final count = outbox.seq.count();
    return (selectOnly(outbox)
          ..addColumns([outbox.status, count])
          ..groupBy([outbox.status]))
        .watch()
        .map((rows) {
          var pending = 0, rejected = 0;
          for (final row in rows) {
            final n = row.read(count)!;
            if (row.read(outbox.status) == OutboxStatus.rejected.name) {
              rejected += n;
            } else {
              pending += n;
            }
          }
          return (pending: pending, rejected: rejected);
        });
  }

  /// The server applied (or merged) these ops: they are done.
  Future<void> removeAcknowledged(Iterable<int> seqs) =>
      (delete(outbox)..where((o) => o.seq.isIn(seqs))).go();

  Future<void> _setStatus(Iterable<int> seqs, OutboxCompanion status) =>
      (update(outbox)..where((o) => o.seq.isIn(seqs))).write(status);
}
