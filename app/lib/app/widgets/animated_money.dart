import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/money/money_formatter.dart';

/// An amount that counts up to its value when it first shows, and from the
/// old value to the new one when it changes. In whole minor units (an
/// [IntTween]), so no doubles touch the money. Shown at once when the phone
/// asks for reduced motion.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {this.style, this.textKey, super.key});

  final Money value;
  final TextStyle? style;

  /// Put on the [Text], so tests can read the shown amount.
  final Key? textKey;

  static const duration = Duration(milliseconds: 700);
  static const _format = MoneyFormatter();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(_format.format(value), key: textKey, style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value.minorUnits),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, minor, _) => Text(
        _format.format(Money(minor, value.currency)),
        key: textKey,
        style: style,
      ),
    );
  }
}
