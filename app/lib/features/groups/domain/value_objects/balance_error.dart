/// Why balances cannot be computed from a group's rows. Each one means the
/// stored data is inconsistent: it is validated on save and by the server.
enum BalanceError {
  /// An expense, share or settlement is not in the group currency.
  currencyMismatch,

  /// An expense's shares do not add up to its amount.
  sharesDoNotMatchAmount,

  /// A settlement is zero, negative, or from a member to themselves.
  invalidSettlement,
}
