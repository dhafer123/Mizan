/// Why a split cannot be applied to an expense.
enum SplitError {
  /// The expense amount is zero or negative.
  nonPositiveAmount,

  /// Nobody is included in the split.
  noParticipants,

  /// The split names someone who is not a member of the group.
  unknownMember,

  /// An exact amount, percentage or weight is below zero.
  negativeValue,

  /// An exact amount is in a different currency from the expense.
  currencyMismatch,

  /// Exact amounts do not add up to the expense amount.
  exactSumMismatch,

  /// Percentages do not add up to 100%.
  percentageSumMismatch,

  /// All weights are zero, so nobody would pay.
  zeroTotalWeight,
}
