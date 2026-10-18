import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/haptics.dart';

import '../../support/record_haptics.dart';

Future<BuildContext> _context(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const SizedBox(),
    ),
  );
  return tester.element(find.byType(SizedBox));
}

void main() {
  testWidgets('each moment has its own feel', (tester) async {
    final played = recordHaptics(tester);
    final context = await _context(tester);

    Haptics.saved(context);
    Haptics.deleted(context);
    Haptics.settled(context);
    Haptics.tick(context);
    await tester.pump();

    expect(played, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  testWidgets('none with reduced motion', (tester) async {
    final played = recordHaptics(tester);
    final context = await _context(tester, reduceMotion: true);

    Haptics.saved(context);
    Haptics.tick(context);
    await tester.pump();

    expect(played, isEmpty);
  });

  testWidgets('none once the screen is gone', (tester) async {
    final played = recordHaptics(tester);
    final context = await _context(tester);
    await tester.pumpWidget(const Placeholder());

    Haptics.saved(context);
    await tester.pump();

    expect(played, isEmpty);
  });
}
