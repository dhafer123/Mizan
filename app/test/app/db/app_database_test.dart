import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<List<String>> columns(String table) async => [
    for (final row in await db.customSelect('PRAGMA table_info($table)').get())
      row.read<String>('name'),
  ];

  test('creates every table at schema version 4', () async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(db.schemaVersion, 4);
    expect(tables, [
      'budget_category_limits',
      'budgets',
      'categories',
      'entity_history',
      'expenses',
      'group_backfills',
      'groups',
      'income_sources',
      'members',
      'outbox',
      'server_rows',
      'sync_state',
    ]);
  });

  test('synced tables carry the sync metadata columns', () async {
    for (final table in [
      'expenses',
      'categories',
      'income_sources',
      'budgets',
      'budget_category_limits',
      'groups',
      'members',
    ]) {
      expect(
        await columns(table),
        containsAll(['version', 'deleted', 'updated_by', 'server_seq']),
        reason: table,
      );
    }
  });

  test('local-only tables do not', () async {
    for (final table in [
      'outbox',
      'sync_state',
      'entity_history',
      'group_backfills',
    ]) {
      expect(await columns(table), isNot(contains('deleted')), reason: table);
    }
  });

  test('foreign keys are enforced', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('income day of month must be 1-31', () async {
    IncomeSourcesCompanion income(String id, int? day) =>
        IncomeSourcesCompanion.insert(
          id: id,
          name: 'Scholarship',
          amountMinor: 300000,
          currency: 'TND',
          scheduleType: 'monthly',
          dayOfMonth: Value(day),
        );

    await db.into(db.incomeSources).insert(income('ok', 31));
    await db.into(db.incomeSources).insert(income('none', null));
    await expectLater(
      db.into(db.incomeSources).insert(income('bad', 32)),
      throwsA(anything),
    );
  });

  test('dates round-trip with milliseconds and UTC', () async {
    final at = DateTime.utc(2026, 10, 6, 9, 30, 15, 123);
    await db.syncStateDao.saveCursor(1, at);

    expect((await db.syncStateDao.read()).lastSyncAt, at);
  });
}
