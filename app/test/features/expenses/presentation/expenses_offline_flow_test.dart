import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/database_providers.dart';
import 'package:mizan/app/di/settings_providers.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/sync/data/db/outbox_op_type.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_biometric_authenticator.dart';
import '../../../support/fake_lock_settings_repository.dart';
import '../../../support/sequential_id_generator.dart';
import '../../../support/test_database.dart';

/// The whole expenses flow on the real local database, with no network:
/// add, edit, delete with undo, and delete. Every change must be queued in
/// the outbox for a later sync.
void main() {
  testWidgets('add, edit and delete an expense offline', (tester) async {
    final clock = FakeClock(DateTime.utc(2026, 10, 6, 9));
    final ids = SequentialIdGenerator(prefix: 'id-');
    final db = openTestDatabase(ids: ids, clock: clock);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          idGeneratorProvider.overrideWithValue(ids),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          appDatabaseProvider.overrideWithValue(db),
          lockSettingsRepositoryProvider.overrideWithValue(
            FakeLockSettingsRepository(),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MizanApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('No expenses this month'), findsOneWidget);

    // Add.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '4.5');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'coffee',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'coffee'), findsOneWidget);
    expect(find.text('4.500 DT'), findsNWidgets(2)); // day total and row

    // Edit.
    await tester.tap(find.text('coffee'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('5.000 DT'), findsNWidgets(2));

    // Delete, then undo.
    await tester.drag(find.text('coffee'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('coffee'), findsOneWidget);

    // Delete for good.
    await tester.drag(find.text('coffee'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('No expenses this month'), findsOneWidget);

    final ops = await db.select(db.outbox).get();
    expect(ops.map((o) => o.opType), [
      OutboxOpType.create,
      OutboxOpType.update,
      OutboxOpType.delete,
    ]);
    expect(ops.map((o) => o.entityId).toSet(), {'id-1'});
    expect(jsonDecode(ops[1].changedFields), {'amountMinor': 5000});

    final ExpenseRow row = (await db.expensesDao.findById('id-1'))!;
    expect(row.deleted, isTrue);
    expect(row.amountMinor, 5000);
    expect(row.note, 'coffee');
    expect(row.date, DateTime.utc(2026, 10, 6));

    // Unmount so drift's query streams close, and let fake time run their
    // cleanup timers (and the close's) before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final closing = db.close();
    await tester.pump(const Duration(seconds: 1));
    await closing;
  });
}
