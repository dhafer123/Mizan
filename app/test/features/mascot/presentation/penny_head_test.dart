import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_mood.dart';
import 'package:mizan/features/mascot/presentation/penny_head.dart';

Widget _app(PennyMood mood, {int pokes = 0, bool reduceMotion = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: Center(
            child: PennyHead(mood: mood, pokes: pokes),
          ),
        ),
      ),
    );

void main() {
  testWidgets('every expression draws, in both themes', (tester) async {
    for (final dark in [false, true]) {
      for (final mood in PennyMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(body: PennyHead(mood: mood)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$mood');
      }
    }
  });

  testWidgets('she is decoration: nothing for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(PennyMood.happy));

    expect(
      find.semantics.byPredicate((node) => node.label.isNotEmpty),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('she comes alive in short bursts, so the screen settles', (
    tester,
  ) async {
    await tester.pumpWidget(_app(PennyMood.calm));
    await tester.pumpAndSettle();

    // A few idle bursts later she's still settling between them.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a mood change or a poke animates; with reduced motion they '
      'apply at once', (tester) async {
    await tester.pumpWidget(_app(PennyMood.calm));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(PennyMood.happy));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(PennyMood.happy, pokes: 1));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(PennyMood.calm, reduceMotion: true));
    await tester.pumpWidget(
      _app(PennyMood.worried, pokes: 2, reduceMotion: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
