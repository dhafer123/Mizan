import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/groups/domain/entities/settlement.dart';
import 'package:mizan/features/groups/domain/entities/shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/compute_shares.dart';
import 'package:mizan/features/groups/domain/value_objects/split_type.dart';

import 'split_generators.dart';

const ledgerGroupId = 'group';

/// A group's live rows: members, expenses and settlements (some of which
/// are reversals of others).
class Ledger {
  const Ledger(this.memberIds, this.expenses, this.settlements);

  final Set<String> memberIds;
  final List<SharedExpense> expenses;
  final List<Settlement> settlements;

  @override
  String toString() =>
      'Ledger(members: $memberIds, expenses: $expenses, '
      'settlements: $settlements)';
}

extension LedgerAnys on Any {
  Generator<Ledger> get ledger => combine3(
    intInRange(2, 7),
    intInRange(0, 16),
    intInRange(0, 1 << 32),
    (int members, int expenses, int seed) =>
        buildLedger(members, expenses, Random(seed)),
  );
}

Ledger buildLedger(int memberCount, int expenseCount, Random random) {
  const computeShares = ComputeShares();
  final members = randomMemberIds(memberCount, random).toList();
  final start = DateTime.utc(2026, 10, 1);
  var nextId = 0;

  final expenses = <SharedExpense>[];
  for (var i = 0; i < expenseCount; i++) {
    final amount = Money(1 + random.nextInt(2000000), Currency.tnd);
    final participants = ([
      ...members,
    ]..shuffle(random)).take(1 + random.nextInt(members.length)).toList();
    final type = SplitType.values[random.nextInt(SplitType.values.length)];
    final split = buildSplit(amount, participants, type, random);
    final shares = computeShares(
      amount,
      split,
      groupMemberIds: members.toSet(),
    ).valueOrNull!;
    expenses.add(
      SharedExpense(
        id: 'e${nextId++}',
        groupId: ledgerGroupId,
        payerId: members[random.nextInt(members.length)],
        amount: amount,
        date: start.add(Duration(days: i)),
        split: split,
        shares: shares,
      ),
    );
  }

  final settlements = <Settlement>[];
  for (var i = random.nextInt(7); i > 0; i--) {
    final pair = ([...members]..shuffle(random)).take(2).toList();
    final settlement = Settlement(
      id: 's${nextId++}',
      groupId: ledgerGroupId,
      fromMemberId: pair[0],
      toMemberId: pair[1],
      amount: Money(1 + random.nextInt(500000), Currency.tnd),
      date: start.add(Duration(days: i)),
    );
    settlements.add(settlement);
    if (random.nextInt(3) == 0) {
      settlements.add(
        Settlement.reversal(
          settlement,
          id: 's${nextId++}',
          date: settlement.date.add(const Duration(hours: 1)),
        ),
      );
    }
  }

  return Ledger(members.toSet(), expenses, settlements);
}
