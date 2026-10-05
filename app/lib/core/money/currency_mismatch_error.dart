import 'currency.dart';

/// Thrown when two amounts in different currencies are combined.
///
/// This is an [Error], not a `Failure`: a group has one currency, so mixing
/// currencies in arithmetic is a programming bug, never a user mistake.
/// User input in the wrong currency is reported by `MoneyParser` as a
/// `MoneyParseFailure` instead.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError(this.left, this.right);

  final Currency left;
  final Currency right;

  @override
  String toString() =>
      'CurrencyMismatchError: cannot combine ${left.code} with ${right.code}';
}
