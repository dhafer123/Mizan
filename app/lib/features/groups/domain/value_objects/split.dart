import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';
import 'split_type.dart';

part 'split.freezed.dart';

/// The user's instructions for dividing an expense among some of the group's
/// members. Members left out of a split owe nothing for that expense.
@freezed
sealed class Split with _$Split {
  const Split._();

  /// Divide equally among [memberIds].
  const factory Split.equal(Set<String> memberIds) = EqualSplit;

  /// Each member owes exactly the given amount. The amounts must add up to the
  /// expense amount.
  const factory Split.exact(Map<String, Money> amounts) = ExactSplit;

  /// Each member owes a percentage, in basis points: 33.33% is 3333. They
  /// must add up to 10000 (100%).
  const factory Split.percentage(Map<String, int> basisPoints) =
      PercentageSplit;

  /// Each member owes in proportion to a whole-number weight (e.g. 2:1:1).
  const factory Split.shares(Map<String, int> weights) = SharesSplit;

  SplitType get type => switch (this) {
    EqualSplit() => SplitType.equal,
    ExactSplit() => SplitType.exact,
    PercentageSplit() => SplitType.percentage,
    SharesSplit() => SplitType.shares,
  };

  /// The members this split names.
  Set<String> get participants => switch (this) {
    EqualSplit(:final memberIds) => memberIds,
    ExactSplit(:final amounts) => amounts.keys.toSet(),
    PercentageSplit(:final basisPoints) => basisPoints.keys.toSet(),
    SharesSplit(:final weights) => weights.keys.toSet(),
  };
}
