import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/db/app_database.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/app/widgets/skeleton.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/money/currency.dart';
import 'package:mizan/core/money/money.dart';
import 'package:mizan/features/groups/data/remote/groups_api.dart';
import 'package:mizan/features/groups/data/repositories/group_repository_impl.dart';
import 'package:mizan/features/groups/domain/usecases/add_shared_expense.dart';
import 'package:mizan/features/groups/domain/value_objects/split.dart';

import '../../../../support/app_harness.dart';
import '../../../../support/fake_http_adapter.dart';
import '../../../../support/sequential_id_generator.dart';
import '../../../../support/test_database.dart';

MemberRow _member(String id, String name) => MemberRow(
  id: id,
  groupId: 'flat',
  displayName: name,
  version: 0,
  deleted: false,
);

/// Runs [work] (database writes) to the end. Drift's timers run in the
/// test's fake time, so they need pumping rather than `runAsync`.
Future<void> _drive(
  WidgetTester tester,
  Future<void> Function() work, {
  void Function(int frame)? eachFrame,
}) async {
  var done = false;
  Object? error;
  unawaited(
    work().then(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    eachFrame?.call(i);
  }
  if (error case final error?) throw error;
  expect(done, isTrue, reason: 'seeding finished');
}

/// A few frames, so drift's streams deliver and the screen catches up.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppHarness app;

  /// The whole app, on a group where Ali owes Sami 45.000 DT.
  Future<void> openGroup(WidgetTester tester) async {
    app = AppHarness();
    await app.boot(tester);
    final db = app.db;
    await _drive(tester, () async {
      await db.groupsDao.insertGroup(
        const GroupRow(
          id: 'flat',
          name: 'Flat 4B',
          currency: 'TND',
          version: 0,
          deleted: false,
        ),
        _member('sami', 'Sami'),
      );
      await db.groupsDao.insertMember(_member('ali', 'Ali'));
      await AddSharedExpense(
        GroupRepositoryImpl(
          db.groupsDao,
          db.sharedExpensesDao,
          db.settlementsDao,
          GroupsApi(fakeDio(FakeHttpAdapter(FakeHttpAdapter.offline))),
        ),
        SequentialIdGenerator(prefix: 'e'),
        FakeClock(testNow),
      )(
        groupId: 'flat',
        payerId: 'sami',
        amount: const Money(90000, Currency.tnd),
        split: const Split.equal({'sami', 'ali'}),
      );
    });
    unawaited(
      app.container.read(appRouterProvider).push(AppRoutes.group('flat')),
    );
    await _settle(tester);
  }

  testWidgets('recording a payment from Settle up keeps the sheet open until '
      'saved, then stays on Settle up with the payment listed', (
    tester,
  ) async {
    await openGroup(tester);

    await tester.tap(find.text('Settle up'));
    await _settle(tester);
    expect(find.text('Ali pays Sami'), findsOneWidget);

    await tester.tap(find.text('Record'));
    await _settle(tester);
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('Record a payment'), findsOneWidget);

    void noSkeleton(int frame) => expect(
      find.byType(SkeletonList),
      findsNothing,
      reason: 'frame $frame',
    );
    await tester.tap(find.byKey(const Key('payment-save')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      noSkeleton(i);
    }
    // Then sync rewrites the rows it pulled (same values, new writes).
    final db = app.db;
    await _drive(tester, () async {
      for (final row in await db.select(db.groups).get()) {
        await db.into(db.groups).insertOnConflictUpdate(row);
      }
      for (final row in await db.select(db.members).get()) {
        await db.into(db.members).insertOnConflictUpdate(row);
      }
      for (final row in await db.select(db.settlements).get()) {
        await db.into(db.settlements).insertOnConflictUpdate(row);
      }
    }, eachFrame: noSkeleton);
    // Frame by frame: the tab never blinks to a skeleton or back to
    // Balances while its rows refresh.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SkeletonList), findsNothing, reason: 'frame $i');
    }

    expect(find.text('Record a payment'), findsNothing);
    expect(find.text('Ali paid Sami'), findsOneWidget);
    expect(find.text('Suggested payments'), findsOneWidget);

    await app.shutDown(tester);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
