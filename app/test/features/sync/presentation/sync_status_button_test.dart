import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/sync_providers.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/presentation/account_section.dart';
import 'package:mizan/features/sync/domain/entities/sync_status.dart';
import 'package:mizan/features/sync/domain/value_objects/outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_phase.dart';
import 'package:mizan/features/sync/presentation/sync_status_button.dart';
import 'package:mizan/features/sync/presentation/sync_status_provider.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_sync_repository.dart';

/// Pumps the button (and the account section) with [status], driven by a
/// real scheduler on a fake repository so "Sync now" can be checked.
Future<(FakeSyncRepository, StreamController<SyncStatus>)> _pump(
  WidgetTester tester,
  SyncStatus status, {
  Account? account,
}) async {
  final repo = FakeSyncRepository();
  final statuses = StreamController<SyncStatus>.broadcast();
  addTearDown(statuses.close);
  addTearDown(repo.close);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          appBar: AppBar(actions: const [SyncStatusButton()]),
          body: const AccountSection(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const Text('login screen'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncStatusProvider.overrideWith((ref) async* {
          yield status;
          yield* statuses.stream;
        }),
        syncRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(account)),
        connectivityMonitorProvider.overrideWithValue(FakeConnectivity()),
        backgroundSyncProvider.overrideWithValue(FakeBackgroundSync()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, statuses);
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(SyncStatusButton));
  await tester.pumpAndSettle();
}

const _sami = Account(id: 'u1', email: 'sami@example.com');

void main() {
  final cases = {
    'Not syncing: sign in': const SyncStatus(),
    'Offline': const SyncStatus(phase: SyncPhase.offline),
    'Syncing': const SyncStatus(phase: SyncPhase.syncing),
    'Sync problem': const SyncStatus(phase: SyncPhase.error),
    'Synced': const SyncStatus(phase: SyncPhase.idle),
    'Changes waiting to sync': const SyncStatus(
      phase: SyncPhase.idle,
      outbox: OutboxCounts(pending: 3),
    ),
  };
  for (final MapEntry(key: tooltip, value: status) in cases.entries) {
    testWidgets('icon: $tooltip', (tester) async {
      await _pump(tester, status);

      expect(find.byTooltip(tooltip), findsOneWidget);
    });
  }

  testWidgets('the badge counts changes waiting, not when signed out', (
    tester,
  ) async {
    final (_, statuses) = await _pump(
      tester,
      const SyncStatus(
        phase: SyncPhase.offline,
        outbox: OutboxCounts(pending: 4),
      ),
    );
    expect(find.text('4'), findsOneWidget);

    statuses.add(const SyncStatus(outbox: OutboxCounts(pending: 4)));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsNothing);
  });

  testWidgets('signed out: the sheet explains and offers sign-in', (
    tester,
  ) async {
    await _pump(tester, const SyncStatus());
    await _openSheet(tester);

    expect(find.text('Local only'), findsOneWidget);
    expect(find.textContaining('only on this phone'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('login screen'), findsOneWidget);
  });

  testWidgets('error: the reason, waiting and refused changes, last sync', (
    tester,
  ) async {
    await _pump(
      tester,
      SyncStatus(
        phase: SyncPhase.error,
        outbox: const OutboxCounts(pending: 2, rejected: 1),
        failure: const SyncFailure(SyncError.server),
        lastSyncAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    await _openSheet(tester);

    expect(find.text("Couldn't sync"), findsOneWidget);
    expect(
      find.text("The server had a problem. We'll try again soon."),
      findsOneWidget,
    );
    expect(find.text('2 changes are waiting to sync.'), findsOneWidget);
    expect(find.textContaining("1 change couldn't be saved"), findsOneWidget);
    expect(find.text('Last synced 5 min ago.'), findsOneWidget);
  });

  testWidgets('"Sync now" asks the scheduler; disabled while offline', (
    tester,
  ) async {
    final (repo, statuses) = await _pump(
      tester,
      const SyncStatus(phase: SyncPhase.idle),
      account: _sami,
    );
    await _openSheet(tester);
    expect(find.text('Up to date'), findsOneWidget);
    final before = repo.syncs;

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(repo.syncs, before + 1);

    statuses.add(const SyncStatus(phase: SyncPhase.offline));
    await tester.pumpAndSettle();
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Sync now'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('log out warns about changes that have not synced', (
    tester,
  ) async {
    await _pump(
      tester,
      const SyncStatus(
        phase: SyncPhase.offline,
        outbox: OutboxCounts(pending: 3),
      ),
      account: _sami,
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.textContaining("3 changes haven't synced yet"), findsOneWidget);
    expect(find.textContaining('different account'), findsOneWidget);
  });

  testWidgets('log out with everything synced: no warning', (tester) async {
    await _pump(
      tester,
      const SyncStatus(phase: SyncPhase.idle),
      account: _sami,
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.textContaining("haven't synced"), findsNothing);
  });
}
