/// Why an income source or budget could not be saved or read.
enum BudgetError {
  nameEmpty,

  /// Longer than `ValidateIncomeSource.maxNameLength`.
  nameTooLong,

  /// The income amount is zero or negative.
  amountNotPositive,

  /// A monthly day outside 1-31.
  invalidDay,

  /// The overall limit is zero or negative.
  limitNotPositive,

  /// The income source does not exist or was deleted.
  notFound,

  /// The local database failed.
  storage,
}
