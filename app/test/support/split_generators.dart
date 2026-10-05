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
  final ids = <String>{};
  final groupSize = participantCount + random.nextInt(3);
  while (ids.length < groupSize) {
    ids.add(random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
  }
  final participants = ids.take(participantCount).toList();

  final split = switch (type) {
    SplitType.equal => Split.equal(participants.toSet()),
    SplitType.exact => Split.exact({
      for (final (i, part) in _partition(
        amount.minorUnits,
        participantCount,
        random,
      ).indexed)
        participants[i]: Money(part, amount.currency),
    }),
    SplitType.percentage => Split.percentage({
      for (final (i, part) in _partition(
        10000,
        participantCount,
        random,
      ).indexed)
        participants[i]: part,
    }),
    SplitType.shares => Split.shares(_weights(participants, random)),
  };
  return SplitCase(amount, split, ids);
}

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
