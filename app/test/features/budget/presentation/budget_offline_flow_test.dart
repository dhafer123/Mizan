import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/database_providers.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/core/clock/fake_clock.dart';

import '../../../support/sequential_id_generator.dart';
import '../../../support/test_database.dart';

/// Income, budget and spending on the real local database (task 2.4): the
/// budget screen shows money available and used / left per category.
void main() {
  testWidgets('income, budget, an expense: used and left per category', (
    tester,
  ) async {
    final clock = FakeClock(DateTime.utc(2026, 10, 6, 9));
    final ids = SequentialIdGenerator(prefix: 'id-');
    final db = openTestDatabase(ids: ids, clock: clock);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          idGeneratorProvider.overrideWithValue(ids),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MizanApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add your income to see what you can spend.'),
      findsOneWidget,
    );

    // Income.
    await tester.tap(find.byTooltip('Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add income'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Grant');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '450');
    await tester.enterText(
      find.widgetWithText(TextField, 'Day of the month'),
      '15',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Overall budget.
    await tester.tap(find.text('Set budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '600');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // A limit for Food.
    await tester.tap(find.widgetWithText(ListTile, 'Food'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly limit (optional)'),
      '150',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // An expense.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '120');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('available'))).data,
      '330.000 DT',
    );
    expect(
      find.text('Next income: Grant on Thu, Oct 15 (in 9 days)'),
      findsOneWidget,
    );
    expect(find.text('120.000 DT of 600.000 DT'), findsOneWidget);
    expect(find.text('480.000 DT left'), findsOneWidget);
    final food = find.widgetWithText(ListTile, 'Food');
    expect(
      find.descendant(
        of: food,
        matching: find.text('120.000 DT of 150.000 DT'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: food, matching: find.text('30.000 DT left')),
      findsOneWidget,
    );

    final outbox = await db.select(db.outbox).get();
    expect(outbox.map((op) => op.entity).toSet(), {
      'income_sources',
      'budgets',
      'categories',
      'expenses',
    });

    // Unmount so drift's query streams close, and let fake time run their
    // cleanup timers (and the close's) before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final closing = db.close();
    await tester.pump(const Duration(seconds: 1));
    await closing;
  });
}
