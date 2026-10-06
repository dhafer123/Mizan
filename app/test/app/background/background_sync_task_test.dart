import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/background/background_sync_task.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/di/core_providers.dart';
import 'package:mizan/app/di/sync_providers.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/features/auth/data/session/stored_session.dart';
import 'package:mizan/features/auth/data/session/token_pair.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';

import '../../support/fake_session_store.dart';
import '../../support/fake_sync_repository.dart';

const _session = StoredSession(
  account: Account(id: 'u1', email: 'sami@example.com'),
  tokens: TokenPair(access: 'a', refresh: 'r'),
);

void main() {
  late FakeSyncRepository repo;

  setUp(() => repo = FakeSyncRepository());
  tearDown(() => repo.close());

  ProviderContainer container(FakeSessionStore store) {
    final c = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        syncRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10, 6))),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('signed out: nothing to do, done', () async {
    expect(await runBackgroundSync(container(FakeSessionStore())), isTrue);
    expect(repo.calls, isEmpty);
  });

  test('signed in: claims and syncs that account', () async {
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isTrue,
    );
    expect(repo.claims, ['u1']);
    expect(repo.calls, ['push', 'pull:u1']);
  });

  test('offline or server trouble: asks WorkManager to retry', () async {
    repo.pushFailures.add(const SyncFailure(SyncError.offline));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );

    repo.pushFailures.add(const SyncFailure(SyncError.server));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );
  });

  test('session over: done, no retry', () async {
    repo.pushFailures.add(const SyncFailure(SyncError.sessionExpired));
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isTrue,
    );
  });

  test('cannot claim the data: retry later', () async {
    repo.claimFailure = const SyncFailure(SyncError.storage);
    expect(
      await runBackgroundSync(container(FakeSessionStore(_session))),
      isFalse,
    );
    expect(repo.calls, isEmpty);
  });
}
