/// The kinds of budget alert. At most one of each is sent a day.
enum AlertType {
  /// A category has used 80% or more of its monthly limit.
  categoryLimit,

  /// The forecast runs out before the next income.
  runOut,

  /// An expense far above what its category usually costs.
  unusualSpending,
}
