import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/sync/data/remote/sync_api.dart';
import 'package:mizan/features/sync/data/repositories/sync_repository_impl.dart';

import '../../../support/fake_http_adapter.dart';
import '../../../support/test_database.dart';

Map<String, Object?> _group(int seq, {String name = 'Flat 4B'}) => {
  'entity': 'groups',
  'serverSeq': seq,
  'state': {
    'id': 'g1',
    'name': name,
    'currency': 'TND',
    'version': seq,
    'deleted': false,
    'updatedBy': '7',
    'serverSeq': seq,
  },
};

Map<String, Object?> _member(int seq, String id, String? userId) => {
  'entity': 'members',
  'serverSeq': seq,
  'state': {
    'id': id,
    'groupId': 'g1',
    'userId': userId,
    'displayName': id,
    'version': 1,
    'deleted': false,
    'updatedBy': '7',
    'serverSeq': seq,
  },
};

Map<String, Object?> _page(List<Map<String, Object?>> changes, int cursor) => {
  'changes': changes,
  'cursor': cursor,
  'hasMore': false,
};

void main() {
  late AppDatabase db;
  late FakeHttpAdapter server;
  late SyncRepositoryImpl repo;

  setUp(() async {
    db = openTestDatabase();
    server = FakeHttpAdapter((_) => FakeHttpAdapter.json(500));
    repo = SyncRepositoryImpl(
      db: db,
      api: SyncApi(fakeDio(server)),
      clock: FakeClock(testNow),
      deviceId: () async => 'device-1',
      signedIn: () async => true,
    );
    await db.syncStateDao.claim('u1', resetCursor: false);
  });
  tearDown(() => db.close());

  test('joining a group backfills its older rows, once', () async {
    // The normal pull (cursor 50) brings this account's new member row and
    // a rename made after the join; the group's older rows sit below 50.
    server.handler = (r) => FakeHttpAdapter.json(
      200,
      r.queryParameters['group'] == 'g1'
          ? _page([
              _group(3, name: 'Old name'), // Older than the pulled rename.
              _member(4, 'sami', '7'),
              _member(5, 'ali', null),
              _member(60, 'me', 'u1'),
            ], 60)
          : _page([_member(60, 'me', 'u1'), _group(61)], 61),
    );

    expect((await repo.pull(accountId: 'u1')).isOk, isTrue);

    final backfills = server.requests.where(
      (r) => r.queryParameters['group'] == 'g1',
    );
    expect(backfills.map((r) => r.queryParameters['since']), [0]);
    final group = await db.groupsDao.findGroup('g1');
    expect(group!.name, 'Flat 4B', reason: 'the newer pulled row stays');
    final members = await db.select(db.members).get();
    expect(members.map((m) => m.id).toSet(), {'sami', 'ali', 'me'});
    expect(await db.select(db.groupBackfills).get(), isEmpty);
    expect((await db.syncStateDao.read()).cursor, 61);

    // Seen again, this account's row doesn't start another backfill.
    server.requests.clear();
    server.handler = (r) =>
        FakeHttpAdapter.json(200, _page([_member(62, 'me', 'u1')], 62));
    await repo.pull(accountId: 'u1');
    expect(
      server.requests.where((r) => r.queryParameters['group'] != null),
      isEmpty,
    );
  });

  test('a new group queues the group before its founder', () async {
    await db.groupsDao.insertGroup(
      const GroupRow(
        id: 'g1',
        name: 'Flat 4B',
        currency: 'TND',
        version: 0,
        deleted: false,
      ),
      const MemberRow(
        id: 'me',
        groupId: 'g1',
        userId: 'u1',
        displayName: 'Sami',
        version: 0,
        deleted: false,
      ),
    );

    final ops = await db.outboxDao.pending();
    expect(ops.map((o) => (o.entity, o.entityId)), [
      ('groups', 'g1'),
      ('members', 'me'),
    ]);
    expect(jsonDecode(ops.last.changedFields), {
      'id': 'me',
      'groupId': 'g1',
      'userId': 'u1',
      'displayName': 'Sami',
    });
  });
}
