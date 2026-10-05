import 'money.dart';

/// Turns [Money] into display text: "1 234.500 DT", "-4.500 DT", "$12.50".
/// Use it only at the UI edge. Its output can always be read back by
/// `MoneyParser`.
class MoneyFormatter {
  const MoneyFormatter({this.decimalSeparator = '.', this.groupSeparator = ' '})
    : assert(decimalSeparator != groupSeparator);

  final String decimalSeparator;
  final String groupSeparator;

  String format(Money money, {bool withSymbol = true}) {
    final currency = money.currency;
    final units = money.minorUnits.abs();
    final major = units ~/ currency.minorPerMajor;
    final minor = units % currency.minorPerMajor;

    final buffer = StringBuffer(_group(major.toString()));
    if (currency.decimals > 0) {
      buffer
        ..write(decimalSeparator)
        ..write(minor.toString().padLeft(currency.decimals, '0'));
    }
    final number = buffer.toString();
    final sign = money.isNegative ? '-' : '';

    if (!withSymbol) return '$sign$number';
    return currency.symbolFirst
        ? '$sign${currency.symbol}$number'
        : '$sign$number ${currency.symbol}';
  }

  String _group(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(groupSeparator);
      out.write(digits[i]);
    }
    return out.toString();
  }
}
