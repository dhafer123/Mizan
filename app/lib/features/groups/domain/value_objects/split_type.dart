/// How a shared expense is divided. Stored with the expense.
enum SplitType {
  /// Everyone in the subset pays the same.
  equal,

  /// Each member's amount is entered directly.
  exact,

  /// Each member pays a percentage, in basis points (100% = 10000).
  percentage,

  /// Each member pays in proportion to a whole-number weight (2:1:1).
  shares,
}
