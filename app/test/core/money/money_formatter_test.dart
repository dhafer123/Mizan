import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/core/money/money_formatter.dart';
import 'package:test/test.dart';

void main() {
  const formatter = MoneyFormatter();

  test('TND always shows 3 decimals and the symbol after', () {
    expect(formatter.format(const Money(4500, Currency.tnd)), '4.500 DT');
    expect(formatter.format(const Money(450, Currency.tnd)), '0.450 DT');
    expect(formatter.format(const Money(0, Currency.tnd)), '0.000 DT');
  });

  test('groups thousands', () {
    expect(
      formatter.format(const Money(1234500, Currency.tnd)),
      '1 234.500 DT',
    );
    expect(
      formatter.format(const Money(123456789000, Currency.tnd)),
      '123 456 789.000 DT',
    );
  });

  test('negative amounts lead with a minus', () {
    expect(formatter.format(const Money(-4500, Currency.tnd)), '-4.500 DT');
    expect(formatter.format(const Money(-1250, Currency.usd)), r'-$12.50');
  });

  test('symbol position follows the currency', () {
    expect(formatter.format(const Money(1250, Currency.eur)), '12.50 €');
    expect(formatter.format(const Money(1250, Currency.usd)), r'$12.50');
  });

  test('can omit the symbol', () {
    expect(
      formatter.format(const Money(-4500, Currency.tnd), withSymbol: false),
      '-4.500',
    );
  });

  test('separators are configurable', () {
    const fr = MoneyFormatter(decimalSeparator: ',', groupSeparator: '.');
    expect(fr.format(const Money(1234500, Currency.tnd)), '1.234,500 DT');
  });
}
