import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';
import 'package:mizan/features/sync/data/db/outbox_status.dart';
import 'package:mizan/features/sync/data/db/pending_op.dart';
import 'package:mizan/features/sync/data/db/sync_payload.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:mizan/features/sync/domain/value_objects/outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';

import '../../../../support/fake_http_adapter.dart';
import '../../../../support/test_database.dart';

ExpenseRow _expense(
  String id, {
  int amount = 4500,
  int version = 0,
  int? serverSeq,
  String? note,
  bool deleted = false,
}) => ExpenseRow(
  id: id,
  amountMinor: amount,
  currency: 'TND',
  categoryId: 'food',
  date: DateTime.utc(2026, 10, 6),
  note: note,
  source: 'manual',
  version: version,
  deleted: deleted,
  updatedBy: serverSeq == null ? null : '7',
  serverSeq: serverSeq,
);

/// A pulled change for [row], as the server sends it.
Map<String, Object?> _change(ExpenseRow row) => {
  'entity': 'expenses',
  'serverSeq': row.serverSeq,
  'state': row.toJson(serializer: syncSerializer),
};

Map<String, Object?> _page(
  List<Map<String, Object?>> changes, {
  required int cursor,
  bool hasMore = false,
}) => {'changes': changes, 'cursor': cursor, 'hasMore': hasMore};

void main() {
  late AppDatabase db;
  late FakeHttpAdapter server;
  late SyncRepositoryImpl repo;
  var signedIn = true;

  setUp(() async {
    db = openTestDatabase();
    server = FakeHttpAdapter((_) => FakeHttpAdapter.json(500));
    signedIn = true;
    repo = SyncRepositoryImpl(
      db: db,
      api: SyncApi(fakeDio(server)),
      clock: FakeClock(testNow),
      deviceId: () async => 'device-1',
      signedIn: () async => signedIn,
    );
    await db.syncStateDao.claim('u1', resetCursor: false);
  });
  tearDown(() => db.close());

  Future<List<OutboxEntry>> outbox() => db.select(db.outbox).get();

  /// Answers each push with [statuses] for its ops, in order.
  void answerPush(List<String> Function(List<Object?> ops) statuses) {
    server.handler = (r) {
      final ops = (r.data as Map)['ops'] as List<Object?>;
      return FakeHttpAdapter.json(200, {
        'results': [
          for (final s in statuses(ops))
            {'status': s, if (s == 'rejected') 'reason': 'not_a_member'},
        ],
      });
    };
  }

  group('push', () {
    test(
      'sends queued ops; accepted ones leave, refused ones stay with a reason',
      () async {
        for (final id in ['a', 'b', 'c']) {
          await db.expensesDao.insertExpense(_expense(id));
        }
        answerPush((_) => ['applied', 'merged', 'rejected']);

        final result = await repo.push();

        expect(
          result,
          const Ok<({int accepted, int rejected}), SyncFailure>((
            accepted: 2,
            rejected: 1,
          )),
        );
        final [left] = await outbox();
        expect(
          (left.entityId, left.status, left.rejectReason),
          ('c', OutboxStatus.rejected, 'not_a_member'),
        );
        final body = server.requests.single.data as Map;
        expect(body['deviceId'], 'device-1');
        final op = (body['ops'] as List).first as Map;
        expect(op['entity'], 'expenses');
        expect(op['opType'], 'create');
        expect((op['changedFields'] as Map)['amountMinor'], 4500);
      },
    );

    test(
      'a refused edit is replaced by the server row it came back with',
      () async {
        // Regression (found by test/sync_sim): an edit rebased onto a pulled
        // tombstone, then rejected, used to stay on the phone for good.
        await db
            .into(db.expenses)
            .insert(_expense('a', version: 2, serverSeq: 19, deleted: true));
        await db.expensesDao.insertExpense(_expense('b'));
        await db.outboxDao.recordWrite(
          const PendingOp(
            entity: 'expenses',
            entityId: 'a',
            type: OutboxOpType.update,
            changedFields: {'amountMinor': 9999, 'note': 'mine'},
            baseVersion: 1,
          ),
          () => (db.update(db.expenses)..where((e) => e.id.equals('a'))).write(
            const ExpensesCompanion(
              amountMinor: Value(9999),
              note: Value('mine'),
            ),
          ),
        );
        server.handler = (_) => FakeHttpAdapter.json(200, {
          'results': [
            {'status': 'applied'},
            {
              'status': 'rejected',
              'reason': 'deleted',
              'state': _expense(
                'a',
                version: 2,
                serverSeq: 19,
                deleted: true,
              ).toJson(serializer: syncSerializer),
            },
          ],
        });

        await repo.push();

        final row = await db.expensesDao.findById('a');
        expect((row!.amountMinor, row.note, row.deleted), (4500, null, true));
      },
    );

    test('a replayed rejection older than the local row is ignored', () async {
      await db
          .into(db.expenses)
          .insert(_expense('a', amount: 7000, version: 3, serverSeq: 30));
      await db.expensesDao.updateExpense(
        _expense('a', amount: 7100, version: 3, serverSeq: 30),
      );
      server.handler = (_) => FakeHttpAdapter.json(200, {
        'results': [
          {
            'status': 'rejected',
            'reason': 'deleted',
            'state': _expense(
              'a',
              version: 2,
              serverSeq: 19,
              deleted: true,
            ).toJson(serializer: syncSerializer),
          },
        ],
      });

      await repo.push();

      final row = await db.expensesDao.findById('a');
      expect((row!.serverSeq, row.deleted), (30, false));
    });

    test('a retried op whose first answer was lost: the newer server row '
        'wins once it leaves the queue', () async {
      // Regression (found by test/sync_sim): the op's values used to stay
      // on top of a newer server row after the replayed ack.
      await db.expensesDao.insertExpense(_expense('a', note: 'mine'));
      server.handler = (r) => r.path == SyncApi.pullPath
          ? FakeHttpAdapter.json(
              200,
              _page([
                _change(
                  _expense('a', note: 'theirs', version: 2, serverSeq: 9),
                ),
              ], cursor: 9),
            )
          : FakeHttpAdapter.json(200, {
              'results': [
                // The replayed first answer: older than what was pulled.
                {
                  'status': 'applied',
                  'state': _expense(
                    'a',
                    note: 'mine',
                    version: 1,
                    serverSeq: 7,
                  ).toJson(serializer: syncSerializer),
                },
              ],
            });
      await repo.pull(accountId: 'u1');
      expect(
        (await db.expensesDao.findById('a'))!.note,
        'mine',
        reason: 'still queued: shown on top',
      );

      await repo.push();

      final row = await db.expensesDao.findById('a');
      expect((row!.note, row.serverSeq), ('theirs', 9));
    });

    test('in batches of 200, oldest first', () async {
      await db.batch((b) {
        for (var i = 0; i < 250; i++) {
          b.insert(
            db.outbox,
            OutboxCompanion.insert(
              opId: 'op-$i',
              entity: 'expenses',
              entityId: 'e-$i',
              opType: OutboxOpType.create,
              changedFields: '{}',
              baseVersion: 0,
              createdAt: testNow,
            ),
          );
        }
      });
      answerPush((ops) => List.filled(ops.length, 'applied'));

      final result = await repo.push();

      expect(result.valueOrNull?.accepted, 250);
      expect(
        [
          for (final r in server.requests)
            ((r.data as Map)['ops'] as List).length,
        ],
        [200, 50],
      );
      expect(
        ((server.requests.first.data as Map)['ops'] as List).first,
        containsPair('opId', 'op-0'),
      );
      expect(await outbox(), isEmpty);
    });

    test('nothing queued: no request', () async {
      expect((await repo.push()).valueOrNull, (accepted: 0, rejected: 0));
      expect(server.requests, isEmpty);
    });

    test('offline: ops go back to pending with one more attempt', () async {
      await db.expensesDao.insertExpense(_expense('a'));
      server.handler = FakeHttpAdapter.offline;

      expect(
        (await repo.push()).failureOrNull,
        const SyncFailure(SyncError.offline),
      );
      final [op] = await outbox();
      expect((op.status, op.attempts), (OutboxStatus.pending, 1));
    });

    test('server errors and unreadable answers', () async {
      await db.expensesDao.insertExpense(_expense('a'));

      server.handler = (_) => FakeHttpAdapter.json(500);
      expect(
        (await repo.push()).failureOrNull,
        const SyncFailure(SyncError.server),
      );
      server.handler = (_) =>
          FakeHttpAdapter.json(200, {'results': <Object?>[]});
      expect(
        (await repo.push()).failureOrNull,
        const SyncFailure(SyncError.server),
      );
      expect((await outbox()).single.status, OutboxStatus.pending);
    });

    test('a 401: session over if signed out, else just offline', () async {
      await db.expensesDao.insertExpense(_expense('a'));
      server.handler = (_) =>
          FakeHttpAdapter.json(401, {'code': 'token_not_valid'});

      expect(
        (await repo.push()).failureOrNull,
        const SyncFailure(SyncError.offline),
      );
      signedIn = false;
      expect(
        (await repo.push()).failureOrNull,
        const SyncFailure(SyncError.sessionExpired),
      );
    });

    test('ops left "sending" by a killed app are sent again', () async {
      await db.expensesDao.insertExpense(_expense('a'));
      await db.outboxDao.markSending([(await outbox()).single.seq]);
      answerPush((ops) => List.filled(ops.length, 'applied'));

      expect((await repo.push()).valueOrNull?.accepted, 1);
    });
  });

  group('pull', () {
    test('applies every page, then stores the cursor and time', () async {
      server.handler = (r) => switch (r.queryParameters['since']) {
        0 => FakeHttpAdapter.json(
          200,
          _page(
            [_change(_expense('a', version: 1, serverSeq: 10))],
            cursor: 10,
            hasMore: true,
          ),
        ),
        10 => FakeHttpAdapter.json(
          200,
          _page([
            _change(_expense('b', version: 1, serverSeq: 11)),
          ], cursor: 11),
        ),
        _ => FakeHttpAdapter.json(500),
      };

      final result = await repo.pull(accountId: 'u1');

      expect(result.valueOrNull, 2);
      final rows = await db.select(db.expenses).get();
      expect({for (final r in rows) r.id: r.serverSeq}, {'a': 10, 'b': 11});
      final state = await db.syncStateDao.read();
      expect((state.cursor, state.lastSyncAt), (11, testNow));
      expect(await repo.lastSyncAt(), testNow);
      expect(server.requests.map((r) => r.queryParameters['limit']), [
        200,
        200,
      ]);
    });

    test('a value cleared on the server is cleared here', () async {
      // Regression (found by test/sync_sim): a plain upsert dropped nulls.
      server.handler = (r) => FakeHttpAdapter.json(
        200,
        r.queryParameters['since'] == 0
            ? _page([
                _change(
                  _expense('a', note: 'old note', version: 1, serverSeq: 1),
                ),
              ], cursor: 1)
            : _page([
                _change(_expense('a', version: 2, serverSeq: 2)),
              ], cursor: 2),
      );

      await repo.pull(accountId: 'u1');
      expect((await db.expensesDao.findById('a'))!.note, 'old note');
      await repo.pull(accountId: 'u1');

      expect((await db.expensesDao.findById('a'))!.note, isNull);
    });

    test('pulled rows do not go into the outbox', () async {
      server.handler = (_) => FakeHttpAdapter.json(
        200,
        _page([_change(_expense('a', version: 1, serverSeq: 3))], cursor: 3),
      );

      await repo.pull(accountId: 'u1');

      expect(await outbox(), isEmpty);
    });

    test(
      'a local edit still queued stays visible on top of the pulled row',
      () async {
        await db.expensesDao.insertExpense(_expense('a'));
        await db.expensesDao.updateExpense(
          _expense('a', amount: 9999, note: 'mine'),
        );
        server.handler = (_) => FakeHttpAdapter.json(
          200,
          _page([
            _change(
              _expense(
                'a',
                amount: 4500,
                note: 'server',
                version: 2,
                serverSeq: 20,
              ),
            ),
          ], cursor: 20),
        );

        await repo.pull(accountId: 'u1');

        final row = await db.expensesDao.findById('a');
        expect(
          (row!.amountMinor, row.note),
          (9999, 'mine'),
          reason: 'queued edit wins locally',
        );
        expect(
          (row.version, row.serverSeq),
          (2, 20),
          reason: 'metadata is the server\'s',
        );
      },
    );

    test('a refused edit is not re-applied: the server row wins', () async {
      await db.expensesDao.insertExpense(_expense('a'));
      await db.outboxDao.markRejected({(await outbox()).single.seq: 'deleted'});
      server.handler = (_) => FakeHttpAdapter.json(
        200,
        _page([
          _change(_expense('a', version: 3, serverSeq: 30, deleted: true)),
        ], cursor: 30),
      );

      await repo.pull(accountId: 'u1');

      expect((await db.expensesDao.findById('a'))!.deleted, isTrue);
    });

    test(
      'all four personal tables, history, and skipping unknown entities',
      () async {
        server.handler = (_) => FakeHttpAdapter.json(
          200,
          _page([
            {
              'entity': 'categories',
              'serverSeq': 1,
              'state': {
                'id': 'food',
                'name': 'Groceries',
                'icon': 'food',
                'monthlyLimitMinor': null,
                'currency': 'TND',
                'archived': false,
                'version': 1,
                'deleted': false,
                'updatedBy': '7',
                'serverSeq': 1,
              },
            },
            {
              'entity': 'income_sources',
              'serverSeq': 2,
              'state': {
                'id': 'i-1',
                'name': 'Scholarship',
                'amountMinor': 250000,
                'currency': 'TND',
                'scheduleType': 'oneOff',
                'dayOfMonth': null,
                'date': '2026-11-01T00:00:00.000Z',
                'version': 1,
                'deleted': false,
                'updatedBy': '7',
                'serverSeq': 2,
              },
            },
            {
              'entity': 'budgets',
              'serverSeq': 3,
              'state': {
                'id': 'budget-2026-10',
                'month': '2026-10',
                'totalLimitMinor': 600000,
                'currency': 'TND',
                'version': 1,
                'deleted': false,
                'updatedBy': '7',
                'serverSeq': 3,
              },
            },
            {
              'entity': 'receipts',
              'serverSeq': 4,
              'state': {'id': 's-1'},
            },
            {
              'entity': 'entity_history',
              'serverSeq': 5,
              'state': {
                'id': '99',
                'entity': 'expenses',
                'entityId': 'a',
                'kind': 'overwritten',
                'field': 'amountMinor',
                'oldValue': 120000,
                'newValue': 150000,
                'changedBy': '7',
                'serverSeq': 5,
                'changedAt': '2026-10-06T09:00:00.000Z',
              },
            },
          ], cursor: 5),
        );

        final result = await repo.pull(accountId: 'u1');

        expect(result.valueOrNull, 4, reason: 'no table for receipts');
        expect((await db.select(db.categories).getSingle()).name, 'Groceries');
        expect(
          (await db.select(db.incomeSources).getSingle()).date,
          DateTime.utc(2026, 11, 1),
        );
        expect(
          (await db.select(db.budgets).getSingle()).totalLimitMinor,
          600000,
        );
        final history = await db.select(db.entityHistory).getSingle();
        expect(
          (history.kind, history.oldValue, history.newValue),
          ('overwritten', '120000', '150000'),
        );
        expect((await db.syncStateDao.read()).cursor, 5);
      },
    );

    test('a page for another account is not applied', () async {
      server.handler = (_) => FakeHttpAdapter.json(
        200,
        _page([_change(_expense('a', version: 1, serverSeq: 3))], cursor: 3),
      );

      final result = await repo.pull(accountId: 'someone-else');

      expect(result.failureOrNull, const SyncFailure(SyncError.accountChanged));
      expect(await db.select(db.expenses).get(), isEmpty);
      expect((await db.syncStateDao.read()).cursor, 0);
    });

    test('a bad row rolls the whole page back', () async {
      server.handler = (_) => FakeHttpAdapter.json(
        200,
        _page([
          _change(_expense('a', version: 1, serverSeq: 3)),
          {
            'entity': 'expenses',
            'serverSeq': 4,
            'state': {'id': 'b', 'amountMinor': 'lots'},
          },
        ], cursor: 4),
      );

      expect(
        (await repo.pull(accountId: 'u1')).failureOrNull,
        const SyncFailure(SyncError.server),
      );
      expect(await db.select(db.expenses).get(), isEmpty);
      expect((await db.syncStateDao.read()).cursor, 0);
    });

    test('offline: nothing changes', () async {
      server.handler = FakeHttpAdapter.offline;

      expect(
        (await repo.pull(accountId: 'u1')).failureOrNull,
        const SyncFailure(SyncError.offline),
      );
      expect((await db.syncStateDao.read()).cursor, 0);
    });
  });

  group('claimFor', () {
    Future<void> someData() async {
      await db.expensesDao.insertExpense(_expense('a'));
      await db
          .into(db.entityHistory)
          .insert(
            EntityHistoryCompanion.insert(
              id: 'h',
              entity: 'expenses',
              entityId: 'a',
              field: 'x',
              changedAt: testNow,
            ),
          );
      await db.syncStateDao.saveCursor(42, testNow);
    }

    test('the same account keeps everything', () async {
      await someData();

      expect((await repo.claimFor('u1')).valueOrNull, isFalse);
      expect(await db.select(db.expenses).get(), hasLength(1));
      expect((await db.syncStateDao.read()).cursor, 42);
    });

    test('first sign-in keeps local-only data, so it uploads', () async {
      final fresh = openTestDatabase();
      addTearDown(fresh.close);
      final r = SyncRepositoryImpl(
        db: fresh,
        api: SyncApi(fakeDio(server)),
        clock: FakeClock(testNow),
        deviceId: () async => 'd',
        signedIn: () async => true,
      );
      await fresh.expensesDao.insertExpense(_expense('a'));

      expect((await r.claimFor('u1')).valueOrNull, isFalse);
      expect((await fresh.syncStateDao.read()).accountId, 'u1');
      expect(await fresh.select(fresh.outbox).get(), hasLength(1));
    });

    test('another account wipes the synced data, outbox and cursor', () async {
      await someData();

      expect((await repo.claimFor('u2')).valueOrNull, isTrue);

      expect(await db.select(db.expenses).get(), isEmpty);
      expect(await outbox(), isEmpty);
      expect(await db.select(db.entityHistory).get(), isEmpty);
      final state = await db.syncStateDao.read();
      expect(
        (state.accountId, state.cursor, state.lastSyncAt),
        ('u2', 0, null),
      );
    });
  });

  test('watchOutbox counts pending and refused ops', () async {
    final counts = <OutboxCounts>[];
    final sub = repo.watchOutbox().listen(counts.add);
    await db.expensesDao.insertExpense(_expense('a'));
    await db.expensesDao.insertExpense(_expense('b'));
    await db.outboxDao.markRejected({(await outbox()).first.seq: 'x'});
    await pumpEventQueue();
    await sub.cancel();

    expect(counts.last, const OutboxCounts(pending: 1, rejected: 1));
  });

  test('the API refuses a bad push answer shape', () async {
    server.handler = (_) => FakeHttpAdapter.json(200, {'nope': true});
    final api = SyncApi(fakeDio(server));

    await expectLater(api.push('d', const []), throwsA(isA<FormatException>()));
    await expectLater(api.pull(since: 0), throwsA(isA<FormatException>()));
    server.handler = (r) =>
        throw DioException(requestOptions: r, type: DioExceptionType.cancel);
    expect(
      (await repo.pull(accountId: 'u1')).failureOrNull,
      const SyncFailure(SyncError.server),
    );
  });
}
