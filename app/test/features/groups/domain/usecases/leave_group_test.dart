import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/leave_group.dart';
import 'package:mizan/features/groups/domain/usecases/record_settlement.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/group_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeGroupRepository repo;
  late LeaveGroup leave;
  final ids = SequentialIdGenerator(prefix: 'r');
  final clock = FakeClock(DateTime.utc(2026, 10, 6));

  Money tnd(int dinars) => Money(dinars * 1000, Currency.tnd);

  GroupError? errorOf(Result<void, GroupFailure> result) => switch (result) {
    Ok() => null,
    Err(:final failure) => failure.error,
  };

  setUp(() {
    repo = FakeGroupRepository()
      ..groups.add(
        const Group(id: 'flat', name: 'Flat', currency: Currency.tnd),
      )
      ..members.addAll(const [
        Member(id: 'me', groupId: 'flat', userId: 'u1', displayName: 'Sami'),
        Member(id: 'ali', groupId: 'flat', userId: 'u2', displayName: 'Ali'),
      ]);
    leave = LeaveGroup(repo);
  });

  Future<void> spend({required String payer}) async {
    await AddSharedExpense(repo, ids, clock)(
      groupId: 'flat',
      payerId: payer,
      amount: tnd(90),
      split: const Split.equal({'me', 'ali'}),
    );
  }

  test('a member with nothing spent leaves', () async {
    final result = await leave(groupId: 'flat', accountId: 'u1');

    expect(result.isOk, isTrue);
    expect(repo.left, ['flat']);
  });

  test('a member who owes, or is owed, cannot leave', () async {
    await spend(payer: 'me'); // Ali owes me 45.

    final owed = await leave(groupId: 'flat', accountId: 'u1');
    final owes = await leave(groupId: 'flat', accountId: 'u2');

    expect(errorOf(owed), GroupError.balanceNotZero);
    expect(errorOf(owes), GroupError.balanceNotZero);
    expect(repo.left, isEmpty);
  });

  test('once settled up, both can leave', () async {
    await spend(payer: 'me');
    await RecordSettlement(repo, ids, clock)(
      groupId: 'flat',
      fromMemberId: 'ali',
      toMemberId: 'me',
      amount: tnd(45),
    );

    final result = await leave(groupId: 'flat', accountId: 'u2');

    expect(result.isOk, isTrue);
    expect(repo.left, ['flat']);
  });

  test('signed out, not in the group, or no such group: refused', () async {
    expect(
      errorOf(await leave(groupId: 'flat', accountId: null)),
      GroupError.signedOut,
    );
    expect(
      errorOf(await leave(groupId: 'flat', accountId: 'stranger')),
      GroupError.notFound,
    );
    expect(
      errorOf(await leave(groupId: 'nope', accountId: 'u1')),
      GroupError.notFound,
    );
    expect(repo.left, isEmpty);
  });

  test("the server's refusal comes through", () async {
    repo.leaveResult = const Err(GroupFailure(GroupError.offline));

    final result = await leave(groupId: 'flat', accountId: 'u1');

    expect(errorOf(result), GroupError.offline);
    expect(repo.groups, isNotEmpty);
  });
}
