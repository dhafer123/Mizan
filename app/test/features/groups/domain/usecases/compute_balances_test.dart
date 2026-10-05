import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/entities/settlement.dart';
import 'package:mizan/features/groups/domain/entities/shared_expense.dart';
import 'package:mizan/features/groups/domain/usecases/compute_balances.dart';
import 'package:mizan/features/groups/domain/usecases/compute_shares.dart';
import 'package:mizan/features/groups/domain/value_objects/balance_error.dart';
import 'package:mizan/features/groups/domain/value_objects/balance_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../../support/ledger_generators.dart';

const _you = 'you';
const _ali = 'ali';
const _sami = 'sami';
const _members = {_you, _ali, _sami};
final _date = DateTime.utc(2026, 10, 6);

Money _dt(int dinars) => Money(dinars * 1000, Currency.tnd);

SharedExpense _expense(String id, String payer, int dinars, Split split) {
  final amount = _dt(dinars);
  return SharedExpense(
    id: id,
    groupId: ledgerGroupId,
    payerId: payer,
    amount: amount,
    date: _date,
    split: split,
    shares: const ComputeShares()(
      amount,
      split,
      groupMemberIds: _members,
    ).valueOrNull!,
  );
}

Settlement _settlement(String id, String from, String to, int dinars) =>
    Settlement(
      id: id,
      groupId: ledgerGroupId,
      fromMemberId: from,
      toMemberId: to,
      amount: _dt(dinars),
      date: _date,
    );

void main() {
  const computeBalances = ComputeBalances();

  /// Balances in millimes, or the failure.
  Object run({
    List<SharedExpense> expenses = const [],
    List<Settlement> settlements = const [],
    Set<String> members = _members,
  }) => switch (computeBalances(
    currency: Currency.tnd,
    expenses: expenses,
    settlements: settlements,
    memberIds: members,
  )) {
    Ok(:final value) => value.map((id, m) => MapEntry(id, m.minorUnits)),
    Err(:final failure) => failure,
  };

  final rent = _expense('rent', _you, 900, const Split.equal(_members));
  final groceries = _expense(
    'groceries',
    _ali,
    120,
    const Split.equal(_members),
  );
  final internet = _expense('internet', _sami, 60, const Split.equal(_members));
  final trip = _expense('trip', _ali, 300, const Split.equal({_ali, _sami}));

  test('worked example: rent 900 / groceries 120 / internet 60 / trip 300 '
      '-> +540 / -90 / -450', () {
    expect(
      run(expenses: [rent, groceries, internet, trip]),
      _dinars({_ali: -90, _sami: -450, _you: 540}),
    );
  });

  test('worked example: paying the suggested transfers settles everyone', () {
    expect(
      run(
        expenses: [rent, groceries, internet, trip],
        settlements: [
          _settlement('s1', _sami, _you, 450),
          _settlement('s2', _ali, _you, 90),
        ],
      ),
      _dinars({_ali: 0, _sami: 0, _you: 0}),
    );
  });

  group('expenses', () {
    test('the payer is owed what others owe', () {
      expect(
        run(expenses: [rent]),
        _dinars({_ali: -300, _sami: -300, _you: 600}),
      );
    });

    test('paying for others only: the payer is owed everything', () {
      final gift = _expense('gift', _you, 100, const Split.equal({_ali}));
      expect(run(expenses: [gift]), _dinars({_ali: -100, _sami: 0, _you: 100}));
    });

    test('paying only for yourself changes nothing', () {
      final solo = _expense('solo', _you, 100, const Split.equal({_you}));
      expect(run(expenses: [solo]), _dinars({_ali: 0, _sami: 0, _you: 0}));
    });

    test('the rounding millime is owed by the lowest id', () {
      final odd = SharedExpense(
        id: 'odd',
        groupId: ledgerGroupId,
        payerId: _you,
        amount: const Money(100000, Currency.tnd),
        date: _date,
        split: const Split.equal(_members),
        shares: const ComputeShares()(
          const Money(100000, Currency.tnd),
          const Split.equal(_members),
          groupMemberIds: _members,
        ).valueOrNull!,
      );
      final balances = computeBalances(
        currency: Currency.tnd,
        expenses: [odd],
        settlements: const [],
      ).valueOrNull!;
      expect(balances.map((id, m) => MapEntry(id, m.minorUnits)), {
        _ali: -33334, // lowest id gets the extra millime
        _sami: -33333,
        _you: 66667,
      });
    });
  });

  group('settlements', () {
    test('paying back moves both balances toward zero', () {
      expect(
        run(expenses: [rent], settlements: [_settlement('s', _ali, _you, 300)]),
        _dinars({_ali: 0, _sami: -300, _you: 300}),
      );
    });

    test('a reversal cancels the original exactly', () {
      final original = _settlement('s1', _ali, _you, 300);
      final reversal = Settlement.reversal(original, id: 's2', date: _date);
      expect(
        run(expenses: [rent], settlements: [original, reversal]),
        run(expenses: [rent]),
      );
    });

    test('a reversal mirrors the original and points to it', () {
      final original = _settlement('s1', _ali, _you, 300);
      final later = _date.add(const Duration(days: 1));
      final reversal = Settlement.reversal(original, id: 's2', date: later);

      expect(reversal.id, 's2');
      expect(reversal.groupId, original.groupId);
      expect(reversal.fromMemberId, _you);
      expect(reversal.toMemberId, _ali);
      expect(reversal.amount, original.amount);
      expect(reversal.date, later);
      expect(reversal.reversesId, 's1');
      expect(original.reversesId, isNull);
    });
  });

  group('members', () {
    test('a group with no rows has all-zero balances', () {
      expect(run(), _dinars({_ali: 0, _sami: 0, _you: 0}));
    });

    test('someone named by a row but not in memberIds still counts', () {
      expect(
        run(expenses: [rent], members: const {}),
        _dinars({_ali: -300, _sami: -300, _you: 600}),
      );
    });

    test('the result is sorted by member id', () {
      final balances = computeBalances(
        currency: Currency.tnd,
        expenses: [trip, rent],
        settlements: const [],
        memberIds: const {'zed'},
      ).valueOrNull!;
      expect(balances.keys, [_ali, _sami, _you, 'zed']);
    });
  });

  group('inconsistent rows', () {
    BalanceFailure failure(BalanceError error, String id) =>
        BalanceFailure(error, recordId: id);

    test('expense in another currency', () {
      final euros = rent.copyWith(
        amount: const Money(900, Currency.eur),
        shares: {_you: const Money(900, Currency.eur)},
      );
      expect(
        run(expenses: [euros]),
        failure(BalanceError.currencyMismatch, 'rent'),
      );
    });

    test('a share in another currency', () {
      final mixed = rent.copyWith(
        shares: {...rent.shares, _ali: const Money(300000, Currency.eur)},
      );
      expect(
        run(expenses: [mixed]),
        failure(BalanceError.currencyMismatch, 'rent'),
      );
    });

    test('shares that do not add up to the amount', () {
      final broken = rent.copyWith(amount: _dt(901));
      expect(
        run(expenses: [broken]),
        failure(BalanceError.sharesDoNotMatchAmount, 'rent'),
      );
    });

    test('a settlement in another currency', () {
      final euros = _settlement(
        's',
        _ali,
        _you,
        1,
      ).copyWith(amount: const Money(100, Currency.eur));
      expect(
        run(settlements: [euros]),
        failure(BalanceError.currencyMismatch, 's'),
      );
    });

    test('a zero, negative or self settlement', () {
      for (final bad in [
        _settlement('zero', _ali, _you, 0),
        _settlement('negative', _ali, _you, -5),
        _settlement('self', _ali, _ali, 5),
      ]) {
        expect(
          run(settlements: [bad]),
          failure(BalanceError.invalidSettlement, bad.id),
        );
      }
    });

    test('every failure has a message for the UI', () {
      for (final error in BalanceError.values) {
        expect(failure(error, 'x').message, isNotEmpty);
        expect(failure(error, 'x').hashCode, failure(error, 'x').hashCode);
      }
    });
  });

  group('properties', () {
    final config = ExploreConfig(numRuns: 1000);

    Map<String, Money> balances(
      Ledger ledger, {
      Iterable<SharedExpense>? expenses,
      Iterable<Settlement>? settlements,
    }) => computeBalances(
      currency: Currency.tnd,
      expenses: expenses ?? ledger.expenses,
      settlements: settlements ?? ledger.settlements,
      memberIds: ledger.memberIds,
    ).valueOrNull!;

    Glados(any.ledger, config).test('balances always sum to 0', (ledger) {
      final result = balances(ledger);
      expect(Money.sum(result.values, Currency.tnd).isZero, isTrue);
    });

    Glados(any.ledger, config).test('the order of rows does not matter', (
      ledger,
    ) {
      expect(
        balances(
          ledger,
          expenses: ledger.expenses.reversed,
          settlements: ledger.settlements.reversed,
        ),
        balances(ledger),
      );
    });

    Glados(any.ledger, config).test(
      'reversing every settlement is the same as having none',
      (ledger) {
        var n = 0;
        final reversals = [
          for (final s in ledger.settlements)
            Settlement.reversal(s, id: 'r${n++}', date: s.date),
        ];
        expect(
          balances(ledger, settlements: [...ledger.settlements, ...reversals]),
          balances(ledger, settlements: const []),
        );
      },
    );

    Glados(any.ledger, config).test(
      'a settlement of X moves exactly X between the two members',
      (ledger) {
        final [from, to, ...] = ledger.memberIds.toList();
        final payment = Settlement(
          id: 'extra',
          groupId: ledgerGroupId,
          fromMemberId: from,
          toMemberId: to,
          amount: const Money(12345, Currency.tnd),
          date: _date,
        );
        final before = balances(ledger);
        final after = balances(
          ledger,
          settlements: [...ledger.settlements, payment],
        );
        for (final id in ledger.memberIds) {
          final delta = after[id]! - before[id]!;
          final expected = id == from
              ? payment.amount
              : id == to
              ? -payment.amount
              : Money.zero(Currency.tnd);
          expect(delta, expected, reason: id);
        }
      },
    );
  });
}

Map<String, int> _dinars(Map<String, int> dinars) =>
    dinars.map((id, d) => MapEntry(id, d * 1000));
