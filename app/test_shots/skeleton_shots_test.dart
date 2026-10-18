// Visual check: the loading skeletons mid-shine, in both themes, to
// test_shots/shots/. Run: flutter test test_shots --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/theme/app_theme.dart';
import 'package:mizan/app/widgets/skeleton.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    for (final (kind, skeleton) in [
      ('cards', const SkeletonCards(heights: [96, 200, 120, 280, 200])),
      ('list', const SkeletonList()),
    ]) {
      testWidgets('skeleton_${name}_$kind', (tester) async {
        tester.view
          ..physicalSize = const Size(1080, 2340)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: skeleton),
          ),
        );
        // The shine a third of the way across.
        await tester.pump(Skeleton.shine * 0.4);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/skeleton_${name}_$kind.png'),
        );
      });
    }
  }
}
