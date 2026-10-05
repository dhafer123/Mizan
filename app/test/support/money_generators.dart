import 'package:glados/glados.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';

/// Amounts up to ±10 billion TND (±100 billion EUR): far past any real
/// amount, within the parser's 12 integer digits.
const maxTestMinorUnits = 10000000000000;

extension MoneyAnys on Any {
  Generator<Currency> get currency => choose(Currency.values);

  Generator<int> get minorUnits =>
      intInRange(-maxTestMinorUnits, maxTestMinorUnits + 1);

  Generator<Money> get money => combine2(minorUnits, currency, Money.new);

  /// Money in one fixed currency, so amounts can be combined.
  Generator<Money> moneyIn(Currency currency) =>
      minorUnits.map((units) => Money(units, currency));
}
