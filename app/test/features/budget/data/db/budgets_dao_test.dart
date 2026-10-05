import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../../support/sequential_id_generator.dart';
import '../../../../support/test_database.dart';

BudgetRow _row({String month = '2026-10', int? limit = 600000}) => BudgetRow(
  id: 'budget-$month',
  month: month,
  totalLimitMinor: limit,
  currency: 'TND',
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

  test('the first save creates the row', () async {
    expect(await db.budgetsDao.saveBudget(_row()), isTrue);

    expect(await db.budgetsDao.findById('budget-2026-10'), _row());
    final [op] = await outbox();
    expect(op.entity, 'budgets');
    expect(op.opType, OutboxOpType.create);
    expect(op.baseVersion, 0);
    expect(fields(op), {
      'id': 'budget-2026-10',
      'month': '2026-10',
      'totalLimitMinor': 600000,
      'currency': 'TND',
    });
  });

  test('later saves update only what changed', () async {
    await db.budgetsDao.saveBudget(_row());
    await (db.update(db.budgets)..where((b) => b.id.equals('budget-2026-10')))
        .write(const BudgetsCompanion(version: Value(3)));

    expect(await db.budgetsDao.saveBudget(_row(limit: null)), isTrue);

    final [_, op] = await outbox();
    expect(op.opType, OutboxOpType.update);
    expect(op.baseVersion, 3);
    expect(fields(op), {'totalLimitMinor': null});
    final row = (await db.budgetsDao.findById('budget-2026-10'))!;
    expect(row.totalLimitMinor, isNull);
    expect(row.version, 3);
  });

  test('saving the same values does nothing', () async {
    await db.budgetsDao.saveBudget(_row());

    expect(await db.budgetsDao.saveBudget(_row()), isFalse);
    expect(await outbox(), hasLength(1));
  });

  test('watchLive lists every month', () async {
    await db.budgetsDao.saveBudget(_row());
    await db.budgetsDao.saveBudget(_row(month: '2026-11', limit: 1));

    expect(await db.budgetsDao.watchLive().first, hasLength(2));
  });

  test('a failed outbox append leaves no row', () async {
    await db.close();
    db = openTestDatabase(ids: SequentialIdGenerator(ids: ['dup', 'dup']));
    await db.budgetsDao.saveBudget(_row());

    await expectLater(
      db.budgetsDao.saveBudget(_row(month: '2026-11')),
      throwsA(anything),
    );

    expect(await db.budgetsDao.findById('budget-2026-11'), isNull);
  });
}
