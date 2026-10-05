import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';
import 'package:mizan/features/groups/domain/value_objects/split_type.dart';

/// A valid input for `ComputeShares`: an amount, a split over a random subset
/// of the group, and the group's member ids.
class SplitCase {
  const SplitCase(this.amount, this.split, this.groupMemberIds);

  final Money amount;
  final Split split;
  final Set<String> groupMemberIds;

  @override
  String toString() => 'SplitCase($amount, $split, group: $groupMemberIds)';
}

extension SplitAnys on Any {
  Generator<SplitCase> get splitCase => combine4(
    // Tiny amounts (fewer minor units than people) and large ones.
    oneOf([intInRange(1, 20), intInRange(1, 10000000000)]),
    intInRange(1, 9),
    choose(SplitType.values),
    intInRange(0, 1 << 32),
    (int units, int participants, SplitType type, int seed) => buildSplitCase(
      Money(units, Currency.tnd),
      participants,
      type,
      Random(seed),
    ),
  );
}

SplitCase buildSplitCase(
  Money amount,
  int participantCount,
  SplitType type,
  Random random,
) {
  final ids = randomMemberIds(participantCount + random.nextInt(3), random);
  final participants = ids.take(participantCount).toList();
  return SplitCase(amount, buildSplit(amount, participants, type, random), ids);
}

/// [count] distinct random 8-hex-digit ids, in random order.
Set<String> randomMemberIds(int count, Random random) {
  final ids = <String>{};
  while (ids.length < count) {
    ids.add(random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
  }
  return ids;
}

/// A valid split of [amount] of the given [type] among [participants].
Split buildSplit(
  Money amount,
  List<String> participants,
  SplitType type,
  Random random,
) => switch (type) {
  SplitType.equal => Split.equal(participants.toSet()),
  SplitType.exact => Split.exact({
    for (final (i, part) in _partition(
      amount.minorUnits,
      participants.length,
      random,
    ).indexed)
      participants[i]: Money(part, amount.currency),
  }),
  SplitType.percentage => Split.percentage({
    for (final (i, part) in _partition(
      10000,
      participants.length,
      random,
    ).indexed)
      participants[i]: part,
  }),
  SplitType.shares => Split.shares(_weights(participants, random)),
};

/// [total] cut into [parts] non-negative integers at random points.
List<int> _partition(int total, int parts, Random random) {
  const resolution = 1 << 20;
  final cuts = [
    for (var i = 0; i < parts - 1; i++)
      total * random.nextInt(resolution + 1) ~/ resolution,
  ]..sort();
  final bounds = [0, ...cuts, total];
  return [for (var i = 0; i < parts; i++) bounds[i + 1] - bounds[i]];
}

/// Weights 0-10, at least one of them positive.
Map<String, int> _weights(List<String> ids, Random random) {
  final weights = {for (final id in ids) id: random.nextInt(11)};
  if (weights.values.every((w) => w == 0)) weights[ids.first] = 1;
  return weights;
}
