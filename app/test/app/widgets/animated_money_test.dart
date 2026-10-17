import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/animated_money.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';

Widget _app(Money value, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: AnimatedMoney(value)),
  ),
);

void main() {
  const amount = Money(120000, Currency.tnd);

  testWidgets('counts up to the amount', (tester) async {
    await tester.pumpWidget(_app(amount));
    expect(find.text('0.000 DT'), findsOneWidget);

    await tester.pump(AnimatedMoney.duration ~/ 2);
    expect(find.text('120.000 DT'), findsNothing, reason: 'still counting');

    await tester.pumpAndSettle();
    expect(find.text('120.000 DT'), findsOneWidget);
  });

  testWidgets('counts from the old amount to a new one', (tester) async {
    await tester.pumpWidget(_app(amount));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(const Money(-5000, Currency.tnd)));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('-5.000 DT'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('-5.000 DT'), findsOneWidget);
  });

  testWidgets('with reduced motion, shows the amount at once', (tester) async {
    await tester.pumpWidget(_app(amount, reduceMotion: true));

    expect(find.text('120.000 DT'), findsOneWidget);
  });
}
