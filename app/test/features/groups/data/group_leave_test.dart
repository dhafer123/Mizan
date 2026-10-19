import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/data/remote/groups_api.dart';
import 'package:mizan/features/groups/data/repositories/group_repository_impl.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/group_failure.dart';

import '../../../support/fake_http_adapter.dart';
import '../../../support/test_database.dart';

MemberRow _member(String id, String groupId) => MemberRow(
  id: id,
  groupId: groupId,
  displayName: id,
  version: 1,
  deleted: false,
);

GroupRow _group(String id) =>
    GroupRow(id: id, name: id, currency: 'TND', version: 1, deleted: false);

void main() {
  late AppDatabase db;
  late FakeHttpAdapter server;
  late GroupRepositoryImpl repo;

  GroupError? errorOf(Result<void, GroupFailure> result) => switch (result) {
    Ok() => null,
    Err(:final failure) => failure.error,
  };

  /// Pretends every queued op was pushed: the outbox empties and each row
  /// gets a server shadow and a history row.
  Future<void> synced() async {
    for (final op in await db.select(db.outbox).get()) {
      await db
          .into(db.serverRows)
          .insertOnConflictUpdate(
            ServerRow(
              entity: op.entity,
              entityId: op.entityId,
              state: op.changedFields,
              serverSeq: op.seq,
            ),
          );
      await db
          .into(db.entityHistory)
          .insert(
            EntityHistoryRow(
              id: 'h${op.seq}',
              entity: op.entity,
              entityId: op.entityId,
              kind: 'created',
              field: '',
              serverSeq: op.seq,
              changedAt: testNow,
            ),
          );
    }
    await db.delete(db.outbox).go();
  }

  setUp(() async {
    db = openTestDatabase();
    server = FakeHttpAdapter(
      (request) => FakeHttpAdapter.json(200, {'groupId': 'flat'}),
    );
    repo = GroupRepositoryImpl(
      db.groupsDao,
      db.sharedExpensesDao,
      db.settlementsDao,
      GroupsApi(fakeDio(server)),
    );
    await db.groupsDao.insertGroup(_group('flat'), _member('me', 'flat'));
    await db.groupsDao.insertMember(_member('ali', 'flat'));
    // Another group, which leaving must not touch.
    await db.groupsDao.insertGroup(_group('trip'), _member('me2', 'trip'));
  });
  tearDown(() => db.close());

  test('leaving removes the group and everything in it from this phone, '
      'and nothing else', () async {
    await synced();

    final result = await repo.leave('flat');

    expect(result.isOk, isTrue);
    expect(server.to('/groups/flat/leave'), hasLength(1));
    expect((await db.select(db.groups).get()).map((g) => g.id), ['trip']);
    expect((await db.select(db.members).get()).map((m) => m.id), ['me2']);
    final shadows = await db.select(db.serverRows).get();
    expect(shadows.map((r) => r.entityId).toSet(), {'trip', 'me2'});
    final history = await db.select(db.entityHistory).get();
    expect(history.map((h) => h.entityId).toSet(), {'trip', 'me2'});
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test("changes still waiting to sync stop it before the server's asked", () async {
    final result = await repo.leave('flat');

    expect(errorOf(result), GroupError.unsyncedChanges);
    expect(server.requests, isEmpty);
    expect(await db.groupsDao.findGroup('flat'), isNotNull);
  });

  test('a refusal from the server keeps the group here', () async {
    await synced();
    server.handler = (request) => FakeHttpAdapter.json(409, {
      'code': 'balance_not_zero',
    });

    final result = await repo.leave('flat');

    expect(errorOf(result), GroupError.balanceNotZero);
    expect(await db.groupsDao.findGroup('flat'), isNotNull);
    expect(await db.groupsDao.getMembers('flat'), hasLength(2));
  });
}
