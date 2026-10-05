import '../result/failure.dart';
import 'currency.dart';
import 'money_parse_error.dart';

class MoneyParseFailure extends Failure {
  const MoneyParseFailure(this.input, this.error, {required this.expected});

  final String input;
  final MoneyParseError error;
  final Currency expected;

  @override
  String get message => switch (error) {
    MoneyParseError.empty => 'Enter an amount.',
    MoneyParseError.invalidFormat => '"$input" is not a valid amount.',
    MoneyParseError.tooManyDecimals =>
      '${expected.code} amounts have at most ${expected.decimals} decimals.',
    MoneyParseError.tooLarge => 'That amount is too large.',
    MoneyParseError.currencyMismatch => 'Amounts here are in ${expected.code}.',
  };

  @override
  bool operator ==(Object other) =>
      other is MoneyParseFailure &&
      other.input == input &&
      other.error == error &&
      other.expected == expected;

  @override
  int get hashCode => Object.hash(input, error, expected);
}
