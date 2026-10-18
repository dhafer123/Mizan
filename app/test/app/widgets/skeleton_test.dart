import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/skeleton.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('shines while loading', (tester) async {
    await tester.pumpWidget(_app(const SkeletonList()));
    await tester.pump();

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('holds still with reduced motion', (tester) async {
    await tester.pumpWidget(
      _app(const SkeletonCards(heights: [100, 200]), reduceMotion: true),
    );
    await tester.pump();

    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(SkeletonBox), findsNWidgets(2));
  });

  testWidgets('stops shining when reduced motion is turned on', (tester) async {
    await tester.pumpWidget(_app(const SkeletonList()));
    await tester.pump();
    await tester.pumpWidget(_app(const SkeletonList(), reduceMotion: true));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('screen readers hear "Loading", not the shapes', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const SkeletonList(rows: 3)));

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });
}
