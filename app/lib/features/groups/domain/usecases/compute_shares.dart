import '../../../../core/money/money.dart';
import '../../../../core/result/result.dart';
import '../value_objects/split.dart';
import '../value_objects/split_error.dart';
import '../value_objects/split_failure.dart';

/// Works out what each participant owes for an expense.
///
/// Guarantees, for every successful result:
/// - the shares add up to exactly [amount];
/// - the result is the same on every device for the same input: equal,
///   percentage and shares splits use largest-remainder rounding, and ties go
///   to the lowest member id. 100.000 DT split 3 ways is 33.334 / 33.333 /
///   33.333.
///
/// The result maps each participant (sorted by id) to their share, including
/// members whose share is zero.
class ComputeShares {
  const ComputeShares();

  Result<Map<String, Money>, SplitFailure> call(
    Money amount,
    Split split, {
    required Set<String> groupMemberIds,
  }) {
    Err<Map<String, Money>, SplitFailure> fail(SplitError error) =>
        Err(SplitFailure(error));

    if (!amount.isPositive) return fail(SplitError.nonPositiveAmount);
    final participants = split.participants;
    if (participants.isEmpty) return fail(SplitError.noParticipants);
    if (!groupMemberIds.containsAll(participants)) {
      return fail(SplitError.unknownMember);
    }

    switch (split) {
      case EqualSplit(:final memberIds):
        return Ok(
          _largestRemainder(amount, {for (final id in memberIds) id: 1}),
        );

      case ExactSplit(:final amounts):
        if (amounts.values.any((m) => m.currency != amount.currency)) {
          return fail(SplitError.currencyMismatch);
        }
        if (amounts.values.any((m) => m.isNegative)) {
          return fail(SplitError.negativeValue);
        }
        if (Money.sum(amounts.values, amount.currency) != amount) {
          return fail(SplitError.exactSumMismatch);
        }
        final ids = amounts.keys.toList()..sort();
        return Ok(Map.unmodifiable({for (final id in ids) id: amounts[id]!}));

      case PercentageSplit(:final basisPoints):
        if (basisPoints.values.any((bp) => bp < 0)) {
          return fail(SplitError.negativeValue);
        }
        if (basisPoints.values.fold<int>(0, (a, b) => a + b) != 10000) {
          return fail(SplitError.percentageSumMismatch);
        }
        return Ok(_largestRemainder(amount, basisPoints));

      case SharesSplit(:final weights):
        if (weights.values.any((w) => w < 0)) {
          return fail(SplitError.negativeValue);
        }
        if (weights.values.every((w) => w == 0)) {
          return fail(SplitError.zeroTotalWeight);
        }
        return Ok(_largestRemainder(amount, weights));
    }
  }

  /// Splits [amount] in proportion to [weights] (all >= 0, total > 0).
  ///
  /// Each member first gets the rounded-down share; the minor units left over
  /// go one each to the members with the largest remainders, ties broken by
  /// lowest member id. BigInt keeps `amount * weight` exact for any weight.
  Map<String, Money> _largestRemainder(Money amount, Map<String, int> weights) {
    final ids = weights.keys.toList()..sort();
    final total = BigInt.from(weights.values.fold<int>(0, (a, b) => a + b));
    final units = BigInt.from(amount.minorUnits);

    final shares = <String, int>{};
    final remainders = <String, BigInt>{};
    var allocated = 0;
    for (final id in ids) {
      final product = units * BigInt.from(weights[id]!);
      shares[id] = (product ~/ total).toInt();
      remainders[id] = product.remainder(total);
      allocated += shares[id]!;
    }

    final byRemainder = [...ids]
      ..sort((a, b) {
        final byValue = remainders[b]!.compareTo(remainders[a]!);
        return byValue != 0 ? byValue : a.compareTo(b);
      });
    final leftover = amount.minorUnits - allocated;
    for (var i = 0; i < leftover; i++) {
      shares[byRemainder[i]] = shares[byRemainder[i]]! + 1;
    }

    return Map.unmodifiable({
      for (final id in ids) id: Money(shares[id]!, amount.currency),
    });
  }
}
