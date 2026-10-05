import 'dart:math' show max;

import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/entities/settlement.dart';
import 'package:mizan/features/groups/domain/usecases/compute_balances.dart';
import 'package:mizan/features/groups/domain/usecases/simplify_debts.dart';
import 'package:mizan/features/groups/domain/value_objects/simplify_error.dart';
import 'package:mizan/features/groups/domain/value_objects/simplify_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/transfer.dart';

import '../../../../support/ledger_generators.dart';
import '../../../../support/split_generators.dart';

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

Map<String, Money> _balances(Map<String, int> dinars) =>
    dinars.map((id, d) => MapEntry(id, _dt(d)));

/// Random balances that sum to zero: 1-10 members, some of them at zero,
/// with frequent ties.
extension _BalanceAnys on Any {
  Generator<Map<String, Money>> get balances => combine2(
    intInRange(1, 11),
    intInRange(0, 1 << 32),
    (int count, int seed) {
      final random = Random(seed);
      final ids = randomMemberIds(count, random).toList();
      final maxUnits = random.nextBool() ? 5 : 100000000;
      final units = [
        for (var i = 0; i < count - 1; i++)
          random.nextInt(4) == 0
              ? 0
              : random.nextInt(2 * maxUnits + 1) - maxUnits,
      ];
      units.add(-units.fold<int>(0, (a, b) => a + b));
      return {
        for (final (i, id) in ids.indexed) id: Money(units[i], Currency.tnd),
      };
    },
  );
}

void main() {
  const simplifyDebts = SimplifyDebts();

  List<Transfer> run(Map<String, Money> balances) =>
      simplifyDebts(balances).valueOrNull!;

  /// The balances after everyone makes their transfers.
  Map<String, Money> apply(
    Map<String, Money> balances,
    List<Transfer> transfers,
  ) {
    final result = {...balances};
    for (final t in transfers) {
      result[t.fromMemberId] = result[t.fromMemberId]! + t.amount;
      result[t.toMemberId] = result[t.toMemberId]! - t.amount;
    }
    return result;
  }

  test('worked example gives 2 transfers: Sami -> you 450, Ali -> you 90', () {
    final balances = _balances({'you': 540, 'ali': -90, 'sami': -450});
    expect(run(balances), [
      Transfer(fromMemberId: 'sami', toMemberId: 'you', amount: _dt(450)),
      Transfer(fromMemberId: 'ali', toMemberId: 'you', amount: _dt(90)),
    ]);
  });

  test('biggest debtor pays biggest creditor first', () {
    final balances = _balances({'a': 70, 'b': 30, 'c': -60, 'd': -40});
    expect(run(balances), [
      Transfer(fromMemberId: 'c', toMemberId: 'a', amount: _dt(60)),
      Transfer(fromMemberId: 'd', toMemberId: 'b', amount: _dt(30)),
      Transfer(fromMemberId: 'd', toMemberId: 'a', amount: _dt(10)),
    ]);
  });

  test('ties go to the lowest member id', () {
    final balances = _balances({'d': -50, 'c': -50, 'b': 50, 'a': 50});
    expect(run(balances), [
      Transfer(fromMemberId: 'c', toMemberId: 'a', amount: _dt(50)),
      Transfer(fromMemberId: 'd', toMemberId: 'b', amount: _dt(50)),
    ]);
  });

  test('nothing to do when everyone is settled', () {
    expect(run(const {}), isEmpty);
    expect(run(_balances({'a': 0, 'b': 0})), isEmpty);
  });

  test('rejects balances that do not sum to zero', () {
    expect(
      simplifyDebts(_balances({'a': 10, 'b': -9})),
      const Err<List<Transfer>, SimplifyFailure>(
        SimplifyFailure(SimplifyError.notBalanced),
      ),
    );
  });

  test('rejects mixed currencies', () {
    expect(
      simplifyDebts({
        'a': const Money(100, Currency.tnd),
        'b': const Money(-100, Currency.eur),
      }).failureOrNull?.error,
      SimplifyError.currencyMismatch,
    );
  });

  test('every failure has a message for the UI', () {
    for (final error in SimplifyError.values) {
      expect(SimplifyFailure(error).message, isNotEmpty);
      expect(SimplifyFailure(error).hashCode, SimplifyFailure(error).hashCode);
    }
  });

  group('properties', () {
    final config = ExploreConfig(numRuns: 1000);

    Glados(any.balances, config).test(
      'at most n - 1 transfers for n non-zero balances',
      (balances) {
        final nonZero = balances.values.where((m) => !m.isZero).length;
        final transfers = run(balances);
        expect(transfers.length, lessThanOrEqualTo(max(0, nonZero - 1)));
        expect(transfers.length, lessThanOrEqualTo(balances.length - 1));
      },
    );

    Glados(any.balances, config).test(
      'applying the transfers zeroes every balance',
      (balances) {
        final after = apply(balances, run(balances));
        expect(after.values.every((m) => m.isZero), isTrue, reason: '$after');
      },
    );

    Glados(any.balances, config).test(
      'debtors only pay, creditors only receive, amounts are positive',
      (balances) {
        for (final t in run(balances)) {
          expect(t.amount.isPositive, isTrue);
          expect(balances[t.fromMemberId]!.isNegative, isTrue);
          expect(balances[t.toMemberId]!.isPositive, isTrue);
        }
      },
    );

    Glados(any.balances, config).test(
      'deterministic, whatever the order of the balances',
      (balances) {
        final reversed = Map.fromEntries(balances.entries.toList().reversed);
        expect(run(reversed), run(balances));
      },
    );

    Glados(any.ledger, config).test(
      'recording the transfers as settlements settles a real group',
      (ledger) {
        const computeBalances = ComputeBalances();
        final before = computeBalances(
          currency: Currency.tnd,
          expenses: ledger.expenses,
          settlements: ledger.settlements,
          memberIds: ledger.memberIds,
        ).valueOrNull!;
        final transfers = run(before);
        expect(
          transfers.length,
          lessThanOrEqualTo(ledger.memberIds.length - 1),
        );

        var n = 0;
        final payments = [
          for (final t in transfers)
            Settlement(
              id: 'pay${n++}',
              groupId: ledgerGroupId,
              fromMemberId: t.fromMemberId,
              toMemberId: t.toMemberId,
              amount: t.amount,
              date: DateTime.utc(2026, 11),
            ),
        ];
        final after = computeBalances(
          currency: Currency.tnd,
          expenses: ledger.expenses,
          settlements: [...ledger.settlements, ...payments],
          memberIds: ledger.memberIds,
        ).valueOrNull!;
        expect(after.values.every((m) => m.isZero), isTrue);
      },
    );
  });
}
