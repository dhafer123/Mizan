import 'package:mizan/core/money/currency.dart';
import 'package:test/test.dart';

void main() {
  test('minor units per major unit follow the decimals', () {
    expect(Currency.tnd.minorPerMajor, 1000);
    expect(Currency.eur.minorPerMajor, 100);
  });

  test('looks up ISO codes case-insensitively', () {
    expect(Currency.fromCode('TND'), Currency.tnd);
    expect(Currency.fromCode('eur'), Currency.eur);
    expect(Currency.fromCode('XXX'), isNull);
  });
}
