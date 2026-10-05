/// Why a text could not be read as an amount.
enum MoneyParseError {
  empty,
  invalidFormat,

  /// More decimals than the currency has, e.g. "4.5555" for TND.
  tooManyDecimals,
  tooLarge,

  /// The text names another currency, e.g. "12 €" in a TND group.
  currencyMismatch,
}
