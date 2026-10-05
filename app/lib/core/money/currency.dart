/// Currencies the app knows. A group has exactly one currency (v1).
enum Currency {
  tnd(code: 'TND', decimals: 3, symbol: 'DT', symbolFirst: false),
  eur(code: 'EUR', decimals: 2, symbol: '€', symbolFirst: false),
  usd(code: 'USD', decimals: 2, symbol: r'$', symbolFirst: true);

  const Currency({
    required this.code,
    required this.decimals,
    required this.symbol,
    required this.symbolFirst,
  });

  /// ISO 4217 code.
  final String code;

  /// Digits after the decimal point: TND has 3 (1 DT = 1000 millimes).
  final int decimals;

  final String symbol;

  /// Whether the symbol is written before the amount (`$4.50`) or after it
  /// (`4.500 DT`).
  final bool symbolFirst;

  /// Minor units in one major unit, e.g. 1000 for TND.
  int get minorPerMajor {
    var factor = 1;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    return factor;
  }

  static Currency? fromCode(String code) {
    final upper = code.toUpperCase();
    for (final currency in values) {
      if (currency.code == upper) return currency;
    }
    return null;
  }
}
