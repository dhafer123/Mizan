import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';
import 'package:mizan/features/sync/data/db/outbox_status.dart';
import 'package:mizan/features/sync/data/db/pending_op.dart';

import '../../../../support/test_database.dart';

PendingOp _op(String entityId) => PendingOp(
  entity: 'expenses',
  entityId: entityId,
  type: OutboxOpType.update,
  changedFields: {'note': entityId},
  baseVersion: 1,
);

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> queue(List<String> entityIds) async {
    for (final id in entityIds) {
      await db.outboxDao.recordWrite(_op(id), () async {});
    }
  }

  List<String> ids(List<OutboxEntry> ops) => [for (final o in ops) o.entityId];

  test('recordWrite returns the write result and queues the op', () async {
    final result = await db.outboxDao.recordWrite(_op('a'), () async => 42);

    expect(result, 42);
    expect(ids(await db.outboxDao.pending()), ['a']);
  });

  test('recordWrite queues nothing if the write throws', () async {
    await expectLater(
      db.outboxDao.recordWrite(_op('a'), () async => throw StateError('x')),
      throwsStateError,
    );
    expect(await db.outboxDao.pending(), isEmpty);
  });

  test('pending ops come out oldest first, up to the limit', () async {
    await queue(['a', 'b', 'c']);

    expect(ids(await db.outboxDao.pending()), ['a', 'b', 'c']);
    expect(ids(await db.outboxDao.pending(limit: 2)), ['a', 'b']);
  });

  test('ops being sent are not pending; a retry puts them back', () async {
    await queue(['a', 'b']);
    final [a, b] = await db.outboxDao.pending();

    await db.outboxDao.markSending([a.seq, b.seq]);
    expect(await db.outboxDao.pending(), isEmpty);

    await db.outboxDao.markRetry([a.seq]);
    final [retried] = await db.outboxDao.pending();
    expect(retried.entityId, 'a');
    expect(retried.attempts, 1);
    expect(retried.status, OutboxStatus.pending);
  });

  test('rejected ops stay for the UI but are not pending', () async {
    await queue(['a']);
    final [a] = await db.outboxDao.pending();

    await db.outboxDao.markRejected({a.seq: 'not_a_member'});

    expect(await db.outboxDao.pending(), isEmpty);
    final [row] = await db.select(db.outbox).get();
    expect(row.status, OutboxStatus.rejected);
    expect(row.rejectReason, 'not_a_member');
  });

  test('acknowledged ops are removed', () async {
    await queue(['a', 'b']);
    final [a, _] = await db.outboxDao.pending();

    await db.outboxDao.removeAcknowledged([a.seq]);

    expect(ids(await db.outboxDao.pending()), ['b']);
  });

  test('watchPendingCount follows the queue', () async {
    final counts = db.outboxDao.watchPendingCount();
    expect(await counts.first, 0);

    await queue(['a', 'b']);
    expect(await counts.first, 2);
  });
}
