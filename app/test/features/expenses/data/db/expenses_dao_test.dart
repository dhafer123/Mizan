import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';
import 'package:mizan/features/sync/data/db/outbox_status.dart';

import '../../../../support/sequential_id_generator.dart';
import '../../../../support/test_database.dart';

ExpenseRow _expense({
  String id = 'e1',
  int amountMinor = 4500,
  String categoryId = 'food',
  String? note,
}) => ExpenseRow(
  id: id,
  amountMinor: amountMinor,
  currency: 'TND',
  categoryId: categoryId,
  date: DateTime.utc(2026, 10, 6),
  note: note,
  source: 'manual',
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

  /// Simulates the server having accepted the row at [version].
  Future<void> serverAccepted(String id, int version) =>
      (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
        ExpensesCompanion(
          version: Value(version),
          serverSeq: Value(version * 10),
          updatedBy: const Value('user-1'),
        ),
      );

  group('insert', () {
    test('stores the row and queues a create op with every field', () async {
      await db.expensesDao.insertExpense(_expense(note: 'coffee'));

      expect(await db.expensesDao.findById('e1'), _expense(note: 'coffee'));
      final [op] = await outbox();
      expect(op.opId, 'op-1');
      expect(op.entity, 'expenses');
      expect(op.entityId, 'e1');
      expect(op.opType, OutboxOpType.create);
      expect(op.baseVersion, 0);
      expect(op.createdAt, testNow);
      expect(op.status, OutboxStatus.pending);
      expect(op.attempts, 0);
      expect(fields(op), {
        'id': 'e1',
        'amountMinor': 4500,
        'currency': 'TND',
        'categoryId': 'food',
        'date': '2026-10-06T00:00:00.000Z',
        'note': 'coffee',
        'source': 'manual',
      });
    });

    test('insertExpenses stores every row with its op, or none', () async {
      await db.expensesDao.insertExpenses([
        _expense(id: 'e1'),
        _expense(id: 'e2', note: 'taxi'),
      ]);
      expect(
        await db.expensesDao.findById('e2'),
        _expense(id: 'e2', note: 'taxi'),
      );
      expect((await outbox()).map((op) => op.entityId), ['e1', 'e2']);

      // e3 is fine, e1 again isn't: neither is kept.
      await expectLater(
        db.expensesDao.insertExpenses([_expense(id: 'e3'), _expense(id: 'e1')]),
        throwsA(anything),
      );
      expect(await db.expensesDao.findById('e3'), isNull);
      expect(await outbox(), hasLength(2));
    });
  });

  group('update', () {
    test(
      'queues only the changed fields, based on the current version',
      () async {
        await db.expensesDao.insertExpense(_expense());
        await serverAccepted('e1', 3);

        final changed = await db.expensesDao.updateExpense(
          _expense(amountMinor: 5000, note: 'big coffee'),
        );

        expect(changed, isTrue);
        final [_, op] = await outbox();
        expect(op.opType, OutboxOpType.update);
        expect(op.baseVersion, 3);
        expect(fields(op), {'amountMinor': 5000, 'note': 'big coffee'});
      },
    );

    test('keeps the sync metadata the server set', () async {
      await db.expensesDao.insertExpense(_expense());
      await serverAccepted('e1', 3);

      await db.expensesDao.updateExpense(_expense(amountMinor: 5000));

      final row = (await db.expensesDao.findById('e1'))!;
      expect(row.amountMinor, 5000);
      expect(row.version, 3);
      expect(row.serverSeq, 30);
      expect(row.updatedBy, 'user-1');
    });

    test('does nothing when nothing changed', () async {
      await db.expensesDao.insertExpense(_expense());

      expect(await db.expensesDao.updateExpense(_expense()), isFalse);
      expect(await outbox(), hasLength(1));
    });

    test('refuses a missing or deleted expense', () async {
      await expectLater(
        db.expensesDao.updateExpense(_expense(id: 'nope')),
        throwsStateError,
      );
      await db.expensesDao.insertExpense(_expense());
      await db.expensesDao.softDelete('e1');
      await expectLater(
        db.expensesDao.updateExpense(_expense(amountMinor: 1)),
        throwsStateError,
      );
      expect(await outbox(), hasLength(2));
    });
  });

  group('delete', () {
    test('leaves a tombstone and queues a delete op', () async {
      await db.expensesDao.insertExpense(_expense());
      await serverAccepted('e1', 2);

      await db.expensesDao.softDelete('e1');

      expect((await db.expensesDao.findById('e1'))!.deleted, isTrue);
      final [_, op] = await outbox();
      expect(op.opType, OutboxOpType.delete);
      expect(op.baseVersion, 2);
      expect(fields(op), isEmpty);
      await expectLater(db.expensesDao.softDelete('e1'), throwsStateError);
    });
  });

  group('the write and its outbox op are one transaction', () {
    test('if the outbox append fails, the expense is not saved', () async {
      await db.close();
      // Both writes get op id "dup", so the second outbox insert breaks the
      // unique constraint after its expense was written.
      db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
      await db.expensesDao.insertExpense(_expense(id: 'e1'));

      await expectLater(
        db.expensesDao.insertExpense(_expense(id: 'e2')),
        throwsA(anything),
      );

      expect(await db.expensesDao.findById('e2'), isNull);
      expect(await outbox(), hasLength(1));
    });

    test('if the expense write fails, no op is queued', () async {
      await db.expensesDao.insertExpense(_expense());

      await expectLater(
        db.expensesDao.insertExpense(_expense(amountMinor: 1)), // same id
        throwsA(anything),
      );

      expect((await db.expensesDao.findById('e1'))!.amountMinor, 4500);
      expect(await outbox(), hasLength(1));
    });

    test('a failed update leaves the row as it was', () async {
      await db.close();
      db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
      await db.expensesDao.insertExpense(_expense());

      await expectLater(
        db.expensesDao.updateExpense(_expense(amountMinor: 9999)),
        throwsA(anything),
      );

      expect((await db.expensesDao.findById('e1'))!.amountMinor, 4500);
      expect(await outbox(), hasLength(1));
    });

    test('a failed delete leaves no tombstone', () async {
      await db.close();
      db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
      await db.expensesDao.insertExpense(_expense());

      await expectLater(db.expensesDao.softDelete('e1'), throwsA(anything));

      expect((await db.expensesDao.findById('e1'))!.deleted, isFalse);
    });
  });
}
