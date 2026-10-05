/// Why an expense could not be saved, changed or read.
enum ExpenseError {
  /// The amount is zero or negative.
  amountNotPositive,

  /// No category was picked.
  noCategory,

  /// The note is longer than `ValidateExpense.maxNoteLength`.
  noteTooLong,

  /// The date is after today.
  dateInFuture,

  /// The expense does not exist or was deleted.
  notFound,

  /// The local database failed.
  storage,
}
