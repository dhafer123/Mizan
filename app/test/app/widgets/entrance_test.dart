import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/entrance.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('fades in, one after another', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            Entrance(child: Text('first')),
            Entrance(index: 3, child: Text('fourth')),
          ],
        ),
      ),
    );
    expect(_opacity(tester, 'first'), 0);

    await tester.pump(Entrance.length ~/ 2);
    expect(_opacity(tester, 'first'), greaterThan(0));
    expect(
      _opacity(tester, 'fourth'),
      lessThan(_opacity(tester, 'first')),
      reason: 'it waits its turn',
    );

    await tester.pumpAndSettle();
    expect(_opacity(tester, 'first'), 1);
    expect(_opacity(tester, 'fourth'), 1);
  });

  testWidgets('comes in once, not on every rebuild', (tester) async {
    await tester.pumpWidget(_app(const Entrance(child: Text('a'))));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(const Entrance(child: Text('b'))));
    expect(_opacity(tester, 'b'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('shown at once with reduced motion', (tester) async {
    await tester.pumpWidget(
      _app(const Entrance(index: 2, child: Text('a')), reduceMotion: true),
    );

    expect(_opacity(tester, 'a'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
