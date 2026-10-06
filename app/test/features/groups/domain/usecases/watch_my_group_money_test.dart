import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/clock/year_month.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/budget/domain/usecases/compute_budget_overview.dart';
import 'package:mizan/features/budget/domain/usecases/compute_money_available.dart';
import 'package:mizan/features/expenses/domain/entities/default_categories.dart';
import 'package:mizan/features/groups/domain/entities/group.dart';
import 'package:mizan/features/groups/domain/entities/member.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/record_settlement.dart';
import 'package:mizan/features/groups/domain/usecases/watch_my_group_money.dart';
import 'package:mizan/features/groups/domain/value_objects/my_group_money.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../../support/fake_group_repository.dart';
import '../../../../support/sequential_id_generator.dart';

void main() {
  const me = 'u1';
  final today = DateTime.utc(2026, 10, 6);
  late FakeGroupRepository repo;
  late AddSharedExpense add;

  Money tnd(int dinars) => Money(dinars * 1000, Currency.tnd);

  Future<MyGroupMoney> mine({String? accountId = me}) async =>
      (await WatchMyGroupMoney(repo)(
        accountId: accountId,
        currency: Currency.tnd,
      ).first).valueOrNull!;

  setUp(() {
    repo = FakeGroupRepository()
      ..groups.add(
        const Group(id: 'flat', name: 'Flat', currency: Currency.tnd),
      )
      ..members.addAll(const [
        Member(id: 'm-me', groupId: 'flat', userId: me, displayName: 'Me'),
        Member(id: 'm-ali', groupId: 'flat', userId: 'u2', displayName: 'Ali'),
        Member(id: 'm-sami', groupId: 'flat', displayName: 'Sami'),
      ]);
    add = AddSharedExpense(
      repo,
      SequentialIdGenerator(prefix: 'e'),
      FakeClock(today),
    );
  });

  test('paying 900 rent for 3 adds 300 to my spending and 600 to '
      '"owed to me"', () async {
    await add(
      groupId: 'flat',
      payerId: 'm-me',
      amount: tnd(900),
      split: const Split.equal({'m-me', 'm-ali', 'm-sami'}),
      categoryId: DefaultCategories.rent.id,
    );

    final money = await mine();
    expect(money.owedToMe, tnd(600));
    expect(money.iOwe, tnd(0));

    // The budget screen and home dashboard count only my share.
    final month = YearMonth.of(today);
    final overview = const ComputeBudgetOverview()(
      month: month,
      currency: Currency.tnd,
      budgets: const [],
      categories: DefaultCategories.all,
      expenses: const [],
      shares: money.shares,
    );
    expect(overview.spent, tnd(300));
    expect(
      overview.categories
          .firstWhere((l) => l.category?.id == DefaultCategories.rent.id)
          .spent,
      tnd(300),
    );
    final available = const ComputeMoneyAvailable()(
      month: month,
      currency: Currency.tnd,
      incomes: const [],
      expenses: const [],
      today: today,
      shares: money.shares,
    );
    expect(available.spent, tnd(300), reason: 'not 900: the rest is owed');
  });

  test('being paid back lowers what is owed, not my spending', () async {
    await add(
      groupId: 'flat',
      payerId: 'm-me',
      amount: tnd(900),
      split: const Split.equal({'m-me', 'm-ali', 'm-sami'}),
    );
    await RecordSettlement(
      repo,
      SequentialIdGenerator(prefix: 'p'),
      FakeClock(today),
    )(
      groupId: 'flat',
      fromMemberId: 'm-ali',
      toMemberId: 'm-me',
      amount: tnd(300),
    );

    final money = await mine();
    expect(money.owedToMe, tnd(300));
    expect(money.shares.single.amount, tnd(300));
    expect(money.shares.single.categoryId, isNull);
  });

  test('when someone else pays, my share is spending and I owe it', () async {
    await add(
      groupId: 'flat',
      payerId: 'm-ali',
      amount: tnd(120),
      split: const Split.equal({'m-me', 'm-ali', 'm-sami'}),
    );

    final money = await mine();
    expect(money.shares.single.amount, tnd(40));
    expect((money.owedToMe, money.iOwe), (tnd(0), tnd(40)));
  });

  test(
    'signed out, or groups in another currency, count for nothing',
    () async {
      repo.groups.add(
        const Group(id: 'trip', name: 'Trip', currency: Currency.eur),
      );
      repo.members.add(
        const Member(
          id: 'm-me2',
          groupId: 'trip',
          userId: me,
          displayName: 'Me',
        ),
      );
      await add(
        groupId: 'trip',
        payerId: 'm-me2',
        amount: const Money(9000, Currency.eur),
        split: const Split.equal({'m-me2'}),
      );

      expect((await mine()).shares, isEmpty);
      expect((await mine(accountId: null)).owedToMe, tnd(0));
    },
  );
}
