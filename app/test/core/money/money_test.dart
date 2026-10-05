import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/currency_mismatch_error.dart';
import 'package:mizan/core/money/money.dart';

import '../../support/money_generators.dart';

void main() {
  Money dt(int millimes) => Money(millimes, Currency.tnd);
  Money eur(int cents) => Money(cents, Currency.eur);

  group('arithmetic', () {
    test('adds and subtracts minor units', () {
      expect(dt(4500) + dt(500), dt(5000));
      expect(dt(4500) - dt(5000), dt(-500));
      expect(-dt(4500), dt(-4500));
    });

    test('abs and sign helpers', () {
      expect(dt(-4500).abs(), dt(4500));
      expect(dt(4500).abs(), dt(4500));
      expect(dt(-1).isNegative, isTrue);
      expect(dt(1).isPositive, isTrue);
      expect(Money.zero(Currency.tnd).isZero, isTrue);
    });

    test('sum of nothing is zero; sum adds everything', () {
      expect(Money.sum(const [], Currency.tnd), Money.zero(Currency.tnd));
      expect(Money.sum([dt(900), dt(120), dt(-60)], Currency.tnd), dt(960));
    });
  });

  group('comparison', () {
    test('orders by amount', () {
      expect(dt(1) < dt(2), isTrue);
      expect(dt(2) <= dt(2), isTrue);
      expect(dt(-1) > dt(-2), isTrue);
      expect(dt(2) >= dt(3), isFalse);
      expect([dt(3), dt(-1), dt(2)]..sort(), [dt(-1), dt(2), dt(3)]);
    });

    test('equality needs the same amount and currency', () {
      expect(dt(100), dt(100));
      expect(dt(100), isNot(eur(100)));
    });
  });

  group('currency mismatch', () {
    final mismatch = throwsA(
      isA<CurrencyMismatchError>()
          .having((e) => e.left, 'left', Currency.tnd)
          .having((e) => e.right, 'right', Currency.eur),
    );

    test('is an error for +, -, compare and sum', () {
      expect(() => dt(1) + eur(1), mismatch);
      expect(() => dt(1) - eur(1), mismatch);
      expect(() => dt(1) < eur(1), mismatch);
      expect(() => dt(1).compareTo(eur(1)), mismatch);
      expect(() => Money.sum([dt(1), eur(1)], Currency.tnd), mismatch);
    });

    test('names both currencies', () {
      expect(
        CurrencyMismatchError(Currency.tnd, Currency.eur).toString(),
        contains('TND with EUR'),
      );
    });
  });

  group('properties', () {
    final tnd = any.moneyIn(Currency.tnd);

    Glados2(tnd, tnd).test('addition is commutative', (a, b) {
      expect(a + b, b + a);
    });

    Glados3(tnd, tnd, tnd).test('addition is associative', (a, b, c) {
      expect((a + b) + c, a + (b + c));
    });

    Glados2(tnd, tnd).test('subtraction undoes addition', (a, b) {
      expect(a + b - b, a);
    });

    Glados(any.money).test('a + (-a) is zero', (a) {
      expect((a + -a).isZero, isTrue);
    });

    Glados(any.list(tnd)).test('sum matches adding minor units', (amounts) {
      final expected = amounts.fold<int>(0, (sum, m) => sum + m.minorUnits);
      expect(Money.sum(amounts, Currency.tnd).minorUnits, expected);
    });
  });
}
