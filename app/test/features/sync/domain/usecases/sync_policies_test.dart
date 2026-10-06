import 'package:glados/glados.dart';
import 'package:mizan/core/clock/fake_clock.dart';
import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/sync/domain/usecases/backoff_policy.dart';
import 'package:mizan/features/sync/domain/usecases/claim_local_data.dart';
import 'package:mizan/features/sync/domain/usecases/get_last_sync_time.dart';
import 'package:mizan/features/sync/domain/usecases/rebase_row.dart';
import 'package:mizan/features/sync/domain/usecases/sync_now.dart';
import 'package:mizan/features/sync/domain/usecases/watch_outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/outbox_counts.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_error.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_failure.dart';
import 'package:mizan/features/sync/domain/value_objects/sync_report.dart';

import '../../../../support/fake_sync_repository.dart';

void main() {
  group('BackoffPolicy', () {
    const policy = BackoffPolicy();

    test('doubles from 2 s and stops at 5 min', () {
      Duration at(int attempt) => policy(attempt, random: () => 0.5);

      expect([for (var i = 0; i < 4; i++) at(i).inSeconds], [2, 4, 8, 16]);
      expect(at(7), const Duration(minutes: 4, seconds: 16));
      expect(at(8), const Duration(minutes: 5));
      expect(at(1000), const Duration(minutes: 5));
    });

    Glados2(any.intInRange(0, 40), any.double).test(
      'always within ±20 % of the capped delay',
      (attempt, r) {
        final random = (r.abs() % 1).toDouble();
        final delay = policy(attempt, random: () => random).inMilliseconds;
        final capped = (2000 * (1 << attempt.clamp(0, 30)))
            .clamp(0, 300000)
            .toDouble();
        expect(delay, inInclusiveRange(capped * 0.8 - 1, capped * 1.2 + 1));
      },
    );
  });

  group('rebaseRow', () {
    const server = {
      'id': 'e-1',
      'amountMinor': 4500,
      'note': 'server',
      'version': 3,
      'deleted': false,
    };

    test('nothing queued: the server row as is', () {
      expect(rebaseRow(server, const []), server);
    });

    test(
      'queued edits go on top, oldest first; metadata stays the server\'s',
      () {
        final row = rebaseRow(server, [
          (opType: 'update', changedFields: {'amountMinor': 5000}),
          (
            opType: 'update',
            changedFields: {'amountMinor': 6000, 'note': 'mine'},
          ),
        ]);

        expect(row, {
          'id': 'e-1',
          'amountMinor': 6000,
          'note': 'mine',
          'version': 3,
          'deleted': false,
        });
      },
    );

    test('a queued delete keeps the row deleted', () {
      expect(
        rebaseRow(server, [(opType: 'delete', changedFields: {})])['deleted'],
        isTrue,
      );
    });

    test('a queued create (restore) undeletes', () {
      final row = rebaseRow(
        {...server, 'deleted': true},
        [
          (opType: 'create', changedFields: {'id': 'e-1', 'note': 'back'}),
        ],
      );

      expect((row['deleted'], row['note']), (false, 'back'));
    });

    Glados(any.list(any.intInRange(0, 100))).test(
      'the last queued value of a field wins',
      (amounts) {
        final row = rebaseRow(server, [
          for (final a in amounts)
            (opType: 'update', changedFields: {'amountMinor': a}),
        ]);
        expect(row['amountMinor'], amounts.isEmpty ? 4500 : amounts.last);
        expect(row['version'], 3);
      },
    );
  });

  group('SyncNow', () {
    late FakeSyncRepository repo;
    final now = DateTime.utc(2026, 10, 6, 9);
    setUp(() => repo = FakeSyncRepository());
    tearDown(() => repo.close());

    test('pushes, then pulls for the account', () async {
      final result = await SyncNow(repo, FakeClock(now))(accountId: 'u1');

      expect(repo.calls, ['push', 'pull:u1']);
      expect(
        result,
        Ok<(SyncReport, DateTime), SyncFailure>((
          const SyncReport(pushed: 1, pulled: 2),
          now,
        )),
      );
    });

    test('a failed push skips the pull', () async {
      repo.pushFailures.add(const SyncFailure(SyncError.offline));

      final result = await SyncNow(repo, FakeClock(now))(accountId: 'u1');

      expect(result.failureOrNull, const SyncFailure(SyncError.offline));
      expect(repo.calls, ['push']);
    });

    test('a failed pull is the failure', () async {
      repo.pullFailures.add(const SyncFailure(SyncError.accountChanged));

      final result = await SyncNow(repo, FakeClock(now))(accountId: 'u1');

      expect(result.failureOrNull, const SyncFailure(SyncError.accountChanged));
    });
  });

  test('the small use cases pass through to the repository', () async {
    final repo = FakeSyncRepository()
      ..claimWipes = true
      ..storedLastSync = DateTime.utc(2026, 10, 5);
    addTearDown(repo.close);

    expect((await ClaimLocalData(repo)('u2')).valueOrNull, isTrue);
    expect(repo.claims, ['u2']);
    expect(await GetLastSyncTime(repo)(), DateTime.utc(2026, 10, 5));
    final counts = WatchOutboxCounts(repo)().first;
    repo.outbox.add(const OutboxCounts(pending: 2, rejected: 1));
    expect(await counts, const OutboxCounts(pending: 2, rejected: 1));
  });

  test('every sync failure has a message', () {
    for (final error in SyncError.values) {
      expect(SyncFailure(error).message, isNotEmpty);
    }
  });
}
