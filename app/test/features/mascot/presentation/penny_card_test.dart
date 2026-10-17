import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_mood.dart';
import 'package:mizan/features/mascot/presentation/penny_head.dart';
import 'package:mizan/features/mascot/presentation/penny_lines.dart';
import 'package:mizan/features/mascot/presentation/penny_providers.dart';

import '../../../support/app_harness.dart';

PennyMood _mood(WidgetTester tester) => tester
    .widget<PennyHead>(
      find.descendant(
        of: find.byKey(const ValueKey('pennyCard')),
        matching: find.byType(PennyHead),
      ),
    )
    .mood;

String _line(WidgetTester tester) {
  final texts = find.descendant(
    of: find.byKey(const ValueKey('pennyCard')),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(texts.last).data!;
}

void main() {
  Future<AppHarness> boot(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = AppHarness();
    await app.boot(tester);
    return app;
  }

  testWidgets('a new install: Penny is calm and asks about income', (
    tester,
  ) async {
    final app = await boot(tester);

    expect(_mood(tester), PennyMood.calm);
    expect(_line(tester).toLowerCase(), contains('income'));

    await app.shutDown(tester);
  });

  testWidgets('tapping her gets another line', (tester) async {
    final app = await boot(tester);
    final first = _line(tester);

    await tester.tap(find.byKey(const ValueKey('pennyCard')));
    await tester.pumpAndSettle();

    expect(_line(tester), isNot(first));
    expect(_line(tester).toLowerCase(), contains('income'));

    await app.shutDown(tester);
  });

  testWidgets('screen readers hear what she says', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await boot(tester);

    expect(
      find.semantics.byPredicate(
        (node) =>
            node.label.startsWith('Penny says') &&
            node.label.contains('income'),
      ),
      findsOne,
    );

    semantics.dispose();
    await app.shutDown(tester);
  });

  testWidgets('she cheers for the first expense of the month, then calms '
      'down', (tester) async {
    final app = await boot(tester);

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '4.5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(_mood(tester), PennyMood.excited);
    expect(
      _line(tester),
      PennyLines.forMoment(PennyMoment.firstOfMonth).single,
    );

    await tester.pump(PennyReaction.hold);
    await tester.pumpAndSettle();
    expect(_mood(tester), isNot(PennyMood.excited));

    await app.shutDown(tester);
  });

  testWidgets('the next expense gets a smaller cheer', (tester) async {
    final app = await boot(tester);

    for (final amount in ['4.5', '3']) {
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    expect(_mood(tester), PennyMood.happy);
    expect(PennyLines.forMoment(PennyMoment.logged), contains(_line(tester)));

    await tester.pump(PennyReaction.hold);
    await tester.pumpAndSettle();
    await app.shutDown(tester);
  });
}
