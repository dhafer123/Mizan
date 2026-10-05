import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../../support/sequential_id_generator.dart';
import '../../../../support/test_database.dart';

IncomeSourceRow _row({
  String id = 's1',
  String name = 'Grant',
  int amount = 450000,
  int? day = 15,
}) => IncomeSourceRow(
  id: id,
  name: name,
  amountMinor: amount,
  currency: 'TND',
  scheduleType: 'monthly',
  dayOfMonth: day,
  version: 0,
  deleted: false,
);

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<List<OutboxEntry>> outbox() => db.select(db.outbox).get();

  Map<String, Object?> fields(OutboxEntry op) =>
      jsonDecode(op.changedFields) as Map<String, Object?>;

  test('insert stores the row and queues a create', () async {
    await db.incomeSourcesDao.insertSource(_row());

    expect(await db.incomeSourcesDao.findById('s1'), _row());
    final [op] = await outbox();
    expect(op.entity, 'income_sources');
    expect(op.opType, OutboxOpType.create);
    expect(fields(op), containsPair('scheduleType', 'monthly'));
  });

  test('update queues only the changed fields', () async {
    await db.incomeSourcesDao.insertSource(_row());
    await (db.update(db.incomeSources)..where((s) => s.id.equals('s1'))).write(
      const IncomeSourcesCompanion(version: Value(2)),
    );

    expect(
      await db.incomeSourcesDao.updateSource(_row(amount: 500000)),
      isTrue,
    );

    final [_, op] = await outbox();
    expect(op.opType, OutboxOpType.update);
    expect(op.baseVersion, 2);
    expect(fields(op), {'amountMinor': 500000});
    expect((await db.incomeSourcesDao.findById('s1'))!.version, 2);
    expect(
      await db.incomeSourcesDao.updateSource(_row(amount: 500000)),
      isFalse,
    );
  });

  test('delete leaves a tombstone, hidden from watchLive', () async {
    await db.incomeSourcesDao.insertSource(_row());
    await db.incomeSourcesDao.insertSource(_row(id: 's2', name: 'Job'));

    await db.incomeSourcesDao.softDelete('s1');

    expect((await db.incomeSourcesDao.findById('s1'))!.deleted, isTrue);
    expect((await db.incomeSourcesDao.watchLive().first).map((r) => r.id), [
      's2',
    ]);
    final ops = await outbox();
    expect(ops.last.opType, OutboxOpType.delete);
  });

  test('missing or deleted sources are refused', () async {
    await expectLater(
      db.incomeSourcesDao.updateSource(_row()),
      throwsStateError,
    );
    await db.incomeSourcesDao.insertSource(_row());
    await db.incomeSourcesDao.softDelete('s1');
    await expectLater(db.incomeSourcesDao.softDelete('s1'), throwsStateError);
  });

  test('the day of the month is checked by the database', () async {
    await expectLater(
      db.incomeSourcesDao.insertSource(_row(day: 32)),
      throwsA(anything),
    );
    expect(await outbox(), isEmpty);
  });

  test('a failed outbox append leaves no row', () async {
    await db.close();
    db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
    await db.incomeSourcesDao.insertSource(_row());

    await expectLater(
      db.incomeSourcesDao.insertSource(_row(id: 's2')),
      throwsA(anything),
    );

    expect(await db.incomeSourcesDao.findById('s2'), isNull);
  });
}
