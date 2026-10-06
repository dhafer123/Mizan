// Started from `dart run drift_dev make-migrations`; the data checks are ours.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/fake_clock.dart';

import '../../support/sequential_id_generator.dart';
import '../../support/test_database.dart';
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

AppDatabase _open(QueryExecutor executor) => AppDatabase(
  executor,
  ids: SequentialIdGenerator(),
  clock: FakeClock(testNow),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    useSystemSqliteOnWindows();
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('every upgrade path produces the current schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      for (final toVersion in versions.skip(i + 1)) {
        test('$fromVersion → $toVersion', () async {
          final schema = await verifier.schemaAt(fromVersion);
          final db = _open(schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    }
  });

  test('v1 → v2 keeps every row; the new columns start empty', () async {
    const expense = v1.ExpensesData(
      version: 0,
      deleted: 0,
      id: 'e-1',
      amountMinor: 4500,
      currency: 'TND',
      categoryId: 'food',
      date: '2026-10-06T00:00:00.000Z',
      source: 'manual',
    );
    const op = v1.OutboxData(
      seq: 1,
      opId: 'op-1',
      entity: 'expenses',
      entityId: 'e-1',
      opType: 'create',
      changedFields: '{"amountMinor":4500}',
      baseVersion: 0,
      createdAt: '2026-10-06T09:00:00.000Z',
      attempts: 0,
      status: 'pending',
    );
    const history = v1.EntityHistoryData(
      id: 'h-1',
      entity: 'expenses',
      entityId: 'e-1',
      field: 'amountMinor',
      changedAt: '2026-10-06T09:00:00.000Z',
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: _open,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.expenses, expense);
        batch.insert(oldDb.outbox, op);
        batch.insert(oldDb.syncState, const v1.SyncStateData(id: 1, cursor: 0));
        batch.insert(oldDb.entityHistory, history);
      },
      validateItems: (newDb) async {
        expect((await newDb.select(newDb.expenses).getSingle()).id, 'e-1');
        final outbox = await newDb.select(newDb.outbox).getSingle();
        expect(
          (outbox.opId, outbox.status, outbox.rejectReason),
          ('op-1', 'pending', null),
        );
        final state = await newDb.select(newDb.syncState).getSingle();
        expect((state.cursor, state.accountId), (0, null));
        final row = await newDb.select(newDb.entityHistory).getSingle();
        expect((row.field, row.kind), ('amountMinor', 'changed'));
      },
    );
  });

  test('v3 → v4 builds groups and members from their shadows', () async {
    v3.ServerRowsData shadow(String entity, String id, String state) =>
        v3.ServerRowsData(
          entity: entity,
          entityId: id,
          state: state,
          serverSeq: 9,
        );

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: _open,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.serverRows, [
          shadow(
            'groups',
            'g1',
            '{"id":"g1","name":"Flat 4B","currency":"TND","version":1,'
                '"deleted":false,"updatedBy":"7","serverSeq":9}',
          ),
          shadow(
            'members',
            'm1',
            '{"id":"m1","groupId":"g1","userId":null,"displayName":"Ali",'
                '"version":2,"deleted":true,"updatedBy":"7","serverSeq":9}',
          ),
        ]);
      },
      validateItems: (newDb) async {
        final group = await newDb.select(newDb.groups).getSingle();
        expect(
          (group.id, group.name, group.currency, group.version, group.deleted),
          ('g1', 'Flat 4B', 'TND', 1, 0),
        );
        expect((group.updatedBy, group.serverSeq), ('7', 9));
        final member = await newDb.select(newDb.members).getSingle();
        expect(
          (member.groupId, member.userId, member.displayName, member.deleted),
          ('g1', null, 'Ali', 1),
        );
      },
    );
  });

  test('v4 → v5 builds shared expenses from their shadows', () async {
    const state =
        '{"id":"s1","groupId":"g1","payerId":"m1","amountMinor":9000,'
        '"currency":"TND","date":"2026-10-06T00:00:00.000Z",'
        '"split":{"type":"equal","memberIds":["m1","m2"]},'
        '"shares":{"m1":4500,"m2":4500},"categoryId":null,"version":1,'
        '"deleted":false,"updatedBy":"7","serverSeq":12}';

    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: _open,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.serverRows,
          const v4.ServerRowsData(
            entity: 'shared_expenses',
            entityId: 's1',
            state: state,
            serverSeq: 12,
          ),
        );
      },
      validateItems: (newDb) async {
        final row = await newDb.select(newDb.sharedExpenses).getSingle();
        expect(
          (row.groupId, row.payerId, row.amountMinor, row.categoryId),
          ('g1', 'm1', 9000, null),
        );
        expect(row.date, '2026-10-06T00:00:00.000Z');
        expect(jsonDecode(row.split), {
          'type': 'equal',
          'memberIds': ['m1', 'm2'],
        });
        expect(jsonDecode(row.shares), {'m1': 4500, 'm2': 4500});
        expect((row.version, row.deleted, row.serverSeq), (1, 0, 12));
      },
    );
  });

  test('v5 → v6 builds settlements from their shadows', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 5,
      newVersion: 6,
      createOld: v5.DatabaseAtV5.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: _open,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.serverRows,
          const v5.ServerRowsData(
            entity: 'settlements',
            entityId: 'p2',
            state:
                '{"id":"p2","groupId":"g1","fromMemberId":"m2",'
                '"toMemberId":"m1","amountMinor":4500,"currency":"TND",'
                '"date":"2026-10-06T00:00:00.000Z","reversesId":"p1",'
                '"version":1,"deleted":false,"updatedBy":"7","serverSeq":20}',
            serverSeq: 20,
          ),
        );
      },
      validateItems: (newDb) async {
        final row = await newDb.select(newDb.settlements).getSingle();
        expect(
          (row.fromMemberId, row.toMemberId, row.amountMinor, row.reversesId),
          ('m2', 'm1', 4500, 'p1'),
        );
        expect((row.date, row.serverSeq), ('2026-10-06T00:00:00.000Z', 20));
      },
    );
  });
}
