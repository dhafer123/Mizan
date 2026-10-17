// Visual check: every Penny expression on the light and dark pages, to
// test_shots/shots/penny_faces.png. Run: flutter test test_shots --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/theme/app_theme.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_mood.dart';
import 'package:mizan/features/mascot/presentation/penny_head.dart';

void main() {
  testWidgets('penny faces', (tester) async {
    debugDisableShadows = false;
    tester.view
      ..physicalSize = const Size(1600, 520)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Widget row(ThemeData theme) => Theme(
      data: theme,
      child: Builder(
        builder: (context) => ColoredBox(
          color: theme.colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final mood in PennyMood.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 84,
                      child: CustomPaint(
                        painter: PennyPainter(
                          mood: mood,
                          glow: theme.brightness == Brightness.dark,
                          pulse: 0.5,
                          float: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      mood.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Column(
          children: [
            Expanded(child: row(AppTheme.light())),
            Expanded(child: row(AppTheme.dark())),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/penny_faces.png'),
    );
    debugDisableShadows = true;
  });
}
