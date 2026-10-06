import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/record_settlement.dart';
import 'package:mizan/features/groups/domain/usecases/reverse_settlement.dart';
import 'package:mizan/features/groups/domain/usecases/simplify_debts.dart';
import 'package:mizan/features/groups/domain/usecases/watch_group_balances.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeGroupRepository repo;
  late RecordSettlement record;
  late ReverseSettlement reverse;

  Money tnd(int dinars) => Money(dinars * 1000, Currency.tnd);

  Future<Map<String, int>> balances() async => (await WatchGroupBalances(repo)(
    'flat',
    currency: Currency.tnd,
  ).first).valueOrNull!.byMember.map((id, m) => MapEntry(id, m.minorUnits));

  setUp(() async {
    repo = FakeGroupRepository()
      ..groups.add(
        const Group(id: 'flat', name: 'Flat', currency: Currency.tnd),
      )
      ..members.addAll([
        for (final id in ['you', 'ali', 'sami'])
          Member(id: id, groupId: 'flat', displayName: id),
      ]);
    final ids = SequentialIdGenerator(prefix: 'r');
    final clock = FakeClock(DateTime.utc(2026, 10, 6));
    record = RecordSettlement(repo, ids, clock);
    reverse = ReverseSettlement(repo, ids, clock);
    // The worked example: +540 / -90 / -450.
    final add = AddSharedExpense(repo, ids, clock);
    const everyone = Split.equal({'you', 'ali', 'sami'});
    for (final (payer, dinars, split) in [
      ('you', 900, everyone),
      ('ali', 120, everyone),
      ('sami', 60, everyone),
      ('ali', 300, const Split.equal({'ali', 'sami'})),
    ]) {
      await add(
        groupId: 'flat',
        payerId: payer,
        amount: tnd(dinars),
        split: split,
      );
    }
  });

  test('recording every suggested payment brings every balance to 0', () async {
    final before = (await WatchGroupBalances(repo)(
      'flat',
      currency: Currency.tnd,
    ).first).valueOrNull!;
    final transfers = const SimplifyDebts()(before.byMember).valueOrNull!;
    expect(transfers, hasLength(2), reason: 'Sami → you 450, Ali → you 90');

    for (final t in transfers) {
      final paid = await record(
        groupId: 'flat',
        fromMemberId: t.fromMemberId,
        toMemberId: t.toMemberId,
        amount: t.amount,
      );
      expect(paid.isOk, isTrue, reason: '$paid');
    }

    expect(await balances(), {'ali': 0, 'sami': 0, 'you': 0});
  });

  test('a mistaken payment is undone once, by a reversal', () async {
    final paid = (await record(
      groupId: 'flat',
      fromMemberId: 'sami',
      toMemberId: 'you',
      amount: tnd(450),
    )).valueOrNull!;
    expect((await balances())['sami'], 0);

    final reversal = (await reverse(
      groupId: 'flat',
      settlementId: paid.id,
    )).valueOrNull!;

    expect((await balances())['sami'], -450000, reason: 'back to before');
    expect(
      (reversal.fromMemberId, reversal.toMemberId, reversal.reversesId),
      ('you', 'sami', paid.id),
    );
    // Neither the original (again) nor the reversal can be reversed.
    for (final id in [paid.id, reversal.id]) {
      final again = await reverse(groupId: 'flat', settlementId: id);
      expect(again.failureOrNull?.error, GroupError.notReversible);
    }
    expect(repo.settlements, hasLength(2), reason: 'insert-only');
  });

  test('refuses payments that make no sense', () async {
    Future<GroupError?> error(String from, String to, Money amount) async =>
        (await record(
          groupId: 'flat',
          fromMemberId: from,
          toMemberId: to,
          amount: amount,
        )).failureOrNull?.error;

    expect(await error('ali', 'ali', tnd(5)), GroupError.sameMember);
    expect(await error('ali', 'you', tnd(0)), GroupError.amountNotPositive);
    expect(await error('ali', 'nour', tnd(5)), GroupError.unknownMember);
    expect(
      await error('ali', 'you', const Money(5, Currency.eur)),
      GroupError.currencyMismatch,
    );
    expect(repo.settlements, isEmpty);
  });
}
