import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/failure.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/value_objects/group_error.dart';
import 'package:mizan/features/groups/domain/value_objects/group_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/groups/domain/value_objects/split_error.dart';
import 'package:mizan/features/groups/domain/value_objects/split_failure.dart';

import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  late FakeGroupRepository repo;
  late AddSharedExpense add;

  Money tnd(int millimes) => Money(millimes, Currency.tnd);

  setUp(() {
    repo = FakeGroupRepository()
      ..groups.add(const Group(id: 'g1', name: 'Flat', currency: Currency.tnd))
      ..members.addAll([
        for (final id in ['a', 'b', 'c'])
          Member(id: id, groupId: 'g1', displayName: id),
      ]);
    add = AddSharedExpense(
      repo,
      SequentialIdGenerator(prefix: 's'),
      FakeClock(DateTime.utc(2026, 10, 6, 23, 30)),
    );
  });

  test('stores the shares the split gives, dated today', () async {
    final result = await add(
      groupId: 'g1',
      payerId: 'a',
      amount: tnd(100000),
      split: const Split.equal({'a', 'b', 'c'}),
      categoryId: 'rent',
    );

    final saved = repo.expenses.single;
    expect(result.valueOrNull, saved);
    expect(saved.shares, {'a': tnd(33334), 'b': tnd(33333), 'c': tnd(33333)});
    expect(saved.date, DateTime.utc(2026, 10, 6));
    expect((saved.id, saved.categoryId), ('s1', 'rent'));
  });

  test('refuses what the group would not accept', () async {
    Future<Failure?> failure({
      String groupId = 'g1',
      String payerId = 'a',
      Money? amount,
      Split split = const Split.equal({'a', 'b'}),
    }) async => (await add(
      groupId: groupId,
      payerId: payerId,
      amount: amount ?? tnd(9000),
      split: split,
    )).failureOrNull;

    expect(
      await failure(groupId: 'gone'),
      const GroupFailure(GroupError.notFound),
    );
    expect(
      await failure(payerId: 'stranger'),
      const GroupFailure(GroupError.unknownMember),
    );
    expect(
      await failure(amount: const Money(9000, Currency.eur)),
      const SplitFailure(SplitError.currencyMismatch),
    );
    expect(
      await failure(split: const Split.equal({'a', 'stranger'})),
      const SplitFailure(SplitError.unknownMember),
    );
    expect(
      await failure(split: Split.exact({'a': tnd(5000), 'b': tnd(3000)})),
      const SplitFailure(SplitError.exactSumMismatch),
    );
    expect(repo.expenses, isEmpty);
  });
}
