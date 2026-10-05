import 'package:freezed_annotation/freezed_annotation.dart';

import 'currency.dart';
import 'currency_mismatch_error.dart';

part 'money.freezed.dart';

/// An exact amount of money in integer minor units: 4.500 DT is
/// `Money(4500, Currency.tnd)`. Never use `double` for money.
///
/// Arithmetic and comparisons need both sides in the same currency and throw
/// [CurrencyMismatchError] otherwise. Parse and format only at the UI edge,
/// with `MoneyParser` and `MoneyFormatter`.
@freezed
abstract class Money with _$Money implements Comparable<Money> {
  const factory Money(int minorUnits, Currency currency) = _Money;

  const Money._();

  factory Money.zero(Currency currency) => Money(0, currency);

  /// Sums [amounts], all of which must be in [currency]. Empty gives zero.
  static Money sum(Iterable<Money> amounts, Currency currency) =>
      amounts.fold(Money.zero(currency), (total, amount) => total + amount);

  bool get isZero => minorUnits == 0;

  bool get isNegative => minorUnits < 0;

  bool get isPositive => minorUnits > 0;

  Money abs() => isNegative ? -this : this;

  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money(-minorUnits, currency);

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  void _checkSameCurrency(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }
}
