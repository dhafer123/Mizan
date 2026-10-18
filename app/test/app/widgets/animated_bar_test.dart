import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/animated_bar.dart';

Widget _app(double value, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: AnimatedBar(value: value, semanticsLabel: 'Food'),
    ),
  ),
);

double? _shown(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value;

void main() {
  testWidgets('grows to its value, then slides to a new one', (tester) async {
    await tester.pumpWidget(_app(0.6));
    expect(_shown(tester), 0);

    await tester.pump(AnimatedBar.duration ~/ 2);
    expect(_shown(tester), allOf(greaterThan(0), lessThan(0.6)));

    await tester.pumpAndSettle();
    expect(_shown(tester), 0.6);

    await tester.pumpWidget(_app(0.2));
    await tester.pump(AnimatedBar.duration ~/ 2);
    expect(_shown(tester), allOf(greaterThan(0.2), lessThan(0.6)));
    await tester.pumpAndSettle();
    expect(_shown(tester), 0.2);
  });

  testWidgets('a value over the limit fills the bar', (tester) async {
    await tester.pumpWidget(_app(1.3));
    await tester.pumpAndSettle();
    expect(_shown(tester), 1);
  });

  testWidgets('screen readers hear the final value only', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(0.45));
    await tester.pump(AnimatedBar.duration ~/ 4);

    expect(
      tester.getSemantics(find.byType(LinearProgressIndicator)),
      matchesSemantics(label: 'Food', value: '45%'),
    );
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('full at once with reduced motion', (tester) async {
    await tester.pumpWidget(_app(0.6, reduceMotion: true));

    expect(_shown(tester), 0.6);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
