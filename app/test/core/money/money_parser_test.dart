import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/money/money_formatter.dart';
import 'package:mizan/core/money/money_parse_error.dart';
import 'package:mizan/core/money/money_parse_failure.dart';
import 'package:mizan/core/money/money_parser.dart';
import 'package:mizan/core/result/result.dart';

import '../../support/money_generators.dart';

void main() {
  const parser = MoneyParser();

  int? minor(String input, [Currency currency = Currency.tnd]) =>
      parser.parse(input, currency: currency).valueOrNull?.minorUnits;

  MoneyParseError? error(String input, [Currency currency = Currency.tnd]) =>
      parser.parse(input, currency: currency).failureOrNull?.error;

  group('TND (3 decimals)', () {
    test('"4.5", "4,500" and "4.500 DT" are all 4500 millimes', () {
      expect(minor('4.5'), 4500);
      expect(minor('4,500'), 4500);
      expect(minor('4.500 DT'), 4500);
    });

    final cases = <String, int>{
      '4': 4000,
      '0.450': 450,
      '.5': 500,
      ',25': 250,
      '4.': 4000,
      '007.5': 7500,
      '4.5dt': 4500,
      '4,5 DT': 4500,
      'DT 4.5': 4500,
      '4.5 TND': 4500,
      'tnd 12': 12000,
      '12 د.ت': 12000,
      '  4.5  ': 4500,
      '1 234,5': 1234500,
      '1 234.5': 1234500,
      '1,234.5': 1234500,
      '1.234,5': 1234500,
      '1.234.567': 1234567000,
      '1,234,567.250': 1234567250,
      '4.5000': 4500, // extra zeros are harmless
      '0': 0,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('"$input" -> $expected', () => expect(minor(input), expected));
    }
  });

  group('negative values', () {
    final cases = <String, int>{
      '-4.5': -4500,
      '- 4.5': -4500,
      '−4,500': -4500, // Unicode minus
      '-4.500 DT': -4500,
      'DT -4.5': -4500,
      '-DT 4.5': -4500,
      '+4.5': 4500,
      '-0': 0,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('"$input" -> $expected', () => expect(minor(input), expected));
    }

    test('only one sign is allowed', () {
      expect(error('--4'), MoneyParseError.invalidFormat);
      expect(error('-DT -4'), MoneyParseError.invalidFormat);
    });
  });

  group('2-decimal currencies', () {
    test('a single separator before 1-2 digits is the decimal point', () {
      expect(minor('12.5', Currency.eur), 1250);
      expect(minor('12,50 €', Currency.eur), 1250);
      expect(minor(r'$12.50', Currency.usd), 1250);
    });

    test('a single separator before exactly 3 digits is grouping', () {
      expect(minor('1,234', Currency.eur), 123400);
      expect(minor('1.234 EUR', Currency.eur), 123400);
    });

    test('3 decimals with mixed separators is too precise', () {
      expect(error('1,234.567', Currency.eur), MoneyParseError.tooManyDecimals);
    });
  });

  group('currency mismatch', () {
    test('a TND field rejects euros and dollars', () {
      expect(error('12 €'), MoneyParseError.currencyMismatch);
      expect(error('EUR 12'), MoneyParseError.currencyMismatch);
      expect(error(r'$12'), MoneyParseError.currencyMismatch);
    });

    test('a EUR field rejects dinars', () {
      expect(error('12 DT', Currency.eur), MoneyParseError.currencyMismatch);
    });

    test('the failure says which currency is expected', () {
      final failure = parser
          .parse('12 €', currency: Currency.tnd)
          .failureOrNull!;
      expect(failure.message, 'Amounts here are in TND.');
      expect(failure.input, '12 €');
    });
  });

  group('invalid input', () {
    final cases = <String, MoneyParseError>{
      '': MoneyParseError.empty,
      '   ': MoneyParseError.empty,
      'DT': MoneyParseError.empty,
      '-': MoneyParseError.empty,
      'abc': MoneyParseError.invalidFormat,
      '4.5.6,7': MoneyParseError.invalidFormat,
      '4,5,6.7': MoneyParseError.invalidFormat,
      '1.23.456': MoneyParseError.invalidFormat,
      '12345.678.9': MoneyParseError.invalidFormat,
      '1 23': MoneyParseError.invalidFormat,
      '.': MoneyParseError.invalidFormat,
      '4 DT 5': MoneyParseError.invalidFormat,
      '4.5x': MoneyParseError.invalidFormat,
      '1e3': MoneyParseError.invalidFormat,
      '4.5555': MoneyParseError.tooManyDecimals,
      '1234567890123': MoneyParseError.tooLarge,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('"$input" -> ${expected.name}', () {
        expect(error(input), expected);
      });
    }

    test('every failure has a message for the UI', () {
      for (final e in MoneyParseError.values) {
        final failure = MoneyParseFailure('x', e, expected: Currency.tnd);
        expect(failure.message, isNotEmpty);
      }
    });

    test('failures are values', () {
      expect(
        parser.parse('abc', currency: Currency.tnd),
        const Err<Money, MoneyParseFailure>(
          MoneyParseFailure(
            'abc',
            MoneyParseError.invalidFormat,
            expected: Currency.tnd,
          ),
        ),
      );
    });
  });

  group('properties', () {
    const formatters = [
      MoneyFormatter(),
      MoneyFormatter(decimalSeparator: ',', groupSeparator: '.'),
      MoneyFormatter(decimalSeparator: '.', groupSeparator: ','),
      MoneyFormatter(decimalSeparator: ',', groupSeparator: ' '),
    ];

    Glados2(any.money, any.choose(formatters)).test('parse(format(m)) == m', (
      money,
      formatter,
    ) {
      for (final withSymbol in [true, false]) {
        final text = formatter.format(money, withSymbol: withSymbol);
        expect(
          parser.parse(text, currency: money.currency),
          Ok<Money, MoneyParseFailure>(money),
          reason: text,
        );
      }
    });
  });
}
