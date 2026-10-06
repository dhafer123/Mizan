import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/sync/domain/usecases/backoff_policy.dart';
import 'package:mizan/features/sync/domain/usecases/claim_local_data.dart';
import 'package:mizan/features/sync/domain/usecases/sync_now.dart';
import 'package:mizan/features/sync/domain/usecases/sync_scheduler.dart';
import 'package:mizan/features/sync/domain/value_objects/outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_phase.dart';

import '../../../../support/fake_sync_repository.dart';
import '../../../../support/fake_timers.dart';

final _now = DateTime.utc(2026, 10, 6, 9);
const _offline = SyncFailure(SyncError.offline);
const _server = SyncFailure(SyncError.server);

class _Harness {
  _Harness({bool online = true})
    : connectivity = FakeConnectivity(online: online) {
    scheduler = SyncScheduler(
      syncNow: SyncNow(repo, FakeClock(_now)),
      claim: ClaimLocalData(repo),
      lastSyncAt: repo.lastSyncAt,
      accounts: accounts.stream,
      online: connectivity.watchOnline(),
      outbox: repo.watchOutbox(),
      background: background,
      // Jitter fixed at the middle: delays are exactly 2s, 4s, 8s, …
      random: () => 0.5,
      startTimer: timers.start,
      backoff: const BackoffPolicy(),
    )..start();
  }

  final repo = FakeSyncRepository();
  final accounts = StreamController<String?>.broadcast();
  final FakeConnectivity connectivity;
  final background = FakeBackgroundSync();
  final timers = FakeTimers();
  late final SyncScheduler scheduler;

  SyncPhase get phase => scheduler.status.phase;

  Future<void> signIn([String account = 'u1']) async {
    accounts.add(account);
    await pumpEventQueue();
  }

  Future<void> write(int pending) async {
    repo.outbox.add(OutboxCounts(pending: pending));
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    await scheduler.dispose();
    await repo.close();
    await connectivity.close();
    await accounts.close();
  }
}

void main() {
  late _Harness h;

  tearDown(() => h.dispose());

  test('signed out: nothing syncs', () async {
    h = _Harness();
    await pumpEventQueue();
    await h.write(3);
    await h.timers.elapse(const Duration(minutes: 5));

    expect(h.phase, SyncPhase.signedOut);
    expect(h.repo.calls, isEmpty);
  });

  test(
    'signing in claims the data, schedules background sync and syncs',
    () async {
      h = _Harness();
      await h.signIn('u1');

      expect(h.repo.claims, ['u1']);
      expect(h.background.enabled, isTrue);
      expect(h.repo.calls, ['push', 'pull:u1']);
      expect(h.phase, SyncPhase.idle);
      expect(h.scheduler.status.lastSyncAt, _now);
    },
  );

  test('signing in while offline waits for the network', () async {
    h = _Harness(online: false);
    await h.signIn();
    expect(h.phase, SyncPhase.offline);
    expect(h.repo.calls, isEmpty);

    h.connectivity.online = true;
    await pumpEventQueue();

    expect(h.repo.syncs, 1);
    expect(h.phase, SyncPhase.idle);
  });

  test('a burst of local writes is synced once, after a quiet 2 s', () async {
    h = _Harness();
    await h.signIn();
    h.repo.calls.clear();

    await h.write(1);
    await h.timers.elapse(const Duration(seconds: 1));
    await h.write(2);
    await h.timers.elapse(const Duration(seconds: 1));
    await h.write(3);
    expect(h.repo.calls, isEmpty, reason: 'still within the debounce');

    await h.timers.elapse(const Duration(seconds: 2));

    expect(h.repo.syncs, 1);
    expect(h.scheduler.status.outbox.pending, 3);
  });

  test('the outbox shrinking (after a push) does not trigger a sync', () async {
    h = _Harness();
    await h.signIn();
    await h.write(2);
    await h.timers.elapse(const Duration(seconds: 2));
    h.repo.calls.clear();

    await h.write(0);
    await h.timers.elapse(const Duration(seconds: 5));

    expect(h.repo.calls, isEmpty);
  });

  test('failures retry with exponential backoff, then reset', () async {
    h = _Harness();
    h.repo.pushFailures.addAll([_server, _server, _offline]);
    await h.signIn();
    expect(h.phase, SyncPhase.error);
    expect(h.scheduler.status.failure, _server);
    expect(h.timers.pending, [const Duration(seconds: 2)]);

    await h.timers.elapse(const Duration(seconds: 2));
    expect(h.repo.syncs, 2);
    expect(h.timers.pending, [const Duration(seconds: 4)]);

    await h.timers.elapse(const Duration(seconds: 4));
    expect(h.repo.syncs, 3);
    expect(h.phase, SyncPhase.offline);
    expect(h.timers.pending, [const Duration(seconds: 8)]);

    await h.timers.elapse(const Duration(seconds: 8));
    expect(h.repo.syncs, 4);
    expect(h.phase, SyncPhase.idle);
    expect(h.scheduler.status.failure, isNull);
    expect(h.timers.pending, isEmpty);

    h.repo.pushFailures.add(_server);
    h.scheduler.syncNow();
    await pumpEventQueue();
    expect(h.timers.pending, [const Duration(seconds: 2)], reason: 'reset');
  });

  test('the network coming back retries at once', () async {
    h = _Harness();
    h.repo.pushFailures.add(_offline);
    await h.signIn();
    h.connectivity.online = false;
    await pumpEventQueue();
    expect(h.phase, SyncPhase.offline);

    h.connectivity.online = true;
    await pumpEventQueue();

    expect(h.repo.syncs, 2);
    expect(h.phase, SyncPhase.idle);
  });

  test('an ended session is not retried', () async {
    h = _Harness();
    h.repo.pushFailures.add(const SyncFailure(SyncError.sessionExpired));
    await h.signIn();

    await h.timers.elapse(const Duration(minutes: 10));

    expect(h.repo.syncs, 1);
    expect(h.timers.pending, isEmpty);
  });

  test('a trigger during a sync queues exactly one more', () async {
    h = _Harness();
    h.repo.gate = Completer<void>();
    await h.signIn();
    expect(h.phase, SyncPhase.syncing);

    h.scheduler
      ..syncNow()
      ..syncNow()
      ..syncNow();
    await pumpEventQueue();
    expect(h.repo.syncs, 1, reason: 'one at a time');

    h.repo.gate!.complete();
    await pumpEventQueue();

    expect(h.repo.syncs, 2);
    expect(h.phase, SyncPhase.idle);
  });

  test('signing out stops everything, including a pending retry', () async {
    h = _Harness();
    h.repo.pushFailures.add(_server);
    await h.signIn();
    expect(h.timers.pending, isNotEmpty);

    h.accounts.add(null);
    await pumpEventQueue();
    await h.timers.elapse(const Duration(minutes: 10));

    expect(h.phase, SyncPhase.signedOut);
    expect(h.background.enabled, isFalse);
    expect(h.repo.syncs, 1);
  });

  test('another account claims (and may wipe) before its first sync', () async {
    h = _Harness();
    await h.signIn('u1');
    h.repo.claimWipes = true;

    await h.signIn('u2');

    expect(h.repo.claims, ['u1', 'u2']);
    expect(h.repo.calls.last, 'pull:u2');
  });

  test('if the data cannot be claimed, nothing syncs', () async {
    h = _Harness();
    h.repo.claimFailure = const SyncFailure(SyncError.storage);

    await h.signIn();

    expect(h.phase, SyncPhase.error);
    expect(h.repo.calls, isEmpty);
  });

  test('shows the stored last sync time from the start', () async {
    h = _Harness();
    h.repo.storedLastSync = DateTime.utc(2026, 10, 5);
    final scheduler = SyncScheduler(
      syncNow: SyncNow(h.repo, FakeClock(_now)),
      claim: ClaimLocalData(h.repo),
      lastSyncAt: h.repo.lastSyncAt,
      accounts: const Stream.empty(),
      online: const Stream.empty(),
      outbox: const Stream.empty(),
      background: h.background,
    )..start();
    addTearDown(scheduler.dispose);
    await pumpEventQueue();

    expect(scheduler.status.lastSyncAt, DateTime.utc(2026, 10, 5));
  });

  test('a failing trigger stream does not break the scheduler', () async {
    h = _Harness();
    h.repo.outbox.addError(Exception('db'));
    await h.signIn();

    expect(h.phase, SyncPhase.idle);
  });

  test('status stream: current value first, then changes', () async {
    h = _Harness();
    final seen = <SyncPhase>[];
    final sub = h.scheduler.watchStatus().listen((s) => seen.add(s.phase));
    await pumpEventQueue();

    await h.signIn();
    await sub.cancel();

    expect(seen, [
      SyncPhase.signedOut,
      SyncPhase.idle,
      SyncPhase.syncing,
      SyncPhase.idle,
    ]);
  });
}
