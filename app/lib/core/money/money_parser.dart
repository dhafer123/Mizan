import '../result/result.dart';
import 'currency.dart';
import 'money.dart';
import 'money_parse_error.dart';
import 'money_parse_failure.dart';

/// Reads typed or recognised amounts into [Money]. Use it only at the UI edge
/// (input fields, quick input); everything past that works with [Money].
///
/// Accepts "4.5", "4,500", "4.500 DT", "DT 4.5", "-4.5", "1 234,5",
/// "1,234.50", "1.234.567". The rules for separators:
/// - Both "." and "," present: the last one is the decimal separator.
/// - One of them, used several times: thousands grouping ("1.234.567").
/// - One of them, used once: decimal separator ("4,500" = 4.500 DT), except
///   "1,234" for a 2-decimal currency, which is grouping (1234.00 €).
/// - Spaces are always grouping.
class MoneyParser {
  const MoneyParser();

  static const _maxIntegerDigits = 12;

  static const _currencyTokens = <(String, Currency)>[
    ('tnd', Currency.tnd),
    ('د.ت', Currency.tnd),
    ('dt', Currency.tnd),
    ('eur', Currency.eur),
    ('€', Currency.eur),
    ('usd', Currency.usd),
    (r'$', Currency.usd),
  ];

  static final _numberChars = RegExp(r'^[0-9., ]+$');
  static final _digits = RegExp(r'^[0-9]*$');

  Result<Money, MoneyParseFailure> parse(
    String input, {
    required Currency currency,
  }) {
    Err<Money, MoneyParseFailure> fail(MoneyParseError error) =>
        Err(MoneyParseFailure(input, error, expected: currency));

    var text = input
        .replaceAll(' ', ' ') // no-break space
        .replaceAll(' ', ' ') // narrow no-break space
        .replaceAll('−', '-') // minus sign
        .trim()
        .toLowerCase();
    if (text.isEmpty) return fail(MoneyParseError.empty);

    // Sign may come before or after a leading currency token: "-4 DT", "DT -4".
    var negative = false;
    var signSeen = false;
    bool takeSign() {
      if (signSeen || text.isEmpty) return false;
      if (text[0] == '-' || text[0] == '+') {
        negative = text[0] == '-';
        signSeen = true;
        text = text.substring(1).trimLeft();
        return true;
      }
      return false;
    }

    takeSign();
    Currency? named;
    for (final (token, tokenCurrency) in _currencyTokens) {
      if (text.startsWith(token)) {
        text = text.substring(token.length).trim();
      } else if (text.endsWith(token)) {
        text = text.substring(0, text.length - token.length).trim();
      } else {
        continue;
      }
      named = tokenCurrency;
      break;
    }
    takeSign();

    if (text.isEmpty) return fail(MoneyParseError.empty);
    if (!_numberChars.hasMatch(text)) {
      return fail(MoneyParseError.invalidFormat);
    }

    final parts = _split(text, currency);
    if (parts == null) return fail(MoneyParseError.invalidFormat);
    var (integer, fraction) = parts;

    if (fraction.length > currency.decimals) {
      final extra = fraction.substring(currency.decimals);
      if (extra.replaceAll('0', '').isNotEmpty) {
        return fail(MoneyParseError.tooManyDecimals);
      }
      fraction = fraction.substring(0, currency.decimals);
    }

    integer = integer.replaceFirst(RegExp('^0+'), '');
    if (integer.length > _maxIntegerDigits) {
      return fail(MoneyParseError.tooLarge);
    }

    if (named != null && named != currency) {
      return fail(MoneyParseError.currencyMismatch);
    }

    final major = integer.isEmpty ? 0 : int.parse(integer);
    final minorDigits = fraction.padRight(currency.decimals, '0');
    final minor = minorDigits.isEmpty ? 0 : int.parse(minorDigits);
    final units = major * currency.minorPerMajor + minor;
    return Ok(Money(negative ? -units : units, currency));
  }

  /// Splits [text] (digits, ".", "," and spaces only) into integer and
  /// fraction digits, or null if it is malformed.
  (String, String)? _split(String text, Currency currency) {
    final dots = '.'.allMatches(text).length;
    final commas = ','.allMatches(text).length;

    String? decimal;
    if (dots > 0 && commas > 0) {
      decimal = text.lastIndexOf('.') > text.lastIndexOf(',') ? '.' : ',';
      if ((decimal == '.' ? dots : commas) > 1) return null;
    } else if (dots == 1 || commas == 1) {
      decimal = dots == 1 ? '.' : ',';
      final after = text.substring(text.indexOf(decimal) + 1);
      final before = text.substring(0, text.indexOf(decimal));
      final looksLikeGrouping =
          after.length == 3 &&
          !before.contains(' ') &&
          before.isNotEmpty &&
          before.length <= 3 &&
          currency.decimals < 3;
      if (looksLikeGrouping) decimal = null;
    }

    final integerText = decimal == null
        ? text
        : text.substring(0, text.indexOf(decimal));
    final fraction = decimal == null
        ? ''
        : text.substring(text.indexOf(decimal) + 1);
    if (!_digits.hasMatch(fraction)) return null;

    final groups = integerText.split(RegExp('[., ]'));
    if (groups.length > 1) {
      if (groups.first.isEmpty || groups.first.length > 3) return null;
      if (groups.skip(1).any((g) => g.length != 3)) return null;
    }
    final integer = groups.join();
    if (!_digits.hasMatch(integer)) return null;
    if (integer.isEmpty && fraction.isEmpty) return null;
    return (integer, fraction);
  }
}
