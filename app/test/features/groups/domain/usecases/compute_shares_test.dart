import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/groups/domain/usecases/compute_shares.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/groups/domain/value_objects/split_error.dart';
import 'package:mizan/features/groups/domain/value_objects/split_failure.dart';
import 'package:mizan/features/groups/domain/value_objects/split_type.dart';

import '../../../../support/split_generators.dart';

void main() {
  const computeShares = ComputeShares();
  const groupMembers = {'a', 'b', 'c', 'd'};

  Money dt(int millimes) => Money(millimes, Currency.tnd);

  /// Shares as plain millimes, or the error.
  Object run(int millimes, Split split, {Set<String> members = groupMembers}) =>
      switch (computeShares(dt(millimes), split, groupMemberIds: members)) {
        Ok(:final value) => value.map((id, m) => MapEntry(id, m.minorUnits)),
        Err(:final failure) => failure.error,
      };

  group('equal', () {
    test('100.000 DT three ways: the lowest id gets the extra millime', () {
      expect(run(100000, const Split.equal({'c', 'a', 'b'})), {
        'a': 33334,
        'b': 33333,
        'c': 33333,
      });
    });

    test('fewer millimes than people: lowest ids get one each', () {
      expect(run(2, const Split.equal({'b', 'c', 'a'})), {
        'a': 1,
        'b': 1,
        'c': 0,
      });
    });

    test('only the chosen subset pays', () {
      expect(run(9000, const Split.equal({'c', 'a'})), {'a': 4500, 'c': 4500});
    });

    test('result is sorted by member id', () {
      final shares = computeShares(
        dt(100),
        const Split.equal({'d', 'b', 'a'}),
        groupMemberIds: groupMembers,
      ).valueOrNull!;
      expect(shares.keys, ['a', 'b', 'd']);
    });
  });

  group('exact', () {
    test('keeps the entered amounts', () {
      final split = Split.exact({'b': dt(700), 'a': dt(300)});
      expect(run(1000, split), {'a': 300, 'b': 700});
    });

    test('allows a zero amount for someone included', () {
      final split = Split.exact({'a': dt(1000), 'b': dt(0)});
      expect(run(1000, split), {'a': 1000, 'b': 0});
    });

    test('rejects amounts that do not add up', () {
      final split = Split.exact({'a': dt(300), 'b': dt(600)});
      expect(run(1000, split), SplitError.exactSumMismatch);
    });

    test('rejects negative amounts even if the sum is right', () {
      final split = Split.exact({'a': dt(1200), 'b': dt(-200)});
      expect(run(1000, split), SplitError.negativeValue);
    });

    test('rejects another currency', () {
      const split = Split.exact({'a': Money(1000, Currency.eur)});
      expect(run(1000, split), SplitError.currencyMismatch);
    });
  });

  group('percentage', () {
    test('33.33 / 33.33 / 33.34 % of 100.000 DT', () {
      const split = Split.percentage({'a': 3333, 'b': 3333, 'c': 3334});
      expect(run(100000, split), {'a': 33330, 'b': 33330, 'c': 33340});
    });

    test('50 / 50 % of 0.001 DT: tie goes to the lowest id', () {
      const split = Split.percentage({'b': 5000, 'a': 5000});
      expect(run(1, split), {'a': 1, 'b': 0});
    });

    test('rejects percentages that are not 100%', () {
      expect(
        run(1000, const Split.percentage({'a': 5000, 'b': 4999})),
        SplitError.percentageSumMismatch,
      );
      expect(
        run(1000, const Split.percentage({'a': 10001})),
        SplitError.percentageSumMismatch,
      );
    });

    test('rejects a negative percentage', () {
      expect(
        run(1000, const Split.percentage({'a': 11000, 'b': -1000})),
        SplitError.negativeValue,
      );
    });
  });

  group('shares', () {
    test('2:1:1 of 10.000 DT', () {
      const split = Split.shares({'a': 2, 'b': 1, 'c': 1});
      expect(run(10000, split), {'a': 5000, 'b': 2500, 'c': 2500});
    });

    test('the largest remainder wins before the lowest id', () {
      // a is owed 1/3 of a millime, b 2/3: b gets it.
      const split = Split.shares({'a': 1, 'b': 2});
      expect(run(1, split), {'a': 0, 'b': 1});
    });

    test('a zero weight pays nothing but is listed', () {
      const split = Split.shares({'a': 1, 'b': 0});
      expect(run(1000, split), {'a': 1000, 'b': 0});
    });

    test('huge weights do not overflow', () {
      const split = Split.shares({'a': 1 << 40, 'b': 1 << 40});
      expect(run(10000000000000, split), {
        'a': 5000000000000,
        'b': 5000000000000,
      });
    });

    test('rejects all-zero and negative weights', () {
      expect(
        run(1000, const Split.shares({'a': 0, 'b': 0})),
        SplitError.zeroTotalWeight,
      );
      expect(
        run(1000, const Split.shares({'a': 2, 'b': -1})),
        SplitError.negativeValue,
      );
    });
  });

  group('validation for every split type', () {
    test('the amount must be positive', () {
      expect(run(0, const Split.equal({'a'})), SplitError.nonPositiveAmount);
      expect(run(-5, const Split.equal({'a'})), SplitError.nonPositiveAmount);
    });

    test('someone must be included', () {
      expect(run(1000, const Split.equal({})), SplitError.noParticipants);
      expect(run(1000, const Split.shares({})), SplitError.noParticipants);
    });

    test('everyone must be in the group', () {
      expect(
        run(1000, const Split.equal({'a', 'z'})),
        SplitError.unknownMember,
      );
      expect(run(1000, Split.exact({'z': dt(1000)})), SplitError.unknownMember);
    });

    test('every failure has a message for the UI', () {
      for (final error in SplitError.values) {
        expect(SplitFailure(error).message, isNotEmpty);
        expect(SplitFailure(error), SplitFailure(error));
        expect(SplitFailure(error).hashCode, SplitFailure(error).hashCode);
      }
    });
  });

  group('Split', () {
    test('reports its type and participants', () {
      expect(const Split.equal({'a'}).type, SplitType.equal);
      expect(Split.exact({'a': dt(1)}).type, SplitType.exact);
      expect(const Split.percentage({'a': 1}).type, SplitType.percentage);
      expect(const Split.shares({'a': 1, 'b': 0}).type, SplitType.shares);
      expect(const Split.shares({'a': 1, 'b': 0}).participants, {'a', 'b'});
    });
  });

  group('properties', () {
    final config = ExploreConfig(numRuns: 1000);

    Result<Map<String, Money>, SplitFailure> compute(SplitCase c) =>
        computeShares(c.amount, c.split, groupMemberIds: c.groupMemberIds);

    Glados(any.splitCase, config).test('shares always sum to the amount', (c) {
      final shares = compute(c).valueOrNull;
      expect(shares, isNotNull, reason: '$c');
      expect(Money.sum(shares!.values, c.amount.currency), c.amount);
    });

    Glados(any.splitCase, config).test('exactly the participants get a share', (
      c,
    ) {
      final shares = compute(c).valueOrNull!;
      expect(shares.keys.toSet(), c.split.participants);
      expect(shares.values.every((m) => !m.isNegative), isTrue);
    });

    Glados(any.splitCase, config).test(
      'deterministic: same result every time, whatever the input order',
      (c) {
        final reversed = SplitCase(c.amount, switch (c.split) {
          EqualSplit(:final memberIds) => Split.equal(
            memberIds.toList().reversed.toSet(),
          ),
          ExactSplit(:final amounts) => Split.exact(_reverse(amounts)),
          PercentageSplit(:final basisPoints) => Split.percentage(
            _reverse(basisPoints),
          ),
          SharesSplit(:final weights) => Split.shares(_reverse(weights)),
        }, c.groupMemberIds.toList().reversed.toSet());

        final first = compute(c).valueOrNull!;
        expect(compute(c).valueOrNull, first);
        expect(compute(reversed).valueOrNull, first);
        expect(compute(reversed).valueOrNull!.keys, first.keys);
      },
    );

    Glados(any.splitCase, config).test(
      'rounding moves each share by less than one minor unit',
      (c) {
        final weights = switch (c.split) {
          EqualSplit(:final memberIds) => {for (final id in memberIds) id: 1},
          PercentageSplit(:final basisPoints) => basisPoints,
          SharesSplit(:final weights) => weights,
          ExactSplit() => null,
        };
        if (weights == null) return;

        final total = BigInt.from(weights.values.fold<int>(0, (a, b) => a + b));
        final shares = compute(c).valueOrNull!;
        for (final MapEntry(key: id, value: share) in shares.entries) {
          final exact =
              BigInt.from(c.amount.minorUnits) * BigInt.from(weights[id]!);
          final floor = (exact ~/ total).toInt();
          expect(share.minorUnits, inInclusiveRange(floor, floor + 1));
        }
      },
    );
  });
}

Map<String, V> _reverse<V>(Map<String, V> map) =>
    Map.fromEntries(map.entries.toList().reversed);
