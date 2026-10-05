/// Why balances cannot be turned into transfers. Both mean the balances did
/// not come from `ComputeBalances`.
enum SimplifyError {
  /// The balances do not sum to zero.
  notBalanced,

  /// The balances are in more than one currency.
  currencyMismatch,
}
