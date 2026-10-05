import '../../../../core/result/failure.dart';
import 'split_error.dart';

class SplitFailure extends Failure {
  const SplitFailure(this.error);

  final SplitError error;

  @override
  String get message => switch (error) {
    SplitError.nonPositiveAmount => 'The amount must be more than zero.',
    SplitError.noParticipants => 'Choose at least one person to split with.',
    SplitError.unknownMember => 'Someone in the split is not in this group.',
    SplitError.negativeValue =>
      'Amounts, percentages and shares cannot be negative.',
    SplitError.currencyMismatch => 'All amounts must be in the group currency.',
    SplitError.exactSumMismatch => 'The amounts must add up to the total.',
    SplitError.percentageSumMismatch => 'The percentages must add up to 100%.',
    SplitError.zeroTotalWeight =>
      'At least one person needs a share above zero.',
  };

  @override
  bool operator ==(Object other) =>
      other is SplitFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
