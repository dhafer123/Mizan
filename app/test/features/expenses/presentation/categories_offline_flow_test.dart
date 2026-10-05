import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/database_providers.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../support/sequential_id_generator.dart';
import '../../../support/test_database.dart';

/// Categories on the real local database: create, rename and archive, and
/// an archived category keeps its expenses (task 2.3).
void main() {
  testWidgets('create, rename and archive a category; history stays', (
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
    await tester.tap(find.byTooltip('Expenses'));
    await tester.pumpAndSettle();

    // Create.
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Gym');
    await tester.tap(find.byKey(const ValueKey('icon-sport')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Archive Gym'), findsOneWidget);

    // Rename.
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Fitness');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsNothing);
    expect(find.byTooltip('Archive Fitness'), findsOneWidget);

    // An expense in it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fitness'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Fitness'), findsOneWidget);

    // Archive it.
    await tester.tap(find.byTooltip('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive Fitness'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The expense keeps its category name and icon...
    expect(find.widgetWithText(ListTile, 'Fitness'), findsOneWidget);
    expect(find.text('25.000 DT'), findsNWidgets(2));
    // ...but new expenses can't be filed under it.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Fitness'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Food'), findsOneWidget);

    final categoryOps = (await db.select(db.outbox).get())
        .where((op) => op.entity == 'categories')
        .toList();
    expect(categoryOps.map((op) => op.opType), [
      OutboxOpType.create,
      OutboxOpType.update,
      OutboxOpType.update,
    ]);
    expect(jsonDecode(categoryOps[1].changedFields), {'name': 'Fitness'});
    expect(jsonDecode(categoryOps[2].changedFields), {'archived': true});
    final expense = (await db.select(db.expenses).get()).single;
    expect(expense.categoryId, categoryOps.first.entityId);

    // Unmount so drift's query streams close, and let fake time run their
    // cleanup timers (and the close's) before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final closing = db.close();
    await tester.pump(const Duration(seconds: 1));
    await closing;
  });
}
