import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/groups/data/remote/groups_api.dart';
import 'package:mizan/features/groups/data/repositories/group_repository_impl.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/watch_group_balances.dart';
import 'package:mizan/features/groups/domain/usecases/watch_group_history.dart';
import 'package:mizan/features/groups/domain/value_objects/group_balances.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../support/fake_http_adapter.dart';
import '../../../support/sequential_id_generator.dart';
import '../../../support/test_database.dart';

MemberRow _member(String id, String groupId) => MemberRow(
  id: id,
  groupId: groupId,
  displayName: id,
  version: 0,
  deleted: false,
);

GroupRow _group(String id) =>
    GroupRow(id: id, name: id, currency: 'TND', version: 0, deleted: false);

void main() {
  late AppDatabase db;
  late GroupRepositoryImpl repo;

  setUp(() async {
    db = openTestDatabase();
    repo = GroupRepositoryImpl(
      db.groupsDao,
      db.sharedExpensesDao,
      GroupsApi(fakeDio(FakeHttpAdapter(FakeHttpAdapter.offline))),
    );
    await db.groupsDao.insertGroup(_group('flat'), _member('you', 'flat'));
    await db.groupsDao.insertMember(_member('ali', 'flat'));
    await db.groupsDao.insertMember(_member('sami', 'flat'));
  });
  tearDown(() => db.close());

  test('the worked example, stored and read back, gives the domain test '
      'balances: +540 / -90 / -450', () async {
    // The same data as compute_balances_test.dart's worked example.
    final add = AddSharedExpense(
      repo,
      SequentialIdGenerator(prefix: 'e'),
      FakeClock(DateTime.utc(2026, 10, 6)),
    );
    const everyone = Split.equal({'you', 'ali', 'sami'});
    for (final (payer, dinars, split) in [
      ('you', 900, everyone), // rent
      ('ali', 120, everyone), // groceries
      ('sami', 60, everyone), // internet
      ('ali', 300, const Split.equal({'ali', 'sami'})), // trip
    ]) {
      final added = await add(
        groupId: 'flat',
        payerId: payer,
        amount: Money(dinars * 1000, Currency.tnd),
        split: split,
      );
      expect(added.isOk, isTrue, reason: '$added');
    }

    final balances = (await WatchGroupBalances(repo)(
      'flat',
      currency: Currency.tnd,
      memberIds: {'you', 'ali', 'sami'},
    ).first).valueOrNull!;

    expect(balances.byMember.map((id, m) => MapEntry(id, m.minorUnits)), {
      'ali': -90000,
      'sami': -450000,
      'you': 540000,
    });
    expect(balances.of('you'), (
      Standing.owed,
      const Money(540000, Currency.tnd),
    ));
    expect(balances.of('sami'), (
      Standing.owes,
      const Money(450000, Currency.tnd),
    ));
  });

  test("history is the group's own, newest first", () async {
    await db.groupsDao.insertGroup(_group('trip'), _member('nour', 'trip'));
    Future<void> history(String id, String entity, String entityId, int seq) =>
        db
            .into(db.entityHistory)
            .insert(
              EntityHistoryCompanion.insert(
                id: id,
                entity: entity,
                entityId: entityId,
                field: '',
                kind: const Value('created'),
                serverSeq: Value(seq),
                changedAt: DateTime.utc(2026, 10, 6),
              ),
            );
    await history('h1', 'groups', 'flat', 1);
    await history('h2', 'members', 'ali', 2);
    await history('h3', 'members', 'nour', 3); // Another group.
    await history('h4', 'expenses', 'ali', 4); // A personal row.

    final entries = (await WatchGroupHistory(repo)('flat').first).valueOrNull!;

    expect(entries.map((e) => e.id), ['h2', 'h1']);
  });
}
